module lbf.math.point;

import std.traits : isNumeric;

version(Have_gfm_math) import gfm.math.vector : vec2;

import lbf.math.size;

///Defines a point on a two-dimensional plane.
public struct Point(T) if(isNumeric!T)
{
	union
	{
		struct
		{
			public T x; ///X coordinate of this instance.
			public T y; ///Y coordinate of this instance.
		}
		version(Have_gfm_math) public vec2!T v; ///2D vector representation of this instance.
	}
	
	version(Have_gfm_math) alias v this;
	
	///Constructs a new Point instance.
	///Params:
	///	x	= The X coordinate of this instance.
	///	y	= The Y coordinate of this instance.
	public this(T x, T y)
	{
		this.x = x;
		this.y = y;
	}
	
	///Constructs a new Point instance from a 2D vector.
	///Params:
	///	vector	= The vector to construct the Point from.
	version(Have_gfm_math) public this(vec2!T vector)
	{
		this.v = vector;
	}
	
	///Gets a $(D bool) that indicates whether this instance is empty or zero.
	public bool isEmpty()
	{
		return (x == 0 && y == 0);
	}
	
	///Returns the Point (0, 0).
	public static const Point!T zero = Point!T();
	
	///Returns the Point (0, 0).
	public static const Point!T empty = Point!T();
	
	auto opBinary(string op, R)(Point!R point) if(isNumeric!R)
	{
		static if (op == "+")
		{
			alias F = typeof(x + point.x);
			return Point!F(x + point.x, y + point.y);
		}
		else static if (op == "-")
		{
			alias F = typeof(x - point.x);
			return Point!F(x - point.x, y - point.y);
		}
		else
			static assert(0, "Operator " ~ op ~ " not implemented");
	}
	
	auto opBinary(string op, R)(R scalar) if(isNumeric!R)
	{
		static if (op == "*")
		{
			alias F = typeof(x * scalar);
			return Point!F(x * scalar, y * scalar);
		}
		else static if (op == "/")
		{
			alias F = typeof(x / scalar);
			return Point!F(x / scalar, y / scalar);
		}
		else
			static assert(0, "Operator " ~ op ~ " not implemented");
	}
	
	auto opBinary(string op, R)(Size!R size) if(isNumeric!R)
	{
		static if (op == "+")
		{
			alias F = typeof(x + size.width);
			return Point!T(x + size.width, y + size.height);
		}
		else static if (op == "-")
		{
			alias F = typeof(x - size.width);
			return Point!T(x - size.width, y - size.height);
		}
		else
			static assert(0, "Operator " ~ op ~ " not implemented");
	}
	
	///Indicates whether this instance is equal to the specified Point.
	public bool opEquals(Point!T other)
	{
		return x == other.x && y == other.y;
	}
	
	///Returns a $(D string) that describes this instance.
	public string toString()
	{
		import std.string : format;
		return format("Point(%s, %s)", x, y);
	}
}

public alias PointI = Point!int;
public alias PointF = Point!float;

unittest
{
	int x = 1920, y = 1080;
	Point!int pi = Point!int(x, y);
	auto pf = pi * 2.5f + pi - pi / 4;
	static assert(is(typeof(pf) == Point!float));
	assert(pf == Point!float(x * 2.5f + x - x / 4, y * 2.5f + y - y / 4));
	vec2!float v = pf;
}
