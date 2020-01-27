module lbf.gamedata;

import std.traits;

import asdf.serialization;
import bindbc.freeimage.types;
import gfm.math.vector;

import lbf.math;
import lbf.math.rectangle;
import lbf.graphics.opengl;

//region Proxies
struct colorProxy
{
	union
	{
		struct
		{
			float r, g, b, a;
		}
		@serializationIgnore
		vec4f v;
	}	
	
	this(vec4f v)
	{
		this.v = v;
	}
	
	vec4f opCast(T : vec4f)()
	{
		return this.v;
	}
}

struct vec4fProxy
{
	union
	{
		struct
		{
			float x, y, z, w;
		}
		@serializationIgnore
		vec4f v;
	}	
	
	this(vec4f v)
	{
		this.v = v;
	}
	
	vec4f opCast(T : vec4f)()
	{
		return this.v;
	}
}

struct vec3fProxy
{
	union
	{
		struct
		{
			float x, y, z;
		}
		@serializationIgnore
		vec3f v;
	}	
	
	this(vec3f v)
	{
		this.v = v;
	}
	
	vec3f opCast(T : vec3f)()
	{
		return this.v;
	}
}

struct vec3iProxy
{
	union
	{
		struct
		{
			int x, y, z;
		}
		@serializationIgnore
		vec3i v;
	}	
	
	this(vec3i v)
	{
		this.v = v;
	}
	
	vec3i opCast(T : vec3i)()
	{
		return this.v;
	}
}

struct vec2fProxy
{
	union
	{
		struct
		{
			float x, y;
		}
		@serializationIgnore
		vec2f v;
	}	
	
	this(vec2f v)
	{
		this.v = v;
	}
	
	vec2f opCast(T : vec2f)()
	{
		return this.v;
	}
}

struct vec2iProxy
{
	union
	{
		struct
		{
			int x, y;
		}
		@serializationIgnore
		vec2i v;
	}	
	
	this(vec2i v)
	{
		this.v = v;
	}
	
	vec2i opCast(T : vec2i)()
	{
		return this.v;
	}
}

struct Dimension
{
	union
	{
		struct
		{
			int rowCount, colCount, width, height;
		}
		@serializationIgnore
		vec4i v;
	}
	
	this(vec4i v)
	{
		this.v = v;
	}
	
	vec4i opCast(T : vec4i)()
	{
		return this.v;
	}
}
//endregion

struct DataFiles
{
	string[] characterFiles;
	string[] weaponFiles;
	string[] energyFiles;
	string[] particleFiles;
	string[] mapFiles;
	string[string] soundFiles;
}

final class CharData
{
	string name;
	
	string face;
	string small;
	
	string[] sprites;
	Dimension[] dimensions;
	@serializationIgnore
	FIBITMAP[] bitmaps;
	@serializationIgnore
	SizeI[] sizes;
	@serializationIgnore
	Texture[] textures;
	
	Charge[string] charges;
	
	this()
	{
		charges = [
			"hp":		Charge(500, 500, 0.125, 3),
			"darkHp":	Charge(0, 500, 0),
			// Decrease mp regen when hp is high
			"mp":		Charge(250, 500, 3, 3, null, "hp", 0.5f / 100, Operation.Substraction),
			"armor":	Charge(),
			"fall":		Charge(60, 60, 0.5, 1),
			"resist":	Charge(60, 60, 0.5, 1),
		];
	}
	
	float weight = 1;
	
	@serializationIgnore
	CharFrame injuredFrame;
	@serializationKeys(injuredFrame.stringof)
	int injuredIndex;
	
	//@serializationIgnore
	//CharFrame caughtFrame;
	//@serializationKeys(caughtFrame.stringof)
	//int caughtIndex;
	
	@serializationIgnore
	CharFrame dizzyFrame;
	@serializationKeys(dizzyFrame.stringof)
	int dizzyIndex;
	
	@serializationIgnore
	CharFrame landingFrame;
	@serializationKeys(landingFrame.stringof)
	int landingIndex;
	
	@serializationIgnore
	CharFrame brokenDefenseFrame;
	@serializationKeys(brokenDefenseFrame.stringof)
	int brokenDefenseIndex;
	
	//@serializationIgnore
	//CharFrame heavyStopFrame;
	//@serializationKeys(heavyStopFrame.stringof)
	//int heavyStopIndex;
	
	@serializationIgnore
	CharFrame flyFrontFrame;
	@serializationKeys(flyFrontFrame.stringof)
	int flyFrontIndex;
	
	@serializationIgnore
	CharFrame fallFrontFrame;
	@serializationKeys(fallFrontFrame.stringof)
	int fallFrontIndex;
	
	@serializationIgnore
	CharFrame flyBackFrame;
	@serializationKeys(flyBackFrame.stringof)
	int flyBackIndex;
	
	@serializationIgnore
	CharFrame fallBackFrame;
	@serializationKeys(fallBackFrame.stringof)
	int fallBackIndex;
	
	@serializationIgnore
	CharFrame groundBackFrame;
	@serializationKeys(groundBackFrame.stringof)
	int groundBackIndex;
	
	@serializationIgnore
	CharFrame groundFrontFrame;
	@serializationKeys(groundFrontFrame.stringof)
	int groundFrontIndex;
	
	CharFrame[int] frames;
}

final class CharFrame
{
	string name;
	Display[] pics;
	State state;
	@serializedAs!vec3fProxy
	vec3f velocity = vec3f(0, 0, 0);
	Operation velocityOp;
	@serializedAs!vec3fProxy
	vec3f controlledVelocity = vec3f(0, 0, 0);
	int wait;
	ushort defending;
	bool dirControl;
	
