module lf2lbf.converter;

version(LF2LBF):

import core.memory : GC;

import std.algorithm.searching : canFind;
import std.conv : to, text;
import std.format : format;

import lf2.gamedata;
import lbf.gamedata;

class ConversionException : Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
		@nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
}


