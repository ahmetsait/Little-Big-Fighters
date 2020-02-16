module lbf.gameobject;

import gfm.math.vector;

import lbf.gamedata;
import lbf.graphics.opengl;
import lbf.graphics.opengl.gl;

final class Hero
{
	vec3f position = vec3f(0, 0, 0);
	vec3f velocity = vec3f(0, 0, 0);
	float facing = 1;
	
	HeroFrame currentFrame;
	int currentIndex = 1;
	
	HeroFrame lastFrame;
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
	HeroData data;
}

final class Weapon	
{
	this()
	{
		
	}
	
	vec3f position = vec3f(0, 0, 0);
	vec3f velocity = vec3f(0, 0, 0);
	float facing = 1;
	
	HeroFrame currentFrame;
	int currentIndex = 1;
	
	HeroFrame lastFrame;
	int lastIndex;
	
	bool hitstop;
	ubyte team;
	Hero owner;
	
	KeyStatePack keyStates;
	
	Charge* hp;
	
	string dataFile;
	Charge[] charges;
	WeaponData data;
}