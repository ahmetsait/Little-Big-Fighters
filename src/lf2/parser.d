module lf2.parser;

version(LF2LBF):

debug import std.stdio;
import std.algorithm.comparison : cmp;
import std.algorithm.searching : canFind;
import std.array : appender, array;
import std.conv : to;
import std.format : format;
import std.traits;
import std.range.primitives : ElementEncodingType;

import lf2.gamedata;

struct Token
{
	const(char)[] str;
	size_t line, col;
	
	string toString()
	{
		return format(`"%s"[line: %d col: %d]  `, str, line, col);
	}
}

class ParserException : Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
		@nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
}

/// This function tokenizes LF2 data and returns a Token array.
/// Returned tokens' slices point to the given string.
Token[] parseData(const(char)[] data) pure
{
	//import std.uni : isWhite;
	import std.string : representation;
	import std.utf : byCodeUnit;
	static immutable delimeters = " \r\n\t".representation;
	
	auto slices = appender!(Token[]);
	
	bool inToken = false;
	size_t tokenStart = 0, tokenCol = 1, tokenLine = 1;
	
	size_t line = 1, col = 1;
	
	foreach(i, ch; data.representation)
	{
		if (delimeters.canFind(ch))
		{
			if (inToken)
			{
				slices ~= Token(data[tokenStart .. i], tokenLine, tokenCol);
				inToken = false;
			}
		}
		else
		{
			if (!inToken)
			{
				inToken = true;
				tokenStart = i;
				tokenLine = line;
				tokenCol = col;
			}
		}
		
		if(ch == '\n')
		{
			line++;
			col = 1;
		}
		else
			col++;
	}
	if (inToken)
		slices ~= Token(data[tokenStart .. $], tokenLine, tokenCol);
	
	return slices[];
}

enum DataState
{
	none,
	bmp,
	frame,
	weapon_strength_list,
	bdy,
	itr,
	wpoint,
	opoint,
	cpoint,
	bpoint,
	entry,
	stage,
	phase,
	layer
}

enum DataTxtState
{
	None,
	Objects,
	Backgrounds,
}

DataTxt ReadDataTxt(const(char)[] dataTxt)
{
	Token[] tokens = parseData(dataTxt);
	DataTxt result;
	
	for(size_t i = 0; i < tokens.length; i++)
	{
		switch(tokens[i].str)
		{
			case "<object>":
				auto objs = appender(&result.objects);
				ObjectInfo obj;
				bool inObject = false;
			Lloop1:
				for(i++; i < tokens.length; i++)
				{
					switch(tokens[i].str)
					{
						case "id:":
							if (inObject)
							{
								objs ~= obj;
								obj = ObjectInfo();
							}
							inObject = true;
							obj.id = tokens[++i].str.to!int;
							break;
						case "type:":
							if (!inObject)
								continue Lloop1;
							obj.type = cast(ObjectType)tokens[++i].str.to!int;
							break;
						case "file:":
							if (!inObject)
								continue Lloop1;
							obj.file = tokens[++i].str.idup;
							break;
						case "<object_end>":
							if (inObject)
								objs ~= obj;
							inObject = false;
							break Lloop1;
						default:
							//ignore
							break;
					}
				}
				break;
			case "<background>":
				auto bgs = appender(&result.backgrounds);
				BackgroundInfo bg;
				bool inBg = false;
			Lloop2:
				for(i++; i < tokens.length; i++)
				{
					switch(tokens[i].str)
					{
						case "id:":
							if (inBg)
							{
								bgs ~= bg;
								bg = BackgroundInfo();
							}
							inBg = true;
							bg.id = tokens[++i].str.to!int;
							break;
						case "file:":
							if (!inBg)
								continue Lloop2;
							bg.file = tokens[++i].str.idup;
							break;
						case "<background_end>":
							if (inBg)
								bgs ~= bg;
							inBg = false;
							break Lloop2;
						default:
							//ignore
							break;
					}
				}
				break;
			default:
				//ignore
				break;
		}
	}
	
	return result;
}

/+
alias dOp = deserializeData!sOpoint;
alias dBp = deserializeData!sBpoint;
alias dCp = deserializeData!sCpoint;
alias dWp = deserializeData!sWpoint;
alias dItr = deserializeData!sItr;
alias dBdy = deserializeData!sBdy;
alias dFr = deserializeData!sFrame;
//alias dWSE = deserializeData!sWeaponStrengthEntry;
alias dWSL = deserializeData!sWeaponStrengthList;
//alias dBF = deserializeData!sBmpFile;
alias dBmp = deserializeData!sBmp;
alias dDF = deserializeData!sDataFile;
//alias dSp = deserializeData!sSpawn;
alias dPh = deserializeData!sPhase;
alias dSt = deserializeData!sStage;
alias dSF = deserializeData!sStageFile;
alias dBg = deserializeData!sBackgroundFile;
+/

