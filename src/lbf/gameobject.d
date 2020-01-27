module lbf.gameobject;

import gfm.math.vector;

import lbf.gamedata;
import lbf.graphics.opengl;
import lbf.graphics.opengl.gl;

final class Char
{
	vec3f position;
	vec3f velocity;
	byte facing;
	
	CharFrame currentFrame;
	int currentIndex = 1;
	
	CharFrame lastFrame;
	int lastIndex;
	
	bool hitstop;
	ubyte team;
	int heldWeapon = -1;
	
	KeyStatePack keyStates;
	
	Charge* hp;
	Charge* darkHp;
	Charge* mp;
	Charge* armor;
	Charge* fall;
	Charge* resist;
	
	string dataFile;
	Charge[] charges;
	CharData data;
}
