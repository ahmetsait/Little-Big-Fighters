module lbf.math.size;

import std.traits : isNumeric;

version(Have_gfm_math) import gfm.math.vector : vec2;

import lbf.math.point;

///Stores the width and height of a rectangle.
public struct Size(T) if(isNumeric!T)
{
	union
	{
		struct
		{
			public T width; ///The width of this instance.
			public T height; ///The height of this instance.
		}
		version(Have_gfm_math) public vec2!T v; ///2D vector representation of this instance.
	}
	
	version(Have_gfm_math) alias v this;
	
	///Constructs a new Size instance.
	///Params:
	///	width	= The width of this instance.
	///	height	= The height of this instance.
	public this(T width, T height)
	{
		this.width = width;
		this.height = height;
	}
	
	///Constructs a new Point instance from a 2D vector.
	///Params:
	///	vector	= The vector to construct the Size from.
	version(Have_gfm_math) public this(vec2!T vector)
	{
		this.v = vector;
	}
	
	//TODO: Decide whether it makes sense to allow negative sizes

	///Gets a $(D bool) that indicates whether this instance is empty or zero.
	public bool isEmpty() @property
	{
		return (width == 0 && height == 0);
	}

	///Returns a Size instance equal to (0, 0).
	public static const Size empty = Size();

	///Returns a Size instance equal to (0, 0).
	public static const Size zero = Size();
	
	auto opBinary(string op, R)(R scalar) if(isNumeric!R)
	{
		static if (op == "*")
		{
			alias F = typeof(width * scalar);
			return Size!F(width * scalar, height * scalar);
		}
		else static if (op == "/")
		{
			alias F = typeof(width / scalar);
			return Size!F(width / scalar, height / scalar);
		}
		else
			static assert(0, "Operator " ~ op ~ " not implemented");
	}
	
	Size opBinary(string op)(Size rhs)
	{
		static if (op == "+")
		{
			alias F = typeof(x + rhs.width);
			return Size!T(x + rhs.width, y + rhs.height);
		}
		else static if (op == "-")
		{
			alias F = typeof(x - rhs.width);
			return Size!F(x - rhs.width, y - rhs.height);
		}
		else
			static assert(0, "Operator " ~ op ~ " not implemented");
	}
	
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

	///Indicates whether this instance is equal to the specified Size.
	public bool opEquals(Size other)
	{
		return width == other.width && height == other.height;
	}
	
	public void clampWidth(T minWidth, T maxWidth, bool min = true, bool max = true)
	{
		if (min && this.width < minWidth)
			this.width = minWidth;
		
		if (max && this.width > maxWidth)
			this.width = maxWidth;
	}
	
	public void clampHeight(T minHeight, T maxHeight, bool min = true, bool max = true)
	{
		if (min && this.height < minHeight)
			this.height = minHeight;

		if (max && this.height > maxHeight)
			this.height = maxHeight;
	}
	
	public void clamp(Size!T minSize, Size!T maxSize, bool min = true, bool max = true, bool width = true, bool height = true)
	{
		if (width)
			clampWidth(minSize.width, maxSize.width, min, max);
		if (height)
			clampHeight(minSize.height, maxSize.height, min, max);
	}

	public Size!T clamped(Size!T minSize, Size!T maxSize, bool min = true, bool max = true, bool width = true, bool height = true)
	{
		Size!T size = this;
		size.clamp(minSize, maxSize, min, max, width, height);
		return size;
	}
	
	///Returns a $(D string) that describes this instance.
	public string toString()
	{
		import std.string : format;
		return format("Size(%s, %s)", width, height);
	}
}

public alias SizeI = Size!int;
public alias SizeF = Size!float;