size_t deserializeData(T)(const(Token)[] tokens, out T data, int level = 0)
{
	//pragma(msg, T, __traits(hasMember, T, "deserialize"));
	static if (__traits(hasMember, T, "deserialize"))
		return T.deserialize(tokens, data);
	else
	{
		static bool compareToken(const(char)[] tname, TokenSyntax ttype, const(char)[] str)
		{
			final switch (ttype)
			{
				case TokenSyntax.plain:
					return str == tname;
				case TokenSyntax.property:
					return str.length >= 1 && str[0 .. $ - 1] == tname && str[$ - 1] == ':';
				case TokenSyntax.xml:
					return str.length >= 2 && str[1 .. $ - 1] == tname &&
						str[0] == '<' && str[$ - 1] == '>';
			}
		}
		
		foreach (field; FieldNameTuple!(T))
		{
			alias type = typeof(__traits(getMember, data, field));
			static if (hasUDA!(__traits(getMember, data, field), TokenIndex))
			{
				enum int tokenIndex = getUDAs!(__traits(getMember, data, field), TokenIndex)[0].index;
				
				static if (is(type == string))
				{
					// We duplicate here so the whole file can be freed
					__traits(getMember, data, field) = tokens[tokenIndex].str.idup;
				}
				else static if (is(type == enum) && isIntegral!enumType)
				{
					__traits(getMember, data, field) = cast(type)to!enumType(tokens[tokenIndex].str);
				}
				else static if (isIntegral!type || isFloatingPoint!type)
				{
					__traits(getMember, data, field) = to!type(tokens[tokenIndex].str);
				}
			}
		}
		size_t i = 0;
	Lfor:
		for (i = 0; i < tokens.length; i++)
		{
			foreach(field; FieldNameTuple!(T))
			{
				alias type = typeof(__traits(getMember, data, field));
				enum tokenTypes = getUDAs!(__traits(getMember, data, field), TokenSyntax);
				
				static if (tokenTypes.length > 0)
					enum TokenSyntax tokenType = tokenTypes[0];
				else
					enum TokenSyntax tokenType = TokenSyntax.property;
				
				alias enumType = OriginalType!type;
				alias elemType = ElementEncodingType!type;
				
				//pragma(msg, type, " ", enumType, " ", elemType, " ", field);
				
				static if (is(type == string))
				{
					if (compareToken(field, tokenType, tokens[i].str))
					{
						// We duplicate here so the whole file can be freed
						__traits(getMember, data, field) = tokens[++i].str.idup;
						goto Lout;
					}
				}
				else static if (is(type == enum) && isIntegral!enumType)
				{
					if (compareToken(field, tokenType, tokens[i].str))
					{
						__traits(getMember, data, field) = cast(type)tokens[++i].str.to!enumType;
						goto Lout;
					}
				}
				else static if (isIntegral!type || isFloatingPoint!type)
				{
					if (compareToken(field, tokenType, tokens[i].str))
					{
						__traits(getMember, data, field) = to!type(tokens[++i].str);
						goto Lout;
					}
				}
				else static if (isStaticArray!type && (isIntegral!elemType || isFloatingPoint!elemType))
				{
					if (compareToken(field, tokenType, tokens[i].str))
					{
						foreach (n; 0 .. type.length)
						{
							__traits(getMember, data, field)[n] = tokens[++i].str.to!elemType;
						}
						goto Lout;
					}
				}
				else static if (isDynamicArray!type && isAggregateType!elemType &&
					__traits(hasMember, elemType, "endToken"))
				{
					enum bool regex = elemType.beginToken.regex;
					if (compareToken(elemType.beginToken.str, TokenSyntax.plain, tokens[i].str))
					{
						elemType elem;
						i += deserializeData!elemType(tokens[i + 1 .. $], elem, level + 1);
						__traits(getMember, data, field) ~= elem;
						goto Lout;
					}
				}
				else static if (isAggregateType!type && __traits(hasMember, type, "endToken"))
				{
					enum bool regex = type.beginToken.regex;
					if (compareToken(type.beginToken.str, TokenSyntax.plain, tokens[i].str))
					{
						i += deserializeData!type(tokens[i + 1 .. $], __traits(getMember, data, field), level + 1);
						goto Lout;
					}
				}
				else
				{
					static assert(false, "Unhandled member: \"" ~ type.stringof ~ " " ~ field ~ "\"");
				}
			}
			
		Lout:
			static if (__traits(hasMember, T, "endToken"))
			{
				if (tokens[i].str == T.endToken.str)
					break Lfor;
			}
		}
		
		return i;
	}
}
