module lbf.graphics.opengl.shader;

import std.conv : to;
import std.string : toStringz, fromStringz;
import std.format : format;

import lbf.core;
import lbf.util;
import lbf.graphics.opengl.gl;
import lbf.graphics.opengl.gltype;

import gfm.math.vector;
import gfm.math.matrix;

public final class Shader
{
	private uint id;
	private int[string] uniformTable;
	
	public this(const(char)[] vertSource, const(char)[] fragSource, const(char)[] geoSource = null)
	{
		uint vert = compileShader(vertSource, GL_VERTEX_SHADER);
		uint frag = compileShader(fragSource, GL_FRAGMENT_SHADER);
		uint geo = geoSource == null ? 0 : compileShader(geoSource, GL_GEOMETRY_SHADER);
		
		uint prog = glCreateProgram();
		
		glAttachShader(prog, vert);
		glAttachShader(prog, frag);
		if (geo != 0) glAttachShader(prog, geo);
		
		glLinkProgram(prog);
		
		glDeleteShader(vert);
		glDeleteShader(frag);
		if (geo != 0) glDeleteShader(geo);
		
		int success;
		glGetProgramiv(prog, GL_LINK_STATUS, &success);
		if (success == 0)
		{
			GLsizei infoLen;
			glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &infoLen);
			char[] error = new char[infoLen];
			glGetProgramInfoLog(prog, infoLen, &infoLen, error.ptr);
			throw new GraphicsException(format("Failed to link program:\n%s", error));
		}
		id = prog;
	}
	
	private static uint compileShader(const(char)[] source, GLenum type)
	{
		uint shader = glCreateShader(type);
		auto src = source.toStringz();
		assert(source.length < int.max);
		int len = cast(int)source.length;
		glShaderSource(shader, 1, &src, &len);
		glCompileShader(shader);
		
		int success;
		glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
		if (success == 0)
		{
			int infoLen;
			glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLen);
			char[] error = new char[infoLen];
			glGetShaderInfoLog(shader, infoLen, &infoLen, error.ptr);
			throw new GraphicsException(format("Failed to compile shader:\n%s", error));
		}
		return shader;
	}
	
	static uint used = 0;
	public void use()
	{
		if (used != id)
			glUseProgram(used = id);
	}
	
	public int getUniformLocation(const(char)[] name)
	{
		int location = glGetUniformLocation(id, name.toStringz());
		if (location == -1)
			throw new GraphicsException(format("Uniform \"%s\" location could not be retrieved.", name));
		return location;
	}
	
	public void setUniform(T)(const(char)[] name, T value) if (isGLType!T)
	{
		enum string suffix = toGLSuffix!T;
		int* locationPtr = name in uniformTable;
		if (locationPtr != null)
			mixin("glUniform1" ~ suffix ~ "(*locationPtr, value);");
		else
			mixin("glUniform1" ~ suffix ~ "(uniformTable[name] = getUniformLocation(name), value);");
	}
	
	unittest
	{
		Shader s;
		static assert(__traits(compiles, s.setUniform("i", 5)));
		static assert(__traits(compiles, s.setUniform("ui", 5u)));
		static assert(__traits(compiles, s.setUniform("f", 5f)));
		static assert(!__traits(compiles, s.setUniform("d", 5.0)));
		static assert(!__traits(compiles, s.setUniform("b", true)));
	}
	
	public void setUniform(T)(int location, T value) if (isGLType!T)
	{
		enum string suffix = toGLSuffix!T;
		mixin("glUniform1" ~ suffix ~ "(location, value);");
	}
	
	public void setUniform(T)(const(char)[] name, T[] value) if (isGLType!T)
	{
		assert(value.length > 0 && value.ptr != null);
		
		enum string suffix = toGLSuffix!T;
		int* locationPtr = name in uniformTable;
		if (locationPtr != null)
			mixin("glUniform1" ~ suffix ~ "v(*locationPtr, cast(int)value.length, value.ptr);");
		else
			mixin("glUniform1" ~ suffix ~
				"v(uniformTable[name] = getUniformLocation(name), cast(int)value.length, value.ptr);");
	}
	
	public void setUniform(T)(int location, T[] value) if (isGLType!T)
	{
		assert(value.length > 0 && value.ptr != null);
		
		enum string suffix = toGLSuffix!T;
		mixin("glUniform1" ~ suffix ~ "v(location, cast(int)value.length, value.ptr);");
	}
	
	public void setUniform(T, int N)(const(char)[] name, Vector!(T, N) value) if (isGLType!T)
	{
		static assert(N >= 2 && N <= 4, "Vector length out of range");
		
		enum string suffix = toGLSuffix!T;
		int* locationPtr = name in uniformTable;
		if (locationPtr != null)
			mixin("glUniform" ~ N.to!string ~ suffix ~ "v(*locationPtr, 1, value.ptr);");
		else
			mixin("glUniform" ~ N.to!string ~ suffix ~
				"v(uniformTable[name] = getUniformLocation(name), 1, value.ptr);");
	}
	
	unittest
	{
		Shader s;
		static assert(__traits(compiles, s.setUniform("v", vec2i(1, 2))));
		static assert(__traits(compiles, s.setUniform("v", vec3!uint(3, 4, 5))));
		static assert(__traits(compiles, s.setUniform("v", vec4f(6, 7, 8, 9))));
	}
	
	public void setUniform(T, int N)(int location, Vector!(T, N) value) if (isGLType!T)
	{
		static assert(N >= 2 && N <= 4, "Vector length out of range");
		
		enum string suffix = toGLSuffix!T;
		mixin("glUniform" ~ N.to!string ~ suffix ~ "v(location, 1, value.ptr);");
	}
	
	public void setUniform(T, int N)(const(char)[] name, Vector!(T, N)[] value) if (isGLType!T)
	{
		static assert(N >= 2 && N <= 4, "Vector length out of range");
		assert(value.length > 0 && value.ptr != null);
		
		enum string suffix = toGLSuffix!T;
		int* locationPtr = name in uniformTable;
		if (locationPtr != null)
			mixin("glUniform" ~ N.to!string ~ suffix ~ "v(*locationPtr, cast(int)value.length, value[0].ptr);");
		else
			mixin("glUniform" ~ N.to!string ~ suffix ~
				"v(uniformTable[name] = getUniformLocation(name), cast(int)value.length, value[0].ptr);");
	}
	
	public void setUniform(T, int N)(int location, Vector!(T, N)[] value) if (isGLType!T)
	{
		static assert(N >= 2 && N <= 4, "Vector length out of range");
		assert(value.length > 0 && value.ptr != null);
		
		enum string suffix = toGLSuffix!T;
		mixin("glUniform" ~ N.to!string ~ suffix ~ "v(location, cast(int)value.length, value[0].ptr);");
	}
	
	public void setUniform(T, int R, int C)(const(char)[] name, Matrix!(T, R, C) value) if (isGLType!T)
	{
		static assert(R >= 2 && R <= 4 && C >= 2 && C <= 4, "Matrix dimension(s) out of range");
		
		enum string suffix = toGLSuffix!T;
		int* locationPtr = name in uniformTable;
		if (locationPtr != null)
			mixin("glUniformMatrix" ~ (R == C ? R.to!string : C.to!string ~ "x" ~ R.to!string) ~ suffix ~
				"v(*locationPtr, 1, true, value.ptr);");
		else
			mixin("glUniformMatrix" ~ (R == C ? R.to!string : C.to!string ~ "x" ~ R.to!string) ~ suffix ~
				"v(uniformTable[name] = getUniformLocation(name), 1, true, value.ptr);");
	}
	
	unittest
	{
		Shader s;
		static assert(__traits(compiles, s.setUniform("m", mat2f())));
		static assert(__traits(compiles, s.setUniform("m", mat3f())));
		static assert(__traits(compiles, s.setUniform("m", mat4f())));
		static assert(__traits(compiles, s.setUniform("m", mat2x3!float())));
		static assert(__traits(compiles, s.setUniform("m", mat2x4!float())));
		static assert(__traits(compiles, s.setUniform("m", mat3x2!float())));
		static assert(__traits(compiles, s.setUniform("m", mat3x4!float())));
		static assert(__traits(compiles, s.setUniform("m", mat4x2!float())));
		static assert(__traits(compiles, s.setUniform("m", mat4x3!float())));
	}
	
	public void setUniform(T, int R, int C)(int location, Matrix!(T, R, C) value) if (isGLType!T)
	{
		static assert(R >= 2 && R <= 4 && C >= 2 && C <= 4, "Matrix dimension(s) out of range");
		
		enum string suffix = toGLSuffix!T;
		mixin("glUniformMatrix" ~ (R == C ? R.to!string : C.to!string ~ "x" ~ R.to!string) ~ suffix ~
			"v(location, 1, true, value.ptr);");
	}
	
	public void setUniform(T, int R, int C)(const(char)[] name, Matrix!(T, R, C)[] value) if (isGLType!T)
	{
		static assert(R >= 2 && R <= 4 && C >= 2 && C <= 4, "Matrix dimension(s) out of range");
		assert(value.length > 0 && value.ptr != null);
		
		enum string suffix = toGLSuffix!T;
		int* locationPtr = name in uniformTable;
		if (locationPtr != null)
			mixin("glUniformMatrix" ~ (R == C ? R.to!string : C.to!string ~ "x" ~ R.to!string) ~ suffix ~
				"v(*locationPtr, cast(int)value.length, true, value[0].ptr);");
		else
			mixin("glUniformMatrix" ~ (R == C ? R.to!string : C.to!string ~ "x" ~ R.to!string) ~ suffix ~
				"v(uniformTable[name] = getUniformLocation(name), cast(int)value.length, true, value[0].ptr);");
	}
	
	public void setUniform(T, int R, int C)(int location, Matrix!(T, R, C)[] value) if (isGLType!T)
	{
		static assert(R >= 2 && R <= 4 && C >= 2 && C <= 4, "Matrix dimension(s) out of range");
		assert(value.length > 0 && value.ptr != null);
		
		enum string suffix = toGLSuffix!T;
		mixin("glUniformMatrix" ~ (R == C ? R.to!string : C.to!string ~ "x" ~ R.to!string) ~ suffix ~
			"v(location, cast(int)value.length, true, value[0].ptr);");
	}
	
	public ~this()
	{
		import core.memory : GC;
		
		if (!GC.inFinalizer)
		{
			// Dispose managed state (managed objects).
			destroy(uniformTable);
		}
		
		// Free unmanaged resources (unmanaged objects), set large fields to null.
		if (id != 0)
			glDeleteProgram(id);
	}
}
