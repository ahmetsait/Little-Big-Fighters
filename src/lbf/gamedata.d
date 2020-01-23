module lbf.gamedata;

import asdf;
import gfm.math.vector;

public final class DataFiles
{
	public string[int] CharDataFiles;
	public string[int] MapFiles;
}

@serializedAs!(int)
public struct Key(T)
{
	alias key this;
	union
	{
		int key;
		T val;
	}
	
	this(int key)
	{
		this.key = key;
	}
	
	int opCast(T : int)()
	{
		return key;
	}
}

public struct vec3fProxy
{
	public float x, y, z;
	
	this(vec3f v)
	{
		x = v.x;
		y = v.y;
		z = v.z;
	}
	
	vec3f opCast(T : vec3f)()
	{
		vec3f v;
		v.x = this.x;
		v.y = this.y;
		v.z = this.z;
		return v;
	}
}

public struct vec2iProxy
{
	public int x, y;
	
	this(vec2i v)
	{
		x = v.x;
		y = v.y;
	}
	
	vec2i opCast(T : vec2i)()
	{
		vec2i v;
		v.x = this.x;
		v.y = this.y;
		return v;
	}
}

public final class CharData
{
	public string name;
	public Charge hp = { amount: 500, max: 500, regen: 1.0f / 12 };
	public Charge mp = { amount: 250, max: 500, regen: 1.0f / 3 };
	public float mpRegenFactor = 5;
	public Charge armor;
	public Charge fall = { amount: 60, max: 60, regen: 1f };
	public Charge defend = { amount: 60, max: 60, regen: 1f };
	@serializedAs!vec2iProxy
	public vec2i center;
	public float weight = 1;
	union
	{
		@serializationIgnore
		public Frame[] injuredFrames;
		public int[] injuredIndices;
	}
	//public int[] caughtIndices;
	union
	{
		@serializationIgnore
		public Frame dizzyFrame;
		public int dizzyIndex;
	}
	union
	{
		@serializationIgnore
		public Frame landingFrame;
		public int landingIndex;
	}
	union
	{
		@serializationIgnore
		public Frame breakDefendFrame;
		public int breakDefendIndex;
	}
	union
	{
		@serializationIgnore
		public Frame heavyStopFrame;
		public int heavyStopIndex;
	}
	union
	{
		@serializationIgnore
		public Frame flyFrontFrame;
		public int flyFrontIndex;
	}
	union
	{
		@serializationIgnore
		public Frame fallFrontFrame;
		public int fallFrontIndex;
	}
	union
	{
		@serializationIgnore
		public Frame flyBackFrame;
		public int flyBackIndex;
	}
	union
	{
		@serializationIgnore
		public Frame fallBackFrame;
		public int fallBackIndex;
	}
	union
	{
		@serializationIgnore
		public Frame startFrame;
		public int startIndex;
	}
	public Charge[] charges;
	@serializedAs!(CharFrame[int])
	public CharFrame[int] frames;
	
	public this()
	{
		injuredIndices = [ int(50), int(51), int(52) ];
		frames = [
			int(1): new CharFrame(),
		];
	}
}

public class Frame
{
	public string name;
}

public final class CharFrame : Frame
{
	public int pic;
	public State state;
	@serializedAs!vec3fProxy
	public vec3f vector;
	public VectorHint vectorHint;
	@serializedAs!vec3fProxy
	public vec3f controlledVelocity;
	public int wait;
	public ushort defending;
	public bool dirControl;
	union
	{
		@serializationIgnore
		public Frame nextFrame;
		public int nextIndex;
	}
	union
	{
		@serializationIgnore
		public Frame injuredFrame;
		public int injuredIndex;
	}
	union
	{
		@serializationIgnore
		public Frame dizzyFrame;
		public int dizzyIndex;
	}
	union
	{
		@serializationIgnore
		public Frame landingFrame;
		public int landingIndex;
	}
	union
	{
		@serializationIgnore
		public Frame breakDefendFrame;
		public int breakDefendIndex;
	}
	union
	{
		@serializationIgnore
		public Frame stopFrame;
		public int stopIndex;
	}
	public Timer timer;
	public Charger[] chargers;
	public GameKeyEvent[] gameKeyEvents;
}

public final class MapData
{
	public string name;
	//public SpriteSheet[] spriteSheets;
	//public SpriteFrame[] spriteFrames;
	public int width;
	public int zPlace;
	public int zWidth;
	public float staticFrictionFactor = 1f;
	public float dynamicfrictionFactor = 0.8f;
	public Charge[] charges;
	public MapFrame[int] mapFrames;
}

public final class MapFrame : Frame
{
	public int wait;
	union
	{
		@serializationIgnore
		public Frame nextFrame;
		public int nextIndex;
	}
	public Charger[] chargers;
	public MapLayer[] mapLayers;
}

public final class MapLayer
{
	public int x;
	public int y;
	public int z;
	public int pic;
}

public struct Charge
{
	public float amount = 0;
	public float regen = 0;
	public float max = 0;
}

public struct Charger
{
	public int charge;
	public float amount = 0;
	union
	{
		@serializationIgnore
		public Frame chargeLowFrame;
		public int chargeLowIndex;
	}
	union
	{
		@serializationIgnore
		public Frame chargeFullFrame;
		public int chargeFullIndex;
	}
	public bool forceUsage;
}

public struct Spawn
{
	public ObjectType objectType;
	public int objectId;
	@serializedAs!vec3fProxy
	{
		public vec3f position;
		public vec3f velocity;
		public vec3f controlledVelocity;
	}
}

public struct WeaponPoint
{
	public int x;
	public int y;
	public float angle;
	@serializedAs!vec3fProxy
	public vec3f velocity;
	public int atkType;
	public bool cover;
}

public enum ObjectType
{
	Char,
	Weapon,
	HeavyWeapon,
	Chunk,
	Energy,
	Drink
}

public struct GameKeyStates
{
	public KeyState up;
	public KeyState down;
	public KeyState right;
	public KeyState left;
	public KeyState jump;
	public KeyState attack;
	public KeyState defend;
}

public struct GameKeyEvent
{
	public int frameToGo;
	public GameKeyStates gameKeyState;
}

public enum KeyState : byte
{
	Any,
	Pressed,
	Released,
	Down,
	Up
}

public final class Timer
{
	union
	{
		@serializationIgnore
		public Frame frame;
		public int index;
	}
	public int interval;
	//public State[] permittedStates;
}

public enum VectorHint : byte
{
	Addition,
	Assignment,
	Multiply,
}

public enum State : byte
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