	@serializationIgnore
	CharFrame nextFrame;
	@serializationKeys(nextFrame.stringof)
	int nextIndex;
	
	@serializationIgnore
	CharFrame injuredFrame;
	@serializationKeys(injuredFrame.stringof)
	int injuredIndex;
	
	@serializationIgnore
	CharFrame dizzyFrame;
	@serializationKeys(dizzyFrame.stringof)
	int dizzyIndex;
	
	@serializationIgnore
	CharFrame landingFrame;
	@serializationKeys(landingFrame.stringof)
	int landingIndex;
	
	@serializationIgnore
	CharFrame brokenDefenseFrame;
	@serializationKeys(brokenDefenseFrame.stringof)
	int brokenDefenseIndex;
	
	@serializationIgnore
	CharFrame stopFrame;
	@serializationKeys(stopFrame.stringof)
	int stopIndex;
	
	Charger[] chargers;
	Spawn[] spawns;
	KeyEvent atk;
	KeyEvent jmp;
	KeyEvent def;
}

struct Display
{
	int index;
	int row, col;
	@serializedAs!vec2iProxy
	vec2i offset;
	float rotation = 0;
	@serializedAs!vec2fProxy
	vec2f scale = vec2f(1, 1);
	@serializedAs!colorProxy
	vec4f color = vec4f(1, 1, 1, 1);
}

final class MapData
{
	string name;
	
	string[] sprites;
	Dimension[] dimensions;
	@serializationIgnore
	FIBITMAP[] bitmaps;
	@serializationIgnore
	SizeI[] sizes;
	@serializationIgnore
	Texture[] textures;
	
	int width;
	int zPlace;
	int zWidth;
	float staticFrictionFactor = 1f;
	float dynamicfrictionFactor = 0.8f;
	MapLayer[] layers;
	Charge[] charges;
	MapFrame[int] mapFrames;
}

final class MapFrame
{
	string name;
	int wait;
	@serializationIgnore
	MapFrame nextFrame;
	@serializationKeys(nextFrame.stringof)
	int nextIndex;
	Charger[] chargers;
	MapLayer[] mapLayers;
}

struct MapLayer
{
	int x;
	int y;
	int z;
	Display pic;
	int loop;
	float distance;
}

struct Charge
{
	float amount = 0;
	float max = 0;
	float regen = 0;
	int regenWait = 2;
	
	@serializationIgnore
	Charge* regenParam;
	@serializationKeys(regenParam.stringof)
	string regenParamName;
	
	float paramFactor = float.nan;
	Operation paramOp;
	float paramWaitFactor = float.nan;
	Operation paramWaitOp;
	
	@serializedAs!colorProxy
	vec4f color;
	float segment = 0;
	
	@serializationIgnore
	CharFrame chargeZeroFrame;
	@serializationKeys(chargeZeroFrame.stringof)
	int chargeZeroIndex;
	
	@serializationIgnore
	CharFrame chargeFullFrame;
	@serializationKeys(chargeFullFrame.stringof)
	int chargeFullIndex;
}

struct Charger
{
	@serializationIgnore
	Charge* charge;
	@serializationKeys(charge.stringof)
	string chargeName;
	
	float amount = 0;
	Operation op;
	
	@serializationIgnore
	CharFrame chargeLowFrame;
	@serializationKeys(chargeLowFrame.stringof)
	int chargeLowIndex;
	
	@serializationIgnore
	CharFrame chargeFullFrame;
	@serializationKeys(chargeFullFrame.stringof)
	int chargeFullIndex;
	
	bool forceUsageLow;
	bool forceUsageHigh;
	bool forceChargeLow;
	bool forceChargeHigh;
}

struct Spawn
{
	@serializationIgnore
	Object obj;
	string name;
	@serializedAs!vec3fProxy
	vec3f position = vec3f(0, 0, 0);
	@serializedAs!vec3fProxy
	vec3f velocity = vec3f(0, 0, 0);
	@serializedAs!vec3fProxy
	vec3f controlledVelocity;
}

struct WeaponPoint
{
	@serializedAs!vec2iProxy
	vec2i offset;
	float angle = 0;
	@serializedAs!vec3fProxy
	vec3f velocity = vec3f(0, 0, 0);
	int attackIndex;
	bool cover;
}

enum ObjectType
{
	Char,
	Weapon,
	Energy,
	Particle,
}

struct KeyStatePack
{
	KeyState up;
	KeyState down;
	KeyState right;
	KeyState left;
	KeyState jump;
	KeyState attack;
	KeyState defend;
}

struct KeyEvent
{
	KeyStatePack keyStates;
	@serializationIgnore
	CharFrame frame;
	@serializationKeys(frame.stringof)
	int index;
}

enum KeyState : byte
{
	Released,
	Pressed,
	Down,
	Up
}

enum Operation : byte
{
	Addition,
	Substraction,
	Multiply,
	Divide,
	Assignment,
}

enum State : byte
{
	// Char States
	Standing,
	Walking,
	Running,
	Lying,
	Attacking,
	Jumping,
	InAir,
	Dash,
	Rowing,
	Defend,
	BrokenDefend,
	Catching,
	Caught,
	Injured,
	Dizzy,
	Hot,
	SpecialAttack,
	
	// Weapon Sates
	OnGround,
	Falling,
	DangerousFalling,
	Hold,
	Thrown,
}
