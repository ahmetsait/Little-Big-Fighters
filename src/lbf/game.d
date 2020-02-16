module lbf.game;

import std.stdio;
import std.format : format;
import std.string : fromStringz, toStringz;
import std.math;

import std.datetime.stopwatch;
import core.thread;

import bindbc.sdl.bind.sdl;
import bindbc.sdl.bind.sdlvideo;
import bindbc.sdl.bind.sdlevents;
import bindbc.sdl.bind.sdlkeyboard;
import bindbc.sdl.bind.sdlkeycode;
import bindbc.sdl.bind.sdltimer;
import bindbc.sdl.bind.sdlhints;

import bindbc.freeimage.types;
import bindbc.freeimage.binddynamic;

import app;
import lbf.core;
import lbf.math;
import lbf.util;
import lbf.events;
import lbf.graphics.opengl.gl.all;
import lbf.graphics.opengl;
import lbf.gamedata;
import lbf.gameobject;
import lbf.match;

import gfm.math.vector;

public final class Game
{
private:
	SDL_Window* window;
	int width = 1280, height = 720;
	bool fullScreen = false;
	
	immutable uint updatePerSecond = 60;
	immutable delayPerSecond = dur!"msecs"(1000) / updatePerSecond;
	
	int updateCounter = 0;
	int renderCounter = 0;
	
	bool _running = false;
	public bool running() @property
	{
		return _running;
	}
	
	public this()
	{
		// Initialize SDL
		debug write("Initializing SDL... ");
		SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS | SDL_INIT_TIMER)
			.enforceSDLNotNegative("Cannot initialize SDL.");
		debug writeln("Done.");
		
