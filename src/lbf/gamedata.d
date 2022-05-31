module lbf.gamedata;

import std.traits;

import asdf.serialization;
import bindbc.freeimage.types;
import gfm.math.vector;

import lbf.math;
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
	string[string] heroFiles;
	@serializationIgnore
	HeroData[string] heroes;
	
	string[string] weaponFiles;
	@serializationIgnore
	WeaponData[string] weapons;
	
	//string[string] energyFiles;
	//@serializationIgnore
	//EnergyData[string] energies;
	//
	//string[string] particleFiles;
	//@serializationIgnore
	//ParticleData[string] particles;
	
	string[string] mapFiles;
	@serializationIgnore
	MapData[string] maps;
	
	string[string] soundFiles;
}

final class HeroData
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
	HeroFrame injuredFrame;
	@serializationKeys(injuredFrame.stringof)
	int injuredIndex;
	
	//@serializationIgnore
	//CharFrame caughtFrame;
	//@serializationKeys(caughtFrame.stringof)
	//int caughtIndex;
	
	@serializationIgnore
	HeroFrame dizzyFrame;
	@serializationKeys(dizzyFrame.stringof)
	int dizzyIndex;
	
	@serializationIgnore
	HeroFrame landingFrame;
	@serializationKeys(landingFrame.stringof)
	int landingIndex;
	
	@serializationIgnore
	HeroFrame brokenDefenseFrame;
	@serializationKeys(brokenDefenseFrame.stringof)
	int brokenDefenseIndex;
	
	//@serializationIgnore
	//CharFrame heavyStopFrame;
	//@serializationKeys(heavyStopFrame.stringof)
	//int heavyStopIndex;
	
	@serializationIgnore
	HeroFrame flyFrontFrame;
	@serializationKeys(flyFrontFrame.stringof)
	int flyFrontIndex;
	
	@serializationIgnore
	HeroFrame fallFrontFrame;
	@serializationKeys(fallFrontFrame.stringof)
	int fallFrontIndex;
	
	@serializationIgnore
	HeroFrame flyBackFrame;
	@serializationKeys(flyBackFrame.stringof)
	int flyBackIndex;
	
	@serializationIgnore
	HeroFrame fallBackFrame;
	@serializationKeys(fallBackFrame.stringof)
	int fallBackIndex;
	
	@serializationIgnore
	HeroFrame groundBackFrame;
	@serializationKeys(groundBackFrame.stringof)
	int groundBackIndex;
	
	@serializationIgnore
	HeroFrame groundFrontFrame;
	@serializationKeys(groundFrontFrame.stringof)
	int groundFrontIndex;
	
	HeroFrame[int] frames;
}

final class HeroFrame
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
	HeroFrame nextFrame;
	@serializationKeys(nextFrame.stringof)
	int nextIndex;
	
	@serializationIgnore
	HeroFrame injuredFrame;
	@serializationKeys(injuredFrame.stringof)
	int injuredIndex;
	
	@serializationIgnore
	HeroFrame dizzyFrame;
	@serializationKeys(dizzyFrame.stringof)
	int dizzyIndex;
	
	@serializationIgnore
	HeroFrame landingFrame;
	@serializationKeys(landingFrame.stringof)
	int landingIndex;
	
	@serializationIgnore
	HeroFrame brokenDefenseFrame;
	@serializationKeys(brokenDefenseFrame.stringof)
	int brokenDefenseIndex;
	
	@serializationIgnore
	HeroFrame stopFrame;
	@serializationKeys(stopFrame.stringof)
	int stopIndex;
	
	Charger[] chargers;
	Spawn[] spawns;
	KeyEvent[] keyEvents;
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

struct Body
{
	RectangleI area;
	float sensitivity = 1;
	Material material = Material.Flesh;
	@serializationIgnore
	HeroFrame hitFrame;
	@serializationKeys(hitFrame.stringof)
	int hitIndex;
	long hitMask;
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
	@serializedAs!vec3fProxy
	vec3f velocity = vec3f(0, 0, 0);
	@serializationIgnore
	WeaponFrame weaponFrame;
	@serializationKeys(weaponFrame.stringof)
	int weaponIndex;
	int attackIndex;
	bool cover;
}

final class WeaponData
{
	
}

final class WeaponFrame
{
	string name;
}

enum Material
{
	Void,
	Flesh,
	Wood,
	Rock,
	Metal,
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
	HeroFrame chargeZeroFrame;
	@serializationKeys(chargeZeroFrame.stringof)
	int chargeZeroIndex;
	
	@serializationIgnore
	HeroFrame chargeFullFrame;
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
	HeroFrame chargeLowFrame;
	@serializationKeys(chargeLowFrame.stringof)
	int chargeLowIndex;
	
	@serializationIgnore
	HeroFrame chargeFullFrame;
	@serializationKeys(chargeFullFrame.stringof)
	int chargeFullIndex;
	
	bool forceUsageLow;	/// Use remaining charge even if it's not enough
	bool forceUsageHigh;	/// 
	bool forceChargeLow;	/// 
	bool forceChargeHigh;	/// 
}

enum ObjectType
{
	Hero,
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
	HeroFrame frame;
	@serializationKeys(frame.stringof)
	int index;
}

enum KeyState : byte
{
	Any,	/// Wildcard state that should be ignored
	Pressed,	/// Pressed in this frame
	Released,	/// Released in this frame
	Down,	/// Currently pressed
	Up	/// Currently released
}

enum Operation : byte
{
	Addition,
	Substraction,
	Multiply,
	Divide,
	Assignment,
}

enum ForceMode : byte
{
	Impact,	/// Change velocity of the object, using its mass
	Assign,	/// Change velocity of the object, ignoring its mass
	Force,	/// Add a continuous force to the object, using its mass
	Acceleration,	/// Add a continuous acceleration to the object, ignoring its mass
	Impulse,	/// Add an instant force impulse to the object, using its mass
	VelocityChange	/// Add an instant velocity change to the object, ignoring its mass
}

enum State : byte
{
	// Hero States
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
