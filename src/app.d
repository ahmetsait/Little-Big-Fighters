module app;

import std.stdio : write, writeln, writefln, stderr;
import std.format : format;
import std.string : fromStringz, toStringz;

import bindbc.sdl.config;
import bindbc.sdl.dynload;
import bindbc.sdl.bind.sdlvideo;
import bindbc.sdl.bind.sdlvulkan;

import bindbc.freeimage.types;
import bindbc.freeimage.binddynamic;

import bindbc.freetype.config;
import bindbc.freetype.dynload;

import bindbc.hb.config;
import bindbc.hb.dynload;

import erupted;
import loader = erupted.vulkan_lib_loader;

import lbf.core;

public immutable appName = "Little Big Fighters";

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
int main(string[] args)
{
	return Main(args);
}

int Main(string[] args)
{
	foreach (arg; args)
		writeln(arg);
	
	//region Load
	debug write("Loading SDL... ");
	if (loadSDL() < SDLSupport.sdl2010)
	{
		writeln("Failed to load SDL library.");
		return 1;
	}
	debug writeln("Done.");
	
	//debug write("Loading FreeImage... ");
	//if (loadFreeImage() < FISupport.fi318)
	//{
	//	writeln("Failed to load FreeImage library.");
	//	return 1;
	//}
	//debug writeln("Done.");
	
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
	
	//debug write("Loading HarfBuzz... ");
	//if (loadHarfBuzz() < HBSupport.v1_7_2)
	//{
	//	writeln("Failed to load HarfBuzz library.");
	//	return 1;
	//}
	//debug writeln("Done.");
	
	debug write("Loading Vulkan... ");
	typeof(vkGetInstanceProcAddr) vkLoad;
	if (loader.loadVulkanLib() == false ||
		(vkLoad = loader.loadGetInstanceProcAddr()) == null)
	{
		writeln("Failed to load Vulkan library.");
		return 1;
	}
	loadGlobalLevelFunctions(vkLoad);
	debug writeln("Done...");
	//endregion
	
	import bindbc.sdl.bind.sdl;
	
	debug write("Initializing SDL... ");
	SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER | SDL_INIT_EVENTS)
		.enforceSDLNotNegative("Cannot initialize SDL.");
	debug writeln("Done.");
	
	{
		import lbf.game;
		Game game = new Game();
		scope(exit) destroy(game);
		game.run();
	}
	
	import asdf;
	import lbf.gamedata;
	import std.file : write;
	auto ch = new CharData();
	//write("kek.json", serializeToJsonPretty(ch));
	
	SDL_Quit();
	debug writeln("Terminated SDL library.");
	
	return 0;
}
