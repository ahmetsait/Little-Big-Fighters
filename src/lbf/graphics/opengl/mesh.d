module lbf.graphics.opengl.mesh;

import std.format;
import std.range;
import std.traits;

import lbf.core;
import lbf.graphics.opengl.gl;
import lbf.graphics.opengl.gltype;
import lbf.graphics.opengl.vertex;

import gfm.math.vector;

import containers.dynamicarray;

/// $(D
/// 	struct Vertex
/// 	{
/// 		public vec3f position;
/// 		public vec3f normal;
/// 		public vec2f texCoord;
/// 		public vec4f color;
/// 	}
/// 	layout (location = 0) in vec3 vPosition;
/// 	layout (location = 1) in vec3 vNormal;
/// 	layout (location = 2) in vec2 vTexCoord;
/// 	layout (location = 3) in vec4 vColor;
/// )
public final class Mesh(V, I = uint)
	if (isInstanceOf!(Vertex, V) && isUnsigned!I)
{
	private uint vao, vbo, ebo;
	public V[] vertices;
	public I[] indices;
	
	public this()
	{
		glGenVertexArrays(1, &vao);
		glGenBuffers(1, &vbo);
		glGenBuffers(1, &ebo);
		
		glBindVertexArray(vao);
		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		
		enum stride = V.sizeof;
		
		static if (hasMember!(V, "position"))
		{
			glEnableVertexAttribArray(0);
			glVertexAttribPointer(0, V.position.v.length, toGLType!(V.position.element_t), GL_FALSE, stride, cast(void*)V.position.offsetof);
		}
		
		static if (hasMember!(V, "normal"))
		{
			glEnableVertexAttribArray(1);
			glVertexAttribPointer(1, V.normal.v.length, toGLType!(V.position.element_t), GL_FALSE, stride, cast(void*)V.normal.offsetof);
		}
		
		static if (hasMember!(V, "texCoord"))
		{
			glEnableVertexAttribArray(2);
			glVertexAttribPointer(2, V.texCoord.v.length, toGLType!(V.position.element_t), GL_FALSE, stride, cast(void*)V.texCoord.offsetof);
		}
		
		static if (hasMember!(V, "color"))
		{
			glEnableVertexAttribArray(3);
			glVertexAttribPointer(3, V.color.v.length, toGLType!(V.position.element_t), GL_FALSE, stride, cast(void*)V.color.offsetof);
		}
		
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
	}
	
	public this(V[] vertices, I[] indices, GLenum hint = GL_STATIC_DRAW)
	{
		this();
		this.vertices = vertices;
		this.indices = indices;
		reload(hint);
	}
	
	public void reload(GLenum hint = GL_STATIC_DRAW, bool vertex = true, bool index = true)
	{
		enum stride = V.sizeof;
		
		glBindVertexArray(vao);
		if (vertices)
		{
			glBindBuffer(GL_ARRAY_BUFFER, vbo);
			glBufferData(GL_ARRAY_BUFFER, vertices.length * stride, vertices.ptr, hint);
			int loadedVertexBufferSize;
			glGetBufferParameteriv(GL_ARRAY_BUFFER, GL_BUFFER_SIZE, &loadedVertexBufferSize);
			if (vertices.length * stride != loadedVertexBufferSize)
				throw new GraphicsException("Vertex buffer not uploaded correctly");
		}
		
		if (indices)
		{
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
			glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.length * I.sizeof, indices.ptr, hint);
			int loadedIndexBufferSize;
			glGetBufferParameteriv(GL_ELEMENT_ARRAY_BUFFER, GL_BUFFER_SIZE, &loadedIndexBufferSize);
			if (indices.length * I.sizeof != loadedIndexBufferSize)
				throw new GraphicsException("Index buffer not uploaded correctly");
		}
	}
	
	public bool checkBufferIntegration()
	{
		foreach (index; indices)
			if (index >= vertices.length)
				return false;
		return true;
	}
	
	public void bind()
	{
		static uint bound = 0;
		if (bound != vao)
			glBindVertexArray(bound = vao);
	}
	
	public void drawIndices(GLenum primitive = GL_TRIANGLES)
	{
		bind();
		glDrawElements(primitive, cast(GLsizei)indices.length, toGLType!I, cast(void*)0);
	}
	
	public void drawVertices(GLenum primitive = GL_TRIANGLES)
	{
		bind();
		glDrawElements(primitive, cast(GLsizei)indices.length, toGLType!I, cast(void*)0);
	}
	
	public ~this()
	{
		import core.memory : GC;
		
		if (!GC.inFinalizer)
		{
			// Dispose managed state (managed objects).
			destroy(vertices);
			destroy(indices);
		}
		
		// Free unmanaged resources (unmanaged objects), set large fields to null.
		if (vbo != 0)
		{
			glDeleteBuffers(1, &vbo);
			vbo = 0;
		}
		if (ebo != 0)
		{
			glDeleteBuffers(1, &ebo);
			ebo = 0;
		}
		if (vao != 0)
		{
			glDeleteVertexArrays(1, &vao);
			vao = 0;
		}
	}
}
