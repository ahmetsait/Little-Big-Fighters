module lbf.util;

import std.range;
import std.string : indexOf, lastIndexOf;
import std.traits;

public RLock!T rlock(T)(ref T ptr)
{
	return RLock!(T)(&ptr);
}

public struct RLock(T) 
{
	@disable this();
	@disable this(this);

	T* var;
	this(T* ptr)
	{
		this.var = ptr;
		(*var)++;
	}
	~this()
	{
		(*var)--;
	}
}

string getStackTrace()
{
	import core.runtime;
	
	version(Posix)
	{
		// druntime cuts out the first few functions on the trace as they are internal
		// so we'll make some dummy functions here so our actual info doesn't get cut
		Throwable.TraceInfo f5() { return defaultTraceHandler(); }
		Throwable.TraceInfo f4() { return f5(); }
		Throwable.TraceInfo f3() { return f4(); }
		Throwable.TraceInfo f2() { return f3(); }
		auto stuff = f2();
	}
	else
		auto stuff = defaultTraceHandler();
	
	return stuff.toString();
}

string toPascalCase(S)(S str) if(isSomeString!S)
{
	import std.array : array;
	import std.conv : to;
	import std.string : capitalize;
	import std.uni : isAlpha, byCodePoint;
	import std.utf : toUTF8; 

	dchar[] result = str.byCodePoint.array;
	sizediff_t index = -1;
	foreach(i, ch; result)
	{
		if(isAlpha(ch))
		{
			index = i;
			break;
		}
	}
	if(index != -1)
	{
		//FIXME: Capitalize is not ligature aware but probably nobody needs this anyway
		result = result[0 .. index] ~ capitalize(result[index].to!dstring) ~ result[index + 1 .. $];
	}
	return result.toUTF8();
}

unittest
{
	assert(toPascalCase("ßtuff") == "SStuff");
	assert(toPascalCase("̏stuff") == "̏Stuff");
	assert(toPascalCase("ﬄ") == "FFL"); //FIXME: Should be Ffl
}

enum bool isIterableReverse(T) = is(typeof({ foreach_reverse (elem; T.init) {} }));

///Returns index of the first element that is equal to the value in the given iterable range.
public bool contains(Range, E)(Range haystack, E needle)
	if(isIterable!Range && is(Unqual!E : Unqual!(ElementType!Range)))
{
	foreach(element; haystack)
		if (element == needle)
			return true;
	return false;
}

///Returns index of the first element that is equal to the value in the given iterable range.
public sizediff_t indexOf(Range, E)(Range haystack, E needle)
	if(isIterable!Range && is(Unqual!E : Unqual!(ElementType!Range)))
{
	sizediff_t i = 0;
	foreach(element; haystack)
		if (element == needle)
			return i;
		else
			i++;
	return -1;
}

///Returns index of the last element that is equal to the value in the given iterable range.
public sizediff_t lastIndexOf(Range, E)(Range haystack, E needle)
	if(is(Unqual!(ElementType!Range) == Unqual!E) && (isIterableReverse!Range || isIterable!Range))
{
	static if(isIterableReverse!Range)
	{
		foreach_reverse(i, element; haystack)
			if (element == needle)
				return i;
		return -1;
	}
	else static if(isIterable!Range)
	{
		sizediff_t found = -1, i = 0;
		foreach(element; haystack)
		{
			if (element == needle)
				found = i;
			i++;
		}
		return found;
	}
	else
		static assert(0, "haystack is not iterable");
}

unittest
{
	import std.range : iota;
	immutable arr = [1, 1, 2, 3, 5, 8, 13, 21];
	assert(arr.contains(1));
	assert(arr.contains(8));
	assert(arr.contains(21));
	assert(!arr.contains(7));
	
	assert(arr.indexOf(1) == 0);
	assert(arr.indexOf(8) == 5);
	assert(arr.indexOf(21) == 7);
	assert(arr.indexOf(4) == -1);
	
	assert(arr.lastIndexOf(1) == 1);
	assert(arr.lastIndexOf(8) == 5);
	assert(arr.lastIndexOf(21) == 7);
	assert(arr.lastIndexOf(4) == -1);

	struct List(T : T[])
	{
	private:
		size_t i = 0;
		T[] list;
	public:
		this(T[] list)
		{
			this.list = list.dup;
		}
		void popFront()
		{
			i++;
		}
		int front()
		{
			return list[i];
		}
		bool empty()
		{
			return !(i < list.length);
		}
	}
	auto r = List!(typeof(arr))(arr);
	assert(r.contains(1));
	assert(r.contains(8));
	assert(r.contains(21));
	assert(!r.contains(7));
	
	assert(r.indexOf(1) == 0);
	assert(r.indexOf(8) == 5);
	assert(r.indexOf(21) == 7);
	assert(r.indexOf(4) == -1);
	
	assert(r.lastIndexOf(1) == 1);
	assert(r.lastIndexOf(8) == 5);
	assert(r.lastIndexOf(21) == 7);
	assert(r.lastIndexOf(4) == -1);
}
