module lf2.gamedata;

version(LF2LBF):

debug import std.stdio;
import std.algorithm.comparison : cmp;
import std.algorithm.searching : canFind;
import std.array : appender, array;
import std.conv : to;
import std.format : format;
import std.traits;
import std.typecons;
import std.range : ElementEncodingType;

import lf2.parser : Token;

struct BeginToken
{
	string str;
	bool regex = false;
}

struct EndToken
{
	string str;
}

struct TokenIndex
{
	int index;
}

enum TokenSyntax
{
	property,
	plain,
	xml,
}

@BeginToken("opoint:")
@EndToken("opoint_end:")
struct sOpoint
{
	int kind;
	int x;
	int y;
	int action;
	int dvx;
	int dvy;
	int oid;
	int facing;
}

@BeginToken("bpoint:")
@EndToken("bpoint_end:")
struct sBpoint
{
	int x;
	int y;
}

@BeginToken("cpoint:")
@EndToken("cpoint_end:")
struct sCpoint
{
	int kind;
	int x;
	int y;
	union
	{
		int injury; /// if its kind 2 this is fronthurtact
		int fronthurtact;
	}
	union
	{
		int cover; /// if its kind 2 this is backhurtact
		int backhurtact;
	}
	int vaction;
	int aaction;
	int jaction;
	int daction;
	int throwvx;
	int throwvy;
	int hurtable;
	int decrease;
	int dircontrol;
	int taction;
	int throwinjury;
	int throwvz;
}

@BeginToken("wpoint:")
@EndToken("wpoint_end:")
struct sWpoint
{
	int kind;
	int x;
	int y;
	int weaponact;
	int attacking;
	int cover;
	int dvx;
	int dvy;
	int dvz;
}

@BeginToken("itr:")
@EndToken("itr_end:")
struct sItr
{
	int kind;
	int x;
	int y;
	int w;
	int h;
	int dvx;
	int dvy;
	int fall;
	int arest;
	int vrest;
	int effect;
	int[2] catchingact;
	int[2] caughtact;
	int bdefend;
	int injury;
	int zwidth;
}

@BeginToken("bdy:")
@EndToken("bdy_end:")
struct sBdy
{
	int kind;
	int x;
	int y;
	int w;
	int h;
}

@BeginToken("<frame>")
@EndToken("<frame_end>")
struct sFrame
{
	@TokenIndex(0)
	int id;
	@TokenIndex(1)
	string name;
	int pic;
	int state;
	int wait;
	int next;
	int dvx;
	int dvy;
	int dvz;
	int hit_a;
	int hit_d;
	int hit_j;
	int hit_Fa;
	int hit_Ua;
	int hit_Da;
	int hit_Fj;
	int hit_Uj;
	int hit_Dj;
	int hit_ja;
	int mp;
	int centerx;
	int centery;
	string sound;
	sOpoint opoint;
	sBpoint bpoint;
	sCpoint cpoint;
	sWpoint wpoint;
	sItr[] itrs;
	sBdy[] bdys;
}

@BeginToken("entry:")
struct sWeaponStrengthEntry
{
	@TokenIndex(0)
	int id;
	@TokenIndex(1)
	string name;
	int dvx;
	int dvy;
	int fall;
	int arest;
	int vrest;
	int effect;
	int bdefend;
	int injury;
}

@BeginToken("<weapon_strength_list>")
@EndToken("<weapon_strength_list_end>")
struct sWeaponStrengthList
{
	sWeaponStrengthEntry[] entries;
	
