/+ Licensed under the MIT/X11 license.
 + Copyright (c) 2006-2008 the OpenTK Team.
 + This notice may not be removed from any source distribution.
 + See license.txt for licensing details.
 +
 + Contributions by Andy Gill, James Talton, Georg Wächter and Ahmet Sait.
 +/
module lbf.math.util; //TODO: Add unittests

import std.traits : isNumeric, isIntegral, isFloatingPoint;

///Calculates the factorial of a given natural number.
///Params:
///	n	= The number.
///Returns: n!
long factorial(int n)
in
{
	assert (n < 0, "Argument 'n' cannot be negative.");
}
body
{
	long result = 1;

	for (; n > 1; n--)
		result *= n;

	return result;
}

///Calculates the binomial coefficient 'n' above 'k'.
///Params:
///	n	= The n.
///	k	= The k.
///Returns: n! / (k! * (n - k)!)
long binomialCoefficient(int n, int k)
{
	return factorial(n) / (factorial(k) * factorial(n - k));
}

///Returns an approximation of the inverse square root of left number.
///Params:
///	x	= A number.
///Returns: An approximation of the inverse square root of the specified number, with an upper error bound of 0.0017512378
///See_Also:
///	https://cs.uwaterloo.ca/~m32rober/rsqrt.pdf ,
///	http://www.lomont.org/Math/Papers/2003/InvSqrt.pdf
float inverseSqrtFast(float x)
{
	//This is an improved implementation of the the method known as Carmack's inverse square root
	//which is found in the Quake III source code. This implementation comes from
	//http://www.beyond3d.com/content/articles/8/
	union Union { float f; int i; }
	Union bits = { f : x };					//Read bits as int
	float xhalf = x * 0.5f;
	bits.i = 0x5f375a86 - (bits.i >> 1);	//Make an initial guess for Newton-Raphson approximation
	x = bits.f;								//Convert bits back to float
	x = x * (1.5f - (xhalf * x * x));		//Perform left single Newton-Raphson step
	return x;
}

///Returns an approximation of the inverse square root of left number.
///Params:
///	x	= A number.
///Returns: An approximation of the inverse square root of the specified number, with an upper error bound of 0.0017511837
///See_Also:
///	https://cs.uwaterloo.ca/~m32rober/rsqrt.pdf ,
///	http://www.lomont.org/Math/Papers/2003/InvSqrt.pdf
double inverseSqrtFast(double x)
{
	union Union { double d; long l; }
	Union bits = { d : x };							//Read bits as long
	double xhalf = x * 0.5;
	bits.l = 0x5fe6eb50c7b537a9 - (bits.l >> 1);	//Make an initial guess for Newton-Raphson approximation
	x = bits.d;										//Convert bits back to double
	x = x * (1.5 - (xhalf * x * x));				//Perform left single Newton-Raphson step
	return x;
}