		// Use OpenGL 3.3 core
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3).enforceSDLEquals(0);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3).enforceSDLEquals(0);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE).enforceSDLEquals(0);
		
		// Enable debug context
		debug
			auto ctxflags = SDL_GL_CONTEXT_DEBUG_FLAG | SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG;
		else
			auto ctxflags = SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG;
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, ctxflags).enforceSDLEquals(0);
		
		// Request some actual bit depth
		SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8).enforceSDLEquals(0);
		SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8).enforceSDLEquals(0);
		SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8).enforceSDLEquals(0);
		SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE, 8).enforceSDLEquals(0);
		SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 0).enforceSDLEquals(0);
		SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 0).enforceSDLEquals(0);
		
		SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1).enforceSDLEquals(0);
		
		// Enable multisampling maybe
		SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 0);
		SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 0);
		
		// Disable drag-drop
		SDL_EventState(SDL_DROPTEXT, SDL_DISABLE);
		SDL_EventState(SDL_DROPFILE, SDL_DISABLE);
		SDL_EventState(SDL_DROPBEGIN, SDL_DISABLE);
		SDL_EventState(SDL_DROPCOMPLETE, SDL_DISABLE);
		
		// Disable text input by default
		SDL_StopTextInput();
		
		window = SDL_CreateWindow(appName.ptr,
			SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, width, height,
			SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIDDEN)
			.enforceSDLNotNull("Cannot create SDL window.");
		debug writeln("Created SDL window.");
		
		getGLContext();
		
		tid = Thread.getThis().id;
		SDL_SetEventFilter(&eventWatcher, cast(void*)this);
		
		import std.file : read, readText;
		shader = new Shader(
			readText("data/shaders/shader.vert.glsl"),
			readText("data/shaders/shader.frag.glsl"));
		debug writeln("Compiled & created shaders.");
		
		// Create an empty VAO
		glGenVertexArrays(1, &vao);
		glBindVertexArray(vao);
		
	}
	
	~this()
	{
		import core.memory;
		
		SDL_DelEventWatch(&eventWatcher, cast(void*)this);
		
		if (window)
		{
			SDL_DestroyWindow(window);
			debug writeln("Destroyed SDL window.");
		}
	}
	
	Shader shader;
	uint vao;
	
	SDL_GLContext glContext;
	bool _glDebugEnabled = false;
	
	public SDL_GLContext getGLContext()
	{
		if (glContext != null)
		{
			return glContext;
		}
		else
		{
			glContext = SDL_GL_CreateContext(window)
				.enforceSDLNotNull("OpenGL context could not be created");
			
			debug write("Loading OpenGL... ");
			if (!loadGL())
				throw new GraphicsException("Failed to load OpenGL 3.3");
			debug writeln("Done");
			
			debug
			{
				// Diagnostics
				writeln("============================================================");
				writeln("Renderer: ", glGetString(GL_RENDERER).fromStringz());
				writeln("Vendor: ", glGetString(GL_VENDOR).fromStringz());
				writeln("OpenGL Version: ", glGetString(GL_VERSION).fromStringz());
				writeln("GLSL Version: ", glGetString(GL_SHADING_LANGUAGE_VERSION).fromStringz());
				writeln("------------------------------------------------------------");
				
				if (GL_KHR_debug)
					glDebugMessageCallbackKHR(&debugCallback, null);
				else if (GL_ARB_debug_output)
					glDebugMessageCallbackARB(&debugCallback, null);
				else if (GL_AMD_debug_output)
					glDebugMessageCallbackAMD(&debugCallbackAMD, null);
				
				auto err = glGetError();
				if (err != GL_NO_ERROR)
					writefln("0x%X", err);
				
				_glDebugEnabled = GL_KHR_debug || GL_ARB_debug_output || GL_AMD_debug_output;
				if (_glDebugEnabled)
				{
					glEnable(GL_DEBUG_OUTPUT);
					writeln("OpenGL debug output enabled.");
				}
			}
			
			glDisable(GL_MULTISAMPLE);
			glDisable(GL_STENCIL_TEST);
			glEnable(GL_SCISSOR_TEST);
			glDisable(GL_DEPTH_TEST);
			glDisable(GL_CULL_FACE);
			glEnable(GL_BLEND);
			glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
			
			// Disable vsync
			if (SDL_GL_SetSwapInterval(-1) != 0)
				if (SDL_GL_SetSwapInterval(1) != 0)
					debug writeln("Could not set swap interval (VSync).");
			
			return glContext;
		}
	}
	
	//region Debug Callback
	extern(System)
	{
		private static void debugCallback(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length,
			in GLchar* message, GLvoid* userParam)
		{
			string sourceStr;
			switch(source)
			{
				case GL_DEBUG_SOURCE_API:
					sourceStr = "API";
					break;
				case GL_DEBUG_SOURCE_APPLICATION:
					sourceStr = "Application";
					break;
				case GL_DEBUG_SOURCE_OTHER:
					sourceStr = "Other";
					break;
				case GL_DEBUG_SOURCE_SHADER_COMPILER:
					sourceStr = "ShaderCompiler";
					break;
				case GL_DEBUG_SOURCE_THIRD_PARTY:
					sourceStr = "ThirdParty";
					break;
				case GL_DEBUG_SOURCE_WINDOW_SYSTEM:
					sourceStr = "WindowSystem";
					break;
				default:
					sourceStr = "?";
					break;
			}
			string typeStr;
			switch(type)
			{
				case GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR:
					typeStr = "DeprecatedBehavior";
					break;
				case GL_DEBUG_TYPE_ERROR:
					typeStr = "Error";
					break;
				case GL_DEBUG_TYPE_MARKER:
					typeStr = "Marker";
					break;
				case GL_DEBUG_TYPE_OTHER:
					typeStr = "Other";
					break;
				case GL_DEBUG_TYPE_PERFORMANCE:
					typeStr = "Performance";
					break;
				case GL_DEBUG_TYPE_POP_GROUP:
					typeStr = "PopGroup";
					break;
				case GL_DEBUG_TYPE_PORTABILITY:
					typeStr = "Portability";
					break;
				case GL_DEBUG_TYPE_PUSH_GROUP:
					typeStr = "PushGroup";
					break;
				case GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR:
					typeStr = "UndefinedBehavior";
					break;
				default:
					typeStr = "?";
					break;
			}
			string severityStr;
			switch(severity)
			{
				case GL_DEBUG_SEVERITY_HIGH:
					severityStr = "High";
					break;
				case GL_DEBUG_SEVERITY_LOW:
					severityStr = "Low";
					break;
				case GL_DEBUG_SEVERITY_MEDIUM:
					severityStr = "Medium";
					break;
				case GL_DEBUG_SEVERITY_NOTIFICATION:
					severityStr = "Notification";
					break;
				default:
					severityStr = "?";
					break;
			}
			stderr.writefln("[%s - Source:%s, Type:%s, Severity:%s] %s\n%s", 
				id, sourceStr, typeStr, severityStr, message.fromStringz(), getStackTrace());
			stderr.flush();
		}
		
		private static void debugCallbackAMD(GLuint id, GLenum category, GLenum severity, GLsizei length, in GLchar* message,
			GLvoid* userParam)
		{
			string categoryStr;
			switch(category)
			{
				case GL_DEBUG_CATEGORY_API_ERROR_AMD:
					categoryStr = "API";
					break;
				case GL_DEBUG_CATEGORY_APPLICATION_AMD:
					categoryStr = "Application";
					break;
				case GL_DEBUG_CATEGORY_DEPRECATION_AMD:
					categoryStr = "Deprecation";
					break;
				case GL_DEBUG_CATEGORY_OTHER_AMD:
					categoryStr = "Other";
					break;
				case GL_DEBUG_CATEGORY_PERFORMANCE_AMD:
					categoryStr = "Performance";
					break;
				case GL_DEBUG_CATEGORY_SHADER_COMPILER_AMD:
					categoryStr = "ShaderCompiler";
					break;
				case GL_DEBUG_CATEGORY_UNDEFINED_BEHAVIOR_AMD:
					categoryStr = "UndefinedBehavior";
					break;
				case GL_DEBUG_CATEGORY_WINDOW_SYSTEM_AMD:
					categoryStr = "WindowSystem";
					break;
				default:
					categoryStr = "?";
					break;
			}
			string severityStr;
			switch(severity)
			{
				case GL_DEBUG_SEVERITY_HIGH_AMD:
					severityStr = "High";
					break;
				case GL_DEBUG_SEVERITY_LOW_AMD:
					severityStr = "Low";
					break;
				case GL_DEBUG_SEVERITY_MEDIUM_AMD:
					severityStr = "Medium";
					break;
				default:
					severityStr = "?";
					break;
			}
			stderr.writefln("[%s - Category:%s, Severity:%s] %s\n%s",
				id, categoryStr, severityStr, message.fromStringz(), getStackTrace());
			stderr.flush();
		}
	}
	//endregion
	
	public void run()
	{
		_running = true;
		SDL_ShowWindow(window);
		
		StopWatch sw = StopWatch(AutoStart.yes);
		uint lastTick = SDL_GetTicks();
		while(_running)
		{
			sw.reset;
			update();
			render();
			uint newTick = SDL_GetTicks();
			uint tickDiff_ = (newTick - lastTick);
			if (tickDiff_ >= 1000)
			{
				debug writef("FPS: %3d\r", renderCounter);
				lastTick = newTick;
				renderCounter = 0;
			}
			auto tickDiff = sw.peek();
			if (tickDiff < delayPerSecond)
			{
				immutable timeLeft = delayPerSecond - tickDiff;
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
	
	void render(bool exposed = false)
	{
		if (updateCounter <= 0 && !exposed)
			return;
		
		glClearColor(0.0, 0.0, 0.0, 1);
		glClear(GL_COLOR_BUFFER_BIT);
		
		void drawObject(Object obj)
		{
			shader.use();
			
			if (is(obj == Char))
			{
				Char chr = cast(Char)obj;
				foreach (display; chr.currentFrame.pics)
				{
					Dimension dim = chr.data.dimensions[display.index];
					SizeI size = chr.data.sizes[display.index];
					Texture tex = chr.data.textures[display.index];
					tex.bind();
					float l = display.col * dim.width / float(size.width);
					float b = display.row * dim.height / float(size.height);
					float r = ((display.col + 1) * dim.width - 1) / float(size.width);
					float t = ((display.row + 1) * dim.height - 1) / float(size.height);
					vec2i position = cast(vec2i)(chr.position.xy + vec2f(0, chr.position.z));
					shader.setUniform("vertices", [
							vec2i(0, 0),
							vec2i(0, size.height),
							vec2i(size.width, size.height),
							vec2i(size.width, 0),
						]);
					shader.setUniform("texCoords", [
							vec2f(l, b),
							vec2f(l, t),
							vec2f(r, t),
							vec2f(r, b),
						]);
					shader.setUniform("view", vec2i(width, height));
					shader.setUniform("focus", vec2i(0, 0));
					shader.setUniform("position", position);
					shader.setUniform("offset", display.offset);
					shader.setUniform("facing", chr.facing);
					shader.setUniform("rotation", display.rotation);
					shader.setUniform("tex", 0);
					shader.setUniform("color", display.color);
					shader.setUniform("texInfluence", 1f);
					glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
				}
			}
		}
		
		
		
		SDL_GL_SwapWindow(window);
		updateCounter = 0;
		renderCounter++;
	}
	
	void update()
	{
		SDL_Event event;
		while(SDL_PollEvent(&event))
		{
			if (event.type == SDL_EventType.SDL_QUIT)
				_running = false;
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
							onSizeChanged();
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
						default:
							//debug writeln("Unhandled window event: ", event.window.event);
							break;
					}
					break;
				case SDL_KEYDOWN:
					if (event.key.keysym.sym == SDL_Keycode.SDLK_ESCAPE)
						exit();
					else if (event.key.keysym.sym == SDL_Keycode.SDLK_F11)
					{
						if ((fullScreen = !fullScreen) == false)
							SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN_DESKTOP);
						else
							SDL_SetWindowFullscreen(window, 0);
					}
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
				default:
					//debug writeln("Undispatched event: ", event.type);
					break;
			}
		}
		updateCounter++;
	}
	
	immutable int tid;
	
	extern(C) private static int eventWatcher(void* data, SDL_Event* event) nothrow
	{
		try
		{
			Game _this = cast(Game)data;
			if (Thread.getThis().id != _this.tid)
				return 1;
			if (event.type == SDL_WINDOWEVENT)
			{
				switch(event.window.event)
				{
					case SDL_WINDOWEVENT_EXPOSED:
						_this.render(true);
						return 0;
					case SDL_WINDOWEVENT_SIZE_CHANGED:
						_this.width = event.window.data1;
						_this.height = event.window.data2;
						_this.onSizeChanged();
						return 0;
					case SDL_WINDOWEVENT_MOVED:
						
						return 0;
					default:
						return 1;
				}
			}
		}
		catch(Throwable) { }
		return 1;
	}
	
	void onSizeChanged()
	{
		SDL_GL_GetDrawableSize(window, &width, &height);
		glScissor(0, 0, width, height);
		glViewport(0, 0, width, height);
	}
}