	static size_t deserialize(const(Token)[] tokens, out sWeaponStrengthList data)
	{
		sWeaponStrengthEntry entry;
		bool inEntry = false;
		auto entries = appender(&data.entries);
		
		size_t i = 0;
	Lfor:
		for(i = 0; i < tokens.length; i++)
		{
		Lswitch:
			switch(tokens[i].str)
			{
				case "entry:":
					if (inEntry)
					{
						entries ~= entry;
						entry = sWeaponStrengthEntry();
					}
					entry.id = tokens[++i].str.to!int;
					// We duplicate here so the whole file can be freed
					entry.name = tokens[++i].str.idup;
					inEntry = true;	
					break;
				case "dvx:":
					if (inEntry)
						entry.dvx = tokens[++i].str.to!int;
					break;
				case "dvy:":
					if (inEntry)
						entry.dvy = tokens[++i].str.to!int;
					break;
				case "fall:":
					if (inEntry)
						entry.fall = tokens[++i].str.to!int;
					break;
				case "arest:":
					if (inEntry)
						entry.arest = tokens[++i].str.to!int;
					break;
				case "vrest:":
					if (inEntry)
						entry.vrest = tokens[++i].str.to!int;
					break;
				case "effect:":
					if (inEntry)
						entry.effect = tokens[++i].str.to!int;
					break;
				case "bdefend:":
					if (inEntry)
						entry.bdefend = tokens[++i].str.to!int;
					break;
				case "injury:":
					if (inEntry)
						entry.injury = tokens[++i].str.to!int;
					break;
				case getUDAs!(typeof(this), EndToken)[0].str:
					if (inEntry)
						entries ~= entry;
					break Lfor;
				default:
					break;
			}
		}
		
		return i;
	}
}

@BeginToken(`^file\S*$`, true)
struct sBmpFile
{
	@TokenIndex(0)
	string path;
	int w;
	int h;
	int row;
	int col;
}

@BeginToken("<bmp_begin>")
@EndToken("<bmp_end>")
struct sBmp
{
	string name;
	string head;
	string small;
	sBmpFile[] files;
	@(TokenSyntax.plain)
	{
		int walking_frame_rate;
		float walking_speed;
		float walking_speedz;
		int running_frame_rate;
		float running_speed;
		float running_speedz;
		float heavy_walking_speed;
		float heavy_walking_speedz;
		float heavy_running_speed;
		float heavy_running_speedz;
		float jump_height;
		float jump_distance;
		float jump_distancez;
		float dash_height;
		float dash_distance;
		float dash_distancez;
		float rowing_height;
		float rowing_distance;
	}
	int weapon_hp;
	int weapon_drop_hurt;
	string weapon_hit_sound;
	string weapon_drop_sound;
	string weapon_broken_sound;
	
	static size_t deserialize(const(Token)[] tokens, out sBmp data)
	{
		sBmpFile file;
		bool inFile = false;
		auto bmp_files = appender(&data.files);
		
		size_t i = 0;
	Lfor:
		for(i = 0; i < tokens.length; i++)
		{
		Lswitch:
			switch(tokens[i].str)
			{
				foreach (field; FieldNameTuple!sBmp)
				{
					alias type = typeof(__traits(getMember, data, field));
					enum tokenTypes = getUDAs!(__traits(getMember, data, field), TokenSyntax);
					static if (tokenTypes.length > 0)
						enum TokenSyntax tokenType = tokenTypes[0];
					else
						enum TokenSyntax tokenType = TokenSyntax.property;
					
					static if (tokenType == TokenSyntax.plain)
					{
						case field:
					}
					else static if (tokenType == TokenSyntax.property)
					{
						case field ~ ":":
					}
					
					static if (is(type == string))
					{
						// We duplicate here so the whole file can be freed
						__traits(getMember, data, field) = tokens[++i].str.idup;
					}
					else static if (isIntegral!type || isFloatingPoint!type)
					{
						__traits(getMember, data, field) = tokens[++i].str.to!type;
					}
					break Lswitch;
				}
				foreach (field; FieldNameTuple!sBmpFile)
				{
					alias type = typeof(__traits(getMember, file, field));
					
					case field ~ ":":
					
					static if (isIntegral!type || isFloatingPoint!type)
					{
						__traits(getMember, file, field) = tokens[++i].str.to!type;
					}
					break Lswitch;
				}
				
				case getUDAs!(typeof(this), EndToken)[0].str:
					if (inFile)
						bmp_files ~= file;
					break Lfor;
				default:
					string f = "file";
					if (tokens[i].str .length >= f.length && tokens[i].str[0 .. f.length] == f)
					{
						if (inFile)
						{
							bmp_files ~= file;
							file = sBmpFile();
						}
						// We duplicate here so the whole file can be freed
						file.path = tokens[++i].str.idup;
						inFile = true;
					}
					break Lswitch;
			}
		}
		
		return i;
	}
}

struct sDataFile
{
	sBmp bmp;
	sWeaponStrengthList weapon_strength_list;
	sFrame[] frames;
}

@BeginToken("id:")
struct sSpawn
{
	@TokenIndex(0)
	int id;
	int x;
	int y;
	int hp;
	int times;
	int reserve;
	int join;
	int join_reserve;
	int act;
	float ratio = 0;
	Role role;
}

