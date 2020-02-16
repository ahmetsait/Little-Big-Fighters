module lbf.graphics.opengl.texture;

debug import std.stdio;
import std.conv : to;
import std.string : toStringz, fromStringz;
import std.format : format;

import lbf.core;
import lbf.util;
import lbf.graphics.opengl.gl;
import lbf.graphics.opengl.gltype;

import bindbc.freeimage.types;
import bindbc.freeimage.binddynamic;

/// Represents a RGBA8 texture
public final class Texture
{
	uint id;
	int width, height;
	
	this(FIBITMAP* bitmap,
		bool generateMipmaps = true,
		GLenum wrapMode = GL_CLAMP_TO_EDGE,
		GLenum minFilter = GL_LINEAR_MIPMAP_LINEAR,
		GLenum magFilter = GL_LINEAR)
	{
		assert(bitmap != null);
		
		FIBITMAP *pImage = FreeImage_ConvertTo32Bits(bitmap);
		if (pImage == null)
			throw new GraphicsException("Failed to convert bitmap to RGBA8 format.");
		scope(exit) FreeImage_Unload(pImage);
		
		width = FreeImage_GetWidth(pImage);
		height = FreeImage_GetHeight(pImage);
		
		glGenTextures(1, &id);
		bind();
		
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrapMode);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrapMode);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, minFilter);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, magFilter);
		
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0,
			GL_BGRA, GL_UNSIGNED_BYTE, FreeImage_GetBits(pImage));
		
		if (generateMipmaps)
			glGenerateMipmap(GL_TEXTURE_2D);
	}
	
	public void bind(GLenum target = GL_TEXTURE0)
	{
		static GLenum active = GL_TEXTURE0;
		static uint bound = 0;
		if (target != active || id != bound)
		{
			glActiveTexture(active = target);
			glBindTexture(GL_TEXTURE_2D, bound = id);
		}
	}
	
	public ~this()
	{
		// Free unmanaged resources (unmanaged objects), set large fields to null.
		if (id != 0)
			glDeleteTextures(1, &id);
	}
}
