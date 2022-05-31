module app;

import std.stdio : write, writeln, writefln, stderr;
import std.format : format;
import std.string : fromStringz, toStringz;

import bindbc.sdl.config;
import bindbc.sdl.dynload;
import bindbc.sdl.bind.sdl;

import lbf.core;

public immutable appName = "Little Big Fighters";

version(LF2LBF)
{
	struct CommandLine
	{
		string path;
	}
	
	int main(string[] args)
	{
		import std.file;
		import asdf.serialization;
		import lbf.gamedata;
		import lf2;
		import lf2lbf;
		
		Token[] dataTxtTokens = parseLf2Data(readText(r"D:\Games\LF2\data\data.txt"));
		Token[] stageTokens = parseLf2Data(decryptLf2Data(cast(ubyte[])read(r"D:\Games\LF2\data\stage.dat")));
		Token[] chTokens = parseLf2Data(decryptLf2Data(cast(ubyte[])read(r"D:\Games\LF2\data\davis.dat")));
		Token[] weaponTokens = parseLf2Data(decryptLf2Data(cast(ubyte[])read(r"D:\Games\LF2\data\weapon0.dat")));
		Token[] bgTokens = parseLf2Data(decryptLf2Data(cast(ubyte[])read(r"D:\Games\LF2\bg\sys\qi\bg.dat")));
		
		sDataTxt datatxt;
		deserializeData(dataTxtTokens, datatxt);
		//writeln(serializeToJsonPretty(stage));
		std.file.write("data.json", serializeToJsonPretty(datatxt));
		
		sStageFile stage;
		deserializeData(stageTokens, stage);
		//writeln(serializeToJsonPretty(stage));
		std.file.write("stage.json", serializeToJsonPretty(stage));
		
		sDataFile ch;
		deserializeData(chTokens, ch);
		//writeln(serializeToJsonPretty(ch));
		std.file.write("davis.json", serializeToJsonPretty(ch));
		
		sDataFile weapon;
		deserializeData(weaponTokens, weapon);
		//writeln(serializeToJsonPretty(weapon));
		std.file.write("weapon0.json", serializeToJsonPretty(weapon));
		
		sBackgroundFile bg;
		deserializeData(bgTokens, bg);
		//writeln(serializeToJsonPretty(bg));
		std.file.write("qi.json", serializeToJsonPretty(bg));
		
		return 0;
	}
}
else
{
	version(WinMain)
	{
		import std.utf : toUTF16z, toUTF8;
		import core.runtime : Runtime;
		import core.sys.windows.shellapi : CommandLineToArgvW;
		import core.sys.windows.winbase : GetCommandLineW, LocalFree;
		import core.sys.windows.windef : LPSTR, HINSTANCE;
		import core.sys.windows.winuser : MessageBoxW, MB_OK, MB_ICONEXCLAMATION;
		pragma(lib, "user32");
		extern (Windows) int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
		{
			if (!Runtime.initialize())
				return 1;
			
			try
			{
				int argc;
				wchar** argv = CommandLineToArgvW(GetCommandLineW(), &argc);
				scope(exit) LocalFree(argv);
				{
					string[] args = new string[argc];
					for (size_t i = 0; i < argc; i++)
						args[i] = fromStringz(argv[i]).toUTF8();
					return Main(args);
				}
			}
			catch (Throwable ex)
			{
				MessageBoxW(null, ex.toString().toUTF16z(), "Error", MB_OK | MB_ICONEXCLAMATION);
				return 1;
			}
			finally
			{
				Runtime.terminate();
			}
		}
	}
	else
	{
		int main(string[] args)
		{
			return Main(args);
		}
	}
	
	int Main(string[] args)
	{
		foreach (arg; args)
			writeln(arg);
		
		//region Load
		debug write("Loading SDL... ");
		if (loadSDL() < SDLSupport.sdl208)
		{
			writeln("Failed to load SDL library.");
			return 1;
		}
		debug writeln("Done.");
		
		import bindbc.freeimage.types;
		import bindbc.freeimage.binddynamic;
		
		debug write("Loading FreeImage... ");
		if (loadFreeImage() < FISupport.fi317)
		{
			writeln("Failed to load FreeImage library.");
			return 1;
		}
		debug writeln("Done.");
		
		//import bindbc.freetype.config;
		//import bindbc.freetype.dynload;
		//
		//debug write("Loading FreeType... ");
		//FTSupport ft = loadFreeType();
		//if (ft != ftSupport)
		//{
		//	if (ft == FTSupport.noLibrary)
		//		writeln("Cannot find FreeType library.");
		//	else if (ft == FTSupport.badLibrary)
		//		writeln("FreeType library.");
		//	return 1;
		//}
		//debug writeln("Done.");
		
		//import bindbc.hb.config;
		//import bindbc.hb.dynload;
		//
		//debug write("Loading HarfBuzz... ");
		//if (loadHarfBuzz() < HBSupport.v1_7_2)
		//{
		//	writeln("Failed to load HarfBuzz library.");
		//	return 1;
		//}
		//debug writeln("Done.");
		
		//import erupted;
		//import loader = erupted.vulkan_lib_loader;
		//
		//debug write("Loading Vulkan... ");
		//typeof(vkGetInstanceProcAddr) vkLoad;
		//if (loader.loadVulkanLib() == false ||
		//	(vkLoad = loader.loadGetInstanceProcAddr()) == null)
		//{
		//	writeln("Failed to load Vulkan library.");
		//	return 1;
		//}
		//loadGlobalLevelFunctions(vkLoad);
		//debug writeln("Done...");
		//endregion
		
		{
			import lbf.game;
			Game game = new Game();
			scope(exit) destroy(game);
			game.run();
		}
		
		SDL_Quit();
		debug writeln("Terminated SDL library.");
		
		return 0;
	}
}