enum Role
{
	None = 0,
	Soldier = 1,
	Boss = 2,
}

@BeginToken("<phase>")
@EndToken("<phase_end>")
struct sPhase
{
	int bound;
	string music;
	sSpawn[] spawns;
	int when_clear_goto_phase = -1;
	
	static size_t deserialize(const(Token)[] tokens, out sPhase phase)
	{
		sSpawn spawn;
		bool inSpawn = false;
		auto phase_spawns = appender(&phase.spawns);
		
		size_t i = 0;
	Lfor:
		for(i = 0; i < tokens.length; i++)
		{
		Lswitch:
			switch(tokens[i].str)
			{
				case "bound:":
					phase.bound = tokens[++i].str.to!int;
					break;
				case "music:":
					// We duplicate here so the whole file can be freed
					phase.music = tokens[++i].str.idup;
					break;
				case "id:":
					if (inSpawn)
					{
						phase_spawns ~= spawn;
						spawn = sSpawn();
					}
					spawn.id = tokens[++i].str.to!int;
					spawn.hp = 500;
					spawn.act = 9;
					spawn.times = 1;
					spawn.x = 80 + phase.bound;
					inSpawn = true;
					break;
				case "x:":
					if (inSpawn)
						spawn.x = tokens[++i].str.to!int;
					break;
				case "y:":
					if (inSpawn)
						spawn.y = tokens[++i].str.to!int;
					break;
				case "hp:":
					if (inSpawn)
						spawn.hp = tokens[++i].str.to!int;
					break;
				case "act:":
					if (inSpawn)
						spawn.act = tokens[++i].str.to!int;
					break;
				case "times:":
					if (inSpawn)
						spawn.times = tokens[++i].str.to!int;
					break;
				case "ratio:":
					if (inSpawn)
						spawn.ratio = tokens[++i].str.to!double;
					break;
				case "reserve:":
					if (inSpawn)
						spawn.reserve = tokens[++i].str.to!int;
					break;
				case "join:":
					if (inSpawn)
						spawn.join = tokens[++i].str.to!int;
					break;
				case "join_reserve:":
					if (inSpawn)
						spawn.join_reserve = tokens[++i].str.to!int;
					break;
				case "<boss>":
					if (inSpawn)
						spawn.role = Role.Boss;
					break;
				case "<soldier>":
					if (inSpawn)
					{
						spawn.role = Role.Soldier;
						if (spawn.times == 0)
							spawn.times = 50;
					}
					break;
				case "when_clear_goto_phase:":
					phase.when_clear_goto_phase = tokens[++i].str.to!int;
					break;
				case getUDAs!(typeof(this), EndToken)[0].str:
					if (inSpawn)
						phase_spawns ~= spawn;
					break Lfor;
				default:
					break;
			}
   		}
		
		return i;
	}
}

@BeginToken("<stage>")
@EndToken("<stage_end>")
struct sStage
{
	int id;
	sPhase[] phases;
}

struct sStageFile
{
	sStage[] stages;
}

@BeginToken("layer:")
@EndToken("layer_end")
struct sLayer
{
	@TokenIndex(0)
	string bmp;
	int transparency;
	int width;
	int x;
	int y;
	int height;
	int loop;
	int c1;
	int c2;
	int cc;
}

struct sBackgroundFile
{
	string name;
	int width;
	int[2] zboundary;
	int[2] shadowsize;
	string shadow;
	sLayer[] layers;
}

enum sObjectType
{
	Char	= 0,
	Weapon	= 1,
	HeavyWeapon	= 2,
	SpecialAttack	= 3,
	ThrowWeapon	= 4,
	Criminal	= 5,
	Drink	= 6
}

enum sDataType
{
	Object	= 0,
	Stage	= 1,
	Background	= 2
}

@BeginToken("id:")
struct ObjectInfo
{
	@TokenIndex(0)
	int id;
	sObjectType type;
	string file;
}

@BeginToken("id:")
struct sBackgroundInfo
{
	@TokenIndex(0)
	int id;
	string file;
}

struct sDataTxt
{
	@BeginToken("<object>")
	@EndToken("<object_end>")
	ObjectInfo[] objects;
	
	@BeginToken("<background>")
	@EndToken("<background_end>")
	sBackgroundInfo[] backgrounds;
}
