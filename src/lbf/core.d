module lbf.core;

import std.string : fromStringz, format;
import std.exception : enforce;

class ApplicationException : Exception
{
	public this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) @nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
}

class ObjectDisposedException : Exception
{
	public this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) @nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
}

class InvalidOperationException : Exception
{
	public this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) @nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
}

class NotImplementedException : Exception
{
	public this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) @nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
}

class ArgumentNullException : Exception
{
	public this(string msg, string arg = null, string file = __FILE__, size_t line = __LINE__, Throwable next = null) @safe pure
	{
		super(arg == null ? msg : format("Argument '%s' cannot be null. %s", arg, msg), file, line, next);
	}
}

class UnsupportedException : Exception
{
	public this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) @nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
}

class SDLException : Exception
{
	public this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) @nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
}

class GraphicsException : Exception
{
	public this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
		@nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
}

import bindbc.sdl.bind.sdlerror: SDL_GetError;
import bindbc.sdl.bind.sdlstdinc : SDL_bool;

SDL_bool enforceSDLTrue(SDL_bool returnCode, string message = null)
{
	enforce!SDLException(returnCode == SDL_bool.SDL_TRUE, (message == null ? "SDL Error: " : message ~ "\nSDL Error: ") ~ fromStringz(SDL_GetError()).idup);
	return returnCode;
}

int enforceSDLEquals(int returnCode, int success, string message = null)
{
	enforce!SDLException(returnCode == success, (message == null ? "SDL Error: " : message ~ "\nSDL Error: ") ~ fromStringz(SDL_GetError()).idup);
	return returnCode;
}

int enforceSDLNotEquals(int returnCode, int success, string message = null)
{
	enforce!SDLException(returnCode != success, (message == null ? "SDL Error: " : message ~ "\nSDL Error: ") ~ fromStringz(SDL_GetError()).idup);
	return returnCode;
}

int enforceSDLNotNegative(int returnCode, string message = null)
{
	enforce!SDLException(returnCode >= 0, (message == null ? "SDL Error: " : message ~ "\nSDL Error: ") ~ fromStringz(SDL_GetError()).idup);
	return returnCode;
}

T* enforceSDLNotNull(T)(T* returnValue, string message = null)
{
	enforce!SDLException(returnValue != null, (message == null ? "SDL Error: " : message ~ "\nSDL Error: ") ~ fromStringz(SDL_GetError()).idup);
	return returnValue;
}
