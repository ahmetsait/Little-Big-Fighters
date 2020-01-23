module lbf.game;

import std.stdio : write, writeln, writefln, stderr;
import std.format : format;
import std.string : fromStringz, toStringz;

import bindbc.sdl.bind.sdl;
import bindbc.sdl.bind.sdlvideo;
import bindbc.sdl.bind.sdlevents;
import bindbc.sdl.bind.sdlkeyboard;
import bindbc.sdl.bind.sdlkeycode;
import bindbc.sdl.bind.sdltimer;
import bindbc.sdl.bind.sdlvulkan;

import erupted;

import app;
import lbf.core;
import lbf.events;
import lbf.graphics;

public final class Game
{
private:
	SDL_Window* window;
	Vulkan vulkan;
	
	public this()
	{
		window = SDL_CreateWindow(appName.ptr,
			SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 794, 550,
			SDL_WINDOW_VULKAN | SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIDDEN)
			.enforceSDLNotNull("Cannot create SDL window.");
		debug writeln("Created SDL window.");
		
		vulkan = new Vulkan(appName, VK_MAKE_VERSION(0, 1, 0), window);
	}
	
	import std.datetime.stopwatch, core.thread;
	
	immutable uint updatePerSecond = 30;
	immutable delayPerSecond = dur!"msecs"(1000) / updatePerSecond;
	
	bool _running = false;
	public bool running() @property
	{
		return _running;
	}
	
	public void run()
	{
		_running = true;
		SDL_ShowWindow(window);
		
		StopWatch sw = StopWatch(AutoStart.yes);
		
		while(_running)
		{
			sw.reset;
			update();
			render();
			auto tickDiff = sw.peek();
			if (tickDiff < delayPerSecond)
			{
				immutable timeLeft = delayPerSecond - tickDiff;
				//writeln(tickDiff);
				Thread.sleep(timeLeft);
			}
		}
		SDL_HideWindow(window);
	}
	
	public void exit()
	{
		SDL_Event event = void;
		event.type = SDL_QUIT;
		event.quit.timestamp = SDL_GetTicks();
		SDL_PushEvent(&event);
	}
	
	Event!() keymapChanged;
	Event!() clipboardUpdate;
	
	void update()
	{
		SDL_Event event;
		while(SDL_PollEvent(&event))
		{
			if (event.type == SDL_EventType.SDL_QUIT)
				_running = false;
			if (event.type == SDL_EventType.SDL_KEYDOWN)
				exit();
			switch(event.type)
			{
				case SDL_QUIT:
					_running = false;
					break;
				case SDL_WINDOWEVENT:
					switch (event.window.event)
					{
						case SDL_WINDOWEVENT_SHOWN:
							//_visible = true;
							//onShown();
							break;
						case SDL_WINDOWEVENT_HIDDEN:
							//_visible = false;
							//onHidden();
							break;
						case SDL_WINDOWEVENT_EXPOSED:
							//onExposed(event);
							break;
						case SDL_WINDOWEVENT_MOVED:
							//onMoved();
							break;
						case SDL_WINDOWEVENT_RESIZED:
							//onResized();
							break;
						case SDL_WINDOWEVENT_SIZE_CHANGED:
							//_bounds.width = event.window.data1;
							//_bounds.height = event.window.data2;
							//onSizeChanged();
							break;
						case SDL_WINDOWEVENT_MINIMIZED:
							//_minimized = true;
							//onMinimized();
							break;
						case SDL_WINDOWEVENT_MAXIMIZED:
							//_maximized = true;
							//onMaximized();
							break;
						case SDL_WINDOWEVENT_RESTORED:
							//_minimized = false;
							//_maximized = false;
							//onRestored();
							break;
						case SDL_WINDOWEVENT_ENTER:
							//onMouseEnter();
							break;
						case SDL_WINDOWEVENT_LEAVE:
							//onMouseLeave();
							break;
						case SDL_WINDOWEVENT_FOCUS_GAINED:
							//_hasFocus = true;
							//onFocusGained();
							break;
						case SDL_WINDOWEVENT_FOCUS_LOST:
							//_hasFocus = false;
							//onFocusLost();
							break;
						case SDL_WINDOWEVENT_CLOSE:
							//bool cancelled = false;
							//onClosing(&cancelled);
							//if (!cancelled)
							//{
							//	onClosed();
							//	dispose();
							//}
							break;
						case SDL_WINDOWEVENT_TAKE_FOCUS:
							//onFocusOffered();
							break;
						case SDL_WINDOWEVENT_HIT_TEST:
							//onHitTest();
							break;
						default:
							debug writeln("Unhandled window event: ", event.window.event);
							break;
					}
					break;
				case SDL_KEYDOWN:
					if (event.key.keysym.sym == SDL_Keycode.SDLK_ESCAPE)
						exit();
					break;
				case SDL_KEYUP:
					
					break;
				case SDL_TEXTEDITING:
					
					break;
				case SDL_TEXTINPUT:
					
					break;
				case SDL_MOUSEMOTION:
					
					break;
				case SDL_MOUSEBUTTONDOWN:
					
					break;
				case SDL_MOUSEBUTTONUP:
					
					break;
				case SDL_MOUSEWHEEL:
					
					break;
				case SDL_DROPBEGIN:
					
					break;
				case SDL_DROPTEXT:
					
					break;
				case SDL_DROPFILE:
					
					break;
				case SDL_DROPCOMPLETE:
					
					break;
				case SDL_KEYMAPCHANGED:
					keymapChanged.fire();
					break;
				case SDL_CLIPBOARDUPDATE:
					clipboardUpdate.fire();
					break;
				default:
					//debug writeln("Undispatched event: ", event.type);
					break;
			}
		}
	}
	
	void render()
	{
		vulkan.drawFrame();
	}
	
	void onResize()
	{
		int width = 0, height = 0;
		SDL_Vulkan_GetDrawableSize(window, &width, &height);
		vulkan.recreateSwapchain(width, height);
	}
	
	~this()
	{
		import core.memory;
		if (!GC.inFinalizer)
			destroy(vulkan);
		
		if (window)
		{
			SDL_DestroyWindow(window);
			debug writeln("Destroyed SDL window.");
		}
	}
}
