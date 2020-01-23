module lbf.graphics;

debug import std.stdio;
import std.file;
import std.format : format;
import std.string : fromStringz, toStringz;
import std.algorithm.comparison : min, max, clamp;
import std.algorithm.searching : canFind;

import bindbc.sdl.bind.sdl;
import bindbc.sdl.bind.sdlvideo;
import bindbc.sdl.bind.sdlvulkan;

import containers.hashset;

import erupted;

import lbf.core;

public final class Vulkan
{
	private
	{
		VkInstance instance;
		VkExtensionProperties[] instanceExtensions;
		VkLayerProperties[] instanceLayers;
		const(char)*[] enabledInstanceExtensions;
		const(char)*[] enabledInstanceLayers;
		
		SDL_Window* window;
		VkSurfaceKHR surface;
		VkSurfaceFormatKHR* surfaceFormat;
		VkPresentModeKHR* presentMode;

		VkPhysicalDevice[] physicalDevices;
		VkExtensionProperties[][] deviceExtensionTable;
		VkLayerProperties[][] deviceLayerTable;
		VkPhysicalDeviceProperties[] physicalDevicePropertiesList;
		VkPhysicalDeviceFeatures[] physicalDeviceFeaturesList;
		VkQueueFamilyProperties[][] queueFamilyTable;
		VkBool32[][] queueFamilySurfaceSupportTable;
		VkSurfaceCapabilitiesKHR[] surfaceCapabilitiesList;
		VkSurfaceFormatKHR[][] surfaceFormatTable;
		VkPresentModeKHR[][] presentModeTable;

		size_t physicalDeviceIndex = -1;
		VkPhysicalDevice selectedDevice;

		VkDevice device;
		const(char)*[] enabledDeviceExtensions;
		const(char)*[] enabledDeviceLayers;

		uint queueFamilyIndex = -1;
		VkQueue queue;

		VkSwapchainKHR swapchain;
		VkImage[] swapchainImages;
		VkFormat swapchainImageFormat;
		VkExtent2D swapchainExtent;
		VkImageView[] swapchainImageViews;
		VkFramebuffer[] swapchainFramebuffers;
		
		VkShaderModule vert, frag;
		VkPipelineShaderStageCreateInfo[] shaderStages;
		VkViewport viewport;
		VkRect2D scissor;
		VkPipelineLayout pipelineLayout;
		VkRenderPass renderPass;
		VkPipeline graphicsPipeline;
		VkCommandPool commandPool;
		VkCommandBuffer[] commandBuffers;
		
		const maxConcurrentFrames = 2;
		VkSemaphore[] imageAvailableSemaphores;
		VkSemaphore[] renderFinishedSemaphores;
		VkFence[] inFlightFences;
		VkFence[] imagesInFlight;
		size_t currentFrame = 0;
	}

	public this(string appName = null, uint appVersion = 0, SDL_Window* window = null)
	{
		debug writeln("Initializing Vulkan...");
		
		this.window = window;
		
		//region Instance diagnostics
		instanceExtensions = getInstanceExtensions();
		debug writeln("Instance Extensions:");
		debug foreach (k, ref ext; instanceExtensions)
			writefln("    %3d: %s v%d.%d.%d", k, ext.extensionName.ptr.fromStringz,
				VK_VERSION_MAJOR(ext.specVersion),
				VK_VERSION_MINOR(ext.specVersion),
				VK_VERSION_PATCH(ext.specVersion));

		instanceLayers = getInstanceLayers();
		debug writeln("Instance Layers:");
		debug foreach (k, ref layer; instanceLayers)
			writefln("    %3d: %s v%d.%d.%d\n        %s", k, layer.layerName.ptr.fromStringz,
				VK_VERSION_MAJOR(layer.implementationVersion),
				VK_VERSION_MINOR(layer.implementationVersion),
				VK_VERSION_PATCH(layer.implementationVersion),
				layer.description.ptr.fromStringz);
		//endregion
		
		createInstance(appName, appVersion);
		
		loadInstanceLevelFunctions(instance);
		
		createSurface();
		
		//region Query physical device properties
		queryPhysicalDeviceProperties();
		debug printPhysicalDeviceDiagnostics();
		//endregion
		
		//region Select a suitable device
		uint[] suitableQueueIndices;
		foreach (i; 0 .. physicalDevices.length)
		{
			if (isDeviceSuitable(i, suitableQueueIndices))
			{
				selectedDevice = physicalDevices[physicalDeviceIndex = i];
				break;
			}
		}

		if (physicalDeviceIndex == -1)
			throw new VulkanException("No suitable device found.");

		debug writefln("Using device: [ID:%d] %s", physicalDevicePropertiesList[physicalDeviceIndex].deviceID,
			physicalDevicePropertiesList[physicalDeviceIndex].deviceName.ptr.fromStringz);

		queueFamilyIndex = suitableQueueIndices[0];

		if (queueFamilyIndex == -1)
			throw new VulkanException("No suitable device queues found.");

		debug writefln("Using graphics queue family: %d", queueFamilyIndex);
		//endregion
		
		//region Logical device & queue creation
		createDevice();
		loadDeviceLevelFunctions(device);
		
		vkGetDeviceQueue(device, queueFamilyIndex, 0, &queue);
		//endregion
		
		if (surface)
		{
			createSwapchain();
			
			createSwapchainImageViews();
		}
		
		createShaderModules();
		
		createPipelineLayout();
		
		createRenderPass();
		
		createGraphicsPipeline();
		
		createSwapchainFramebuffers();
		
		createCommandPool();
		
		allocateCommandBuffers();
		
		initCommandBuffers();
		
		createSyncObjects();
		
		debug writeln("Done initializing Vulkan.");
	}
	
	private void queryPhysicalDeviceProperties()
	{
		physicalDevices = getPhysicalDevices(instance);
		deviceExtensionTable = new VkExtensionProperties[][](physicalDevices.length);
		deviceLayerTable = new VkLayerProperties[][](physicalDevices.length);
		physicalDevicePropertiesList = new VkPhysicalDeviceProperties[physicalDevices.length];
		physicalDeviceFeaturesList = new VkPhysicalDeviceFeatures[physicalDevices.length];
		queueFamilyTable = new VkQueueFamilyProperties[][](physicalDevices.length);
		queueFamilySurfaceSupportTable = new VkBool32[][](physicalDevices.length);
		if (surface)
		{
			surfaceCapabilitiesList = new VkSurfaceCapabilitiesKHR[physicalDevices.length];
			surfaceFormatTable = new VkSurfaceFormatKHR[][](physicalDevices.length);
			presentModeTable = new VkPresentModeKHR[][](physicalDevices.length);
		}
		
		foreach (i, ref dev; physicalDevices)
		{
			deviceExtensionTable[i] = getDeviceExtensions(dev);
			deviceLayerTable[i] = getDeviceLayers(dev);
			
			vkGetPhysicalDeviceProperties(dev, &physicalDevicePropertiesList[i]);
			vkGetPhysicalDeviceFeatures(dev, &physicalDeviceFeaturesList[i]);
			
			queueFamilyTable[i] = getDeviceQueueFamilies(dev);
			
			if (surface && deviceExtensionTable[i].canFind!(ext => ext.extensionName.ptr.fromStringz == VK_KHR_SWAPCHAIN_EXTENSION_NAME))
			{
				queueFamilySurfaceSupportTable[i] = new VkBool32[queueFamilyTable[i].length];
				foreach (j, const ref queueFamily; queueFamilyTable[i])
					vkGetPhysicalDeviceSurfaceSupportKHR(dev, cast(uint)j, surface, &queueFamilySurfaceSupportTable[i][j])
						.enforceVK();
				
				vkGetPhysicalDeviceSurfaceCapabilitiesKHR(dev, surface, &surfaceCapabilitiesList[i]).enforceVK();
				surfaceFormatTable[i] = getSurfaceFormats(dev, surface);
				presentModeTable[i] = getPresentModes(dev, surface);
			}
		}
	}
	
	//region Vulkan init
	private void createSyncObjects()
	{
		imageAvailableSemaphores = new VkSemaphore[maxConcurrentFrames];
		renderFinishedSemaphores = new VkSemaphore[maxConcurrentFrames];
		inFlightFences = new VkFence[maxConcurrentFrames];
		imagesInFlight = new VkFence[swapchainImages.length];
		
		VkSemaphoreCreateInfo semaphoreInfo = {};
		
		VkFenceCreateInfo fenceInfo = {};
		fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;
		
		for (size_t i = 0; i < maxConcurrentFrames; i++) 
		{
			vkCreateSemaphore(device, &semaphoreInfo, null, &imageAvailableSemaphores[i]).enforceVK();
			vkCreateSemaphore(device, &semaphoreInfo, null, &renderFinishedSemaphores[i]).enforceVK();
			vkCreateFence(device, &fenceInfo, null, &inFlightFences[i]).enforceVK();
		}
		debug writeln("Created sync objects.");
	}
	
	private void initCommandBuffers()
	{
		foreach (i, commandBuffer; commandBuffers)
		{
			VkCommandBufferBeginInfo beginInfo = {};
			beginInfo.flags = 0; // Optional
			beginInfo.pInheritanceInfo = null; // Optional
			
			vkBeginCommandBuffer(commandBuffer, &beginInfo).enforceVK();
			
			vkCmdSetViewport(commandBuffer, 0, 1, &viewport);
			vkCmdSetScissor(commandBuffer, 0, 1, &scissor);
			
			VkRenderPassBeginInfo renderPassBeginInfo = {};
			renderPassBeginInfo.renderPass = renderPass;
			renderPassBeginInfo.framebuffer = swapchainFramebuffers[i];
			renderPassBeginInfo.renderArea.offset = VkOffset2D(0, 0);
			renderPassBeginInfo.renderArea.extent = swapchainExtent;
			
			VkClearValue clearColor = {};
			clearColor.color.float32 = [0.0f, 0.0f, 0.0f, 1.0f];
			renderPassBeginInfo.clearValueCount = 1;
			renderPassBeginInfo.pClearValues = &clearColor;
			
			vkCmdBeginRenderPass(commandBuffer, &renderPassBeginInfo, VK_SUBPASS_CONTENTS_INLINE);
			
			vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);
			
			vkCmdDraw(commandBuffer, 3, 1, 0, 0);
			
			vkCmdEndRenderPass(commandBuffer);
			
			vkEndCommandBuffer(commandBuffer).enforceVK();
		}
		debug writeln("Initialized command buffers.");
	}
	
	private void allocateCommandBuffers()
	{
		commandBuffers = new VkCommandBuffer[swapchainFramebuffers.length];
		VkCommandBufferAllocateInfo allocInfo = {};
		allocInfo.commandPool = commandPool;
		allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
		allocInfo.commandBufferCount = cast(uint)commandBuffers.length;
		
		vkAllocateCommandBuffers(device, &allocInfo, commandBuffers.ptr).enforceVK();
		debug writeln("Allocated command buffers.");
	}
	
	private void createCommandPool()
	{
		VkCommandPoolCreateInfo poolInfo = {};
		poolInfo.queueFamilyIndex = queueFamilyIndex;
		//poolInfo.flags = VK_COMMAND_POOL_CREATE_TRANSIENT_BIT;
		
		vkCreateCommandPool(device, &poolInfo, null, &commandPool).enforceVK();
		debug writeln("Created command pool.");
	}
	
	private void createSwapchainFramebuffers()
	{
		swapchainFramebuffers = new VkFramebuffer[swapchainImageViews.length];
		foreach (i; 0 .. swapchainImageViews.length)
		{
			VkFramebufferCreateInfo framebufferInfo = {};
			framebufferInfo.renderPass = renderPass;
			framebufferInfo.attachmentCount = 1;
			framebufferInfo.pAttachments = &swapchainImageViews[i];
			framebufferInfo.width = swapchainExtent.width;
			framebufferInfo.height = swapchainExtent.height;
			framebufferInfo.layers = 1;
			
			vkCreateFramebuffer(device, &framebufferInfo, null, &swapchainFramebuffers[i]).enforceVK();
		}
		debug writeln("Created framebuffers.");
	}
	
	private void createGraphicsPipeline()
	{
		VkPipelineVertexInputStateCreateInfo vertexInputInfo = {
			vertexBindingDescriptionCount	: 0,
			pVertexBindingDescriptions		: null,
			vertexAttributeDescriptionCount	: 0,
			pVertexAttributeDescriptions	: null,
		};
		VkPipelineInputAssemblyStateCreateInfo inputAssemblyStateInfo = {
			topology				: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
			primitiveRestartEnable	: VK_FALSE,
		};
		
		viewport.x = 0f;
		viewport.y = 0f;
		viewport.width = swapchainExtent.width;
		viewport.height = swapchainExtent.height;
		viewport.minDepth = 0.0f;
		viewport.maxDepth = 1.0f;
		
		scissor.offset = VkOffset2D(0, 0);
		scissor.extent = swapchainExtent;
		
		VkPipelineViewportStateCreateInfo viewportStateInfo = {
			viewportCount	: 1,
			pViewports		: null, // Dynamic
			scissorCount	: 1,
			pScissors		: null, // Dynamic
		};
		VkPipelineRasterizationStateCreateInfo rasterizerInfo = {
			depthClampEnable		: VK_FALSE,
			rasterizerDiscardEnable	: VK_FALSE,
			polygonMode				: VK_POLYGON_MODE_FILL,
			lineWidth				: 1f,
			cullMode				: VK_CULL_MODE_BACK_BIT,
			frontFace				: VK_FRONT_FACE_CLOCKWISE,
			depthBiasEnable			: VK_FALSE,
			depthBiasClamp			: 0.0f,
			depthBiasConstantFactor	: 0.0f,
			depthBiasSlopeFactor	: 0.0f,
		};
		VkPipelineMultisampleStateCreateInfo multisampleInfo = {
			sampleShadingEnable		: VK_FALSE,
			rasterizationSamples	: VK_SAMPLE_COUNT_1_BIT,
			minSampleShading		: 1.0f,		// Optional
			pSampleMask				: null,		// Optional
			alphaToCoverageEnable	: VK_FALSE,	// Optional
			alphaToOneEnable		: VK_FALSE,	// Optional
		};
		VkPipelineDepthStencilStateCreateInfo depthStencilInfo = {};
		
		VkPipelineColorBlendAttachmentState colorBlendAttachment = {};
		colorBlendAttachment.colorWriteMask = VK_COLOR_COMPONENT_R_BIT
			| VK_COLOR_COMPONENT_G_BIT
			| VK_COLOR_COMPONENT_B_BIT
			| VK_COLOR_COMPONENT_A_BIT;
		colorBlendAttachment.blendEnable = VK_TRUE;
		colorBlendAttachment.srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA;
		colorBlendAttachment.dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
		colorBlendAttachment.colorBlendOp = VK_BLEND_OP_ADD;
		colorBlendAttachment.srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE;
		colorBlendAttachment.dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO;
		colorBlendAttachment.alphaBlendOp = VK_BLEND_OP_ADD;
		
		VkPipelineColorBlendStateCreateInfo colorBlendState = {};
		colorBlendState.logicOpEnable = VK_FALSE;
		colorBlendState.logicOp = VK_LOGIC_OP_COPY; // Optional
		colorBlendState.attachmentCount = 1;
		colorBlendState.pAttachments = &colorBlendAttachment;
		colorBlendState.blendConstants[] = 0.0f; // Optional
		
		VkDynamicState[] dynamicStates = [
			VK_DYNAMIC_STATE_VIEWPORT,
			VK_DYNAMIC_STATE_SCISSOR,
		];
		VkPipelineDynamicStateCreateInfo dynamicState = {};
		dynamicState.dynamicStateCount = cast(uint)dynamicStates.length;
		dynamicState.pDynamicStates = dynamicStates.ptr;
		
		VkGraphicsPipelineCreateInfo pipelineInfo = {};
		pipelineInfo.stageCount = cast(uint)shaderStages.length;
		pipelineInfo.pStages = shaderStages.ptr;
		pipelineInfo.pVertexInputState = &vertexInputInfo;
		pipelineInfo.pInputAssemblyState = &inputAssemblyStateInfo;
		pipelineInfo.pViewportState = &viewportStateInfo;
		pipelineInfo.pRasterizationState = &rasterizerInfo;
		pipelineInfo.pMultisampleState = &multisampleInfo;
		pipelineInfo.pDepthStencilState = null; // Optional
		pipelineInfo.pColorBlendState = &colorBlendState;
		pipelineInfo.pDynamicState = &dynamicState; // Optional
		pipelineInfo.layout = pipelineLayout;
		pipelineInfo.renderPass = renderPass;
		pipelineInfo.subpass = 0;
		pipelineInfo.basePipelineHandle = VK_NULL_HANDLE; // Optional
		pipelineInfo.basePipelineIndex = -1; // Optional
		
		vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &pipelineInfo, null, &graphicsPipeline).enforceVK();
		debug writeln("Created graphics pipeline.");
	}
	
	private void createRenderPass()
	{
		VkAttachmentDescription colorAttachment = {};
		colorAttachment.format = swapchainImageFormat;
		colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT;
		colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
		colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
		colorAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
		colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
		colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
		colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
		
		VkAttachmentReference attachmentRef = {};
		attachmentRef.attachment = 0;
		attachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
		
		VkSubpassDescription subpass = {};
		subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
		subpass.colorAttachmentCount = 1;
		subpass.pColorAttachments = &attachmentRef;
		
		VkRenderPassCreateInfo renderPassInfo = {};
		renderPassInfo.attachmentCount = 1;
		renderPassInfo.pAttachments = &colorAttachment;
		renderPassInfo.subpassCount = 1;
		renderPassInfo.pSubpasses = &subpass;
		
		vkCreateRenderPass(device, &renderPassInfo, null, &renderPass).enforceVK();
		debug writeln("Created render pass.");
	}
	
	private void createPipelineLayout()
	{
		VkPipelineLayoutCreateInfo pipelineLayoutInfo = {};
		pipelineLayoutInfo.setLayoutCount = 0; // Optional
		pipelineLayoutInfo.pSetLayouts = null; // Optional
		pipelineLayoutInfo.pushConstantRangeCount = 0; // Optional
		pipelineLayoutInfo.pPushConstantRanges = null; // Optional
		
		vkCreatePipelineLayout(device, &pipelineLayoutInfo, null, &pipelineLayout).enforceVK();
		debug writeln("Created pipeline layout.");
	}
	
	private void createShaderModules()
	{
		vert = compileShader(device, "shader.vert.glsl", "vert");
		frag = compileShader(device, "shader.frag.glsl", "frag");
		
		VkPipelineShaderStageCreateInfo vertShaderInfo = {
			stage	: VK_SHADER_STAGE_VERTEX_BIT,
			_module	: vert,
			pName	: "main",
		};
		VkPipelineShaderStageCreateInfo fragShaderInfo = {
			stage	: VK_SHADER_STAGE_FRAGMENT_BIT,
			_module	: frag,
			pName	: "main",
		};
		shaderStages = [
			vertShaderInfo,
			fragShaderInfo,
		];
		
		debug writeln("Created shader modules.");
	}
	
	private void createSwapchainImageViews()
	{
		swapchainImages = getSwapChainImages(device, swapchain);
		swapchainImageFormat = surfaceFormat.format;
		
		swapchainImageViews = createSwapchainImageViews(device, swapchainImages, swapchainImageFormat);
		debug writeln("Created swapchain image views.");
	}
	
	private void createSwapchain()
	{
		// Select surface format
		VkSurfaceFormatKHR[] suitableSurfaceFormats = [
			VkSurfaceFormatKHR(VK_FORMAT_B8G8R8A8_UNORM, VK_COLOR_SPACE_SRGB_NONLINEAR_KHR),
		];
		foreach (ref ssf; suitableSurfaceFormats)
		{
			if (surfaceFormatTable[physicalDeviceIndex].canFind!(sf => sf == ssf))
			{
				surfaceFormat = &ssf;
				break;
			}
		}
		if (surfaceFormat == VK_NULL_HANDLE)
			throw new VulkanException("No suitable surface format found.");
		
		// Select present mode
		VkPresentModeKHR[] suitablePresentModes = [
			VkPresentModeKHR(VK_PRESENT_MODE_MAILBOX_KHR),
			VkPresentModeKHR(VK_PRESENT_MODE_FIFO_RELAXED_KHR),
			VkPresentModeKHR(VK_PRESENT_MODE_FIFO_KHR),
			VkPresentModeKHR(VK_PRESENT_MODE_IMMEDIATE_KHR),
		];
		foreach (ref spm; suitablePresentModes)
		{
			if (presentModeTable[physicalDeviceIndex].canFind!(pm => pm == spm))
			{
				presentMode = &spm;
				break;
			}
		}
		if (presentMode == VK_NULL_HANDLE)
			throw new VulkanException("No suitable present mode found.");
		
		// Select swapchain extent
		int w, h;
		SDL_Vulkan_GetDrawableSize(window, &w, &h);
		//swapchainExtent = chooseSwapExtent(surfaceCapabilitiesList[physicalDeviceIndex], w, h);
		swapchainExtent.width = w;
		swapchainExtent.height = h;
		viewport.width = swapchainExtent.width;
		viewport.height = swapchainExtent.height;
		scissor.extent = swapchainExtent;
		
		uint imageCount = min(surfaceCapabilitiesList[physicalDeviceIndex].minImageCount + 1,
			surfaceCapabilitiesList[physicalDeviceIndex].maxImageCount);
		
		VkSwapchainCreateInfoKHR swapchainInfo = {
			surface					: surface,
			minImageCount			: imageCount,
			imageFormat				: surfaceFormat.format,
			imageColorSpace			: surfaceFormat.colorSpace,
			imageExtent				: swapchainExtent,
			imageArrayLayers		: 1,
			imageUsage				: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
			imageSharingMode		: VK_SHARING_MODE_EXCLUSIVE,
			queueFamilyIndexCount	: 0,
			pQueueFamilyIndices		: null,
			preTransform			: surfaceCapabilitiesList[physicalDeviceIndex].currentTransform,
			compositeAlpha			: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
			presentMode				: *presentMode,
			clipped					: VK_TRUE,
		};
		
		vkCreateSwapchainKHR(device, &swapchainInfo, null, &swapchain).enforceVK();
		debug writeln("Created swapchain.");
	}
	
	private void createDevice()
	{
		float[1] queuePriorities = [ 0.0f ];
		VkDeviceQueueCreateInfo queueInfo = {
		queueCount		: cast(uint)queuePriorities.length,
				pQueuePriorities: queuePriorities.ptr,
				queueFamilyIndex: cast(uint)queueFamilyIndex,
		};
		
		enabledDeviceExtensions = [
			// Required extensions
		];
		if (surface)
			enabledDeviceExtensions ~= VK_KHR_SWAPCHAIN_EXTENSION_NAME;
		
		VkDeviceCreateInfo deviceInfo = {
		queueCreateInfoCount	: 1,
				pQueueCreateInfos		: &queueInfo,
				enabledExtensionCount	: cast(uint)enabledDeviceExtensions.length,
				ppEnabledExtensionNames	: enabledDeviceExtensions.ptr,
		};
		vkCreateDevice(selectedDevice, &deviceInfo, null, &device).enforceVK();
		debug writeln("Created Vulkan device.");
	}
	
	private void createSurface()
	{
		if (window)
			SDL_Vulkan_CreateSurface(window, instance, &surface)
				.enforceSDLTrue("Failed to create Vulkan surface.");
		debug writeln("Created Vulkan surface.");
	}
	
	private void createInstance(string appName, uint appVersion)
	{
		const(char)*[] sdlExt;
		if (window)
			sdlExt = getRequiredSDLExtensions(window);
		
		VkApplicationInfo appInfo = {
			apiVersion			: VK_API_VERSION_1_1,
			pApplicationName	: appName.ptr,
			applicationVersion	: appVersion,
		};
		
		enabledInstanceExtensions = [
			// Required extensions
		];
		debug enabledInstanceExtensions ~= [
			// Additional debug extensions
			VK_EXT_DEBUG_UTILS_EXTENSION_NAME,
		];
		enabledInstanceExtensions ~= sdlExt;
		
		enabledInstanceLayers = [
			// Enabled layers
		];
		debug enabledInstanceLayers ~= [
			// Additional debug layers
			//"VK_LAYER_KHRONOS_validation",
		];
		
		VkInstanceCreateInfo instanceInfo = {
			pApplicationInfo		: &appInfo,
			enabledExtensionCount	: cast(uint)enabledInstanceExtensions.length,
			ppEnabledExtensionNames	: enabledInstanceExtensions.ptr,
			enabledLayerCount		: cast(uint)enabledInstanceLayers.length,
			ppEnabledLayerNames		: enabledInstanceLayers.ptr,
		};
		
		vkCreateInstance(&instanceInfo, null, &instance).enforceVK();
		debug writeln("Created Vulkan instance.");
	}
	//endregion
	
	public void recreateSwapchain(int width, int height)
	{
		vkDeviceWaitIdle(device);
		
		freeCommandBuffers();
		destroySwapchainFramebuffers();
		//destroyGraphicsPipeline();
		//destroyRenderPass();
		destroySwapchainImageViews();
		destroySwapchain();
		
		createSwapchain();
		createSwapchainImageViews();
		//createRenderPass();
		//createGraphicsPipeline();
		createSwapchainFramebuffers();
		allocateCommandBuffers();
		initCommandBuffers();
	}
	
	public void drawFrame()
	{
		vkWaitForFences(device, 1, &inFlightFences[currentFrame], VK_TRUE, ulong.max);
		
		uint imageIndex;
		VkResult result = vkAcquireNextImageKHR(device, swapchain,
			ulong.max, imageAvailableSemaphores[currentFrame], VK_NULL_HANDLE, &imageIndex);
		
		if (result == VK_ERROR_OUT_OF_DATE_KHR)
		{
			int w, h;
			SDL_Vulkan_GetDrawableSize(window, &w, &h);
			recreateSwapchain(w, h);
			return;
		}
		else if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR)
			throw new VulkanException(format("Failed to acquire swap chain image: %s", result));
		
		if (imagesInFlight[imageIndex] != VK_NULL_HANDLE)
			vkWaitForFences(device, 1, &imagesInFlight[imageIndex], VK_TRUE, ulong.max);
			
		imagesInFlight[imageIndex] = inFlightFences[currentFrame];
		
		VkSubmitInfo submitInfo = {};
		
		VkSemaphore[] waitSemaphores = [imageAvailableSemaphores[currentFrame]];
		VkPipelineStageFlags[] waitStages = [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT];
		submitInfo.waitSemaphoreCount = 1;
		submitInfo.pWaitSemaphores = waitSemaphores.ptr;
		submitInfo.pWaitDstStageMask = waitStages.ptr;
		
		submitInfo.commandBufferCount = 1;
		submitInfo.pCommandBuffers = &commandBuffers[imageIndex];
		
		VkSemaphore[] signalSemaphores = [renderFinishedSemaphores[currentFrame]];
		submitInfo.signalSemaphoreCount = 1;
		submitInfo.pSignalSemaphores = signalSemaphores.ptr;
		
		vkResetFences(device, 1, &inFlightFences[currentFrame]);
		
		vkQueueSubmit(queue, 1, &submitInfo, inFlightFences[currentFrame]).enforceVK();
		
		VkPresentInfoKHR presentInfo = {};
		presentInfo.waitSemaphoreCount = 1;
		presentInfo.pWaitSemaphores = signalSemaphores.ptr;
		
		VkSwapchainKHR[] swapchains = [swapchain];
		presentInfo.swapchainCount = 1;
		presentInfo.pSwapchains = swapchains.ptr;
		
		presentInfo.pImageIndices = &imageIndex;
		
		vkQueuePresentKHR(queue, &presentInfo);
		
		currentFrame = (currentFrame + 1) % maxConcurrentFrames;
	}
	
	//region Destructor
	~this()
	{
		vkDeviceWaitIdle(device);
		destroySyncObjects();
		freeCommandBuffers();
		destroyCommandPool();
		destroySwapchainFramebuffers();
		destroyGraphicsPipeline();
		destroyRenderPass();
		destroyPipelineLayout();
		destroyShaderModules();
		destroySwapchainImageViews();
		destroySwapchain();
		destroyDevice();
		destroySurface();
		destroyInstance();
	}
	
	private void destroySyncObjects()
	{
		for (size_t i = 0; i < maxConcurrentFrames; i++)
		{
			if (renderFinishedSemaphores[i])
				vkDestroySemaphore(device, renderFinishedSemaphores[i], null);
			if (imageAvailableSemaphores[i])
				vkDestroySemaphore(device, imageAvailableSemaphores[i], null);
			if (inFlightFences[i])
				vkDestroyFence(device, inFlightFences[i], null);
			debug writeln("Destroyed sync objects.");
		}
	}
	
	private void freeCommandBuffers()
	{
		if (commandBuffers.length > 0)
		{
			vkFreeCommandBuffers(device, commandPool, cast(uint)commandBuffers.length, commandBuffers.ptr);
			debug writeln("Freed command buffers.");
		}
	}
	
	private void destroyCommandPool()
	{
		if (commandPool)
		{
			vkDestroyCommandPool(device, commandPool, null);
			debug writeln("Destroyed command pool.");
		}
	}
	
	private void destroySwapchainFramebuffers()
	{
		if (swapchainFramebuffers.length > 0)
		{
			foreach (framebuffer; swapchainFramebuffers)
				vkDestroyFramebuffer(device, framebuffer, null);
			debug writeln("Destroyed framebuffers.");
		}
	}
	
	private void destroyGraphicsPipeline()
	{
		if (graphicsPipeline)
		{
			vkDestroyPipeline(device, graphicsPipeline, null);
			debug writeln("Destroyed graphics pipeline.");
		}
	}
	
	private void destroyRenderPass()
	{
		if (renderPass)
		{
			vkDestroyRenderPass(device, renderPass, null);
			debug writeln("Destroyed render pass.");
		}
	}
	
	private void destroyPipelineLayout()
	{
		if (pipelineLayout)
		{
			vkDestroyPipelineLayout(device, pipelineLayout, null);
			debug writeln("Destroyed pipeline layout.");
		}
	}
	
	private void destroyShaderModules()
	{
		if (shaderStages.length > 0)
		{
			foreach_reverse (ref shader; shaderStages)
				vkDestroyShaderModule(device, shader._module, null);
			debug writeln("Destroyed shader modules.");
		}
	}
	
	private void destroySwapchainImageViews()
	{
		if (swapchainImageViews.length > 0)
		{
			destroySwapchainImageViews(device, swapchainImageViews);
			debug writeln("Destroyed swapchain image views.");
		}
	}
	
	private void destroySwapchain()
	{
		if (swapchain)
		{
			vkDestroySwapchainKHR(device, swapchain, null);
			debug writeln("Destroyed swapchain.");
		}
	}
	
	private void destroyDevice()
	{
		if (device)
		{
			vkDestroyDevice(device, null);
			debug writeln("Destroyed Vulkan device.");
		}
	}
	
	private void destroySurface()
	{
		if (surface)
		{
			vkDestroySurfaceKHR(instance, surface, null);
			debug writeln("Destroyed Vulkan surface.");
		}
	}
	
	private void destroyInstance()
	{
		if (instance)
		{
			vkDestroyInstance(instance, null);
			debug writeln("Destroyed Vulkan instance.");
		}
	}
	//endregion 
	
	//region Utilities
	private static VkExtent2D chooseSwapExtent(ref VkSurfaceCapabilitiesKHR capabilities, int width, int height)
	{
		if (capabilities.currentExtent.width != uint.max && capabilities.currentExtent.height != uint.max)
			return capabilities.currentExtent;
		else
		{
			VkExtent2D extent;
			extent.width = clamp(width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
			extent.height = clamp(height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);
			return extent;
		}
	}

	public static VkImageView[] createSwapchainImageViews(VkDevice device, VkImage[] swapchainImages, VkFormat format)
	{
		auto views = new VkImageView[swapchainImages.length];
		foreach (i, img; swapchainImages)
		{
			VkImageViewCreateInfo imageViewInfo = {
				image			: img,
				viewType		: VK_IMAGE_VIEW_TYPE_2D,
				format			: format,
				components		: VkComponentMapping(
					VK_COMPONENT_SWIZZLE_IDENTITY,
					VK_COMPONENT_SWIZZLE_IDENTITY,
					VK_COMPONENT_SWIZZLE_IDENTITY,
					VK_COMPONENT_SWIZZLE_IDENTITY),
				subresourceRange: VkImageSubresourceRange(
					VK_IMAGE_ASPECT_COLOR_BIT,
					0,
					1,
					0,
					1),
			};
			vkCreateImageView(device, &imageViewInfo, null, &views[i]).enforceVK();
		}
		return views;
	}
	
	public static void destroySwapchainImageViews(VkDevice device, VkImageView[] views)
	{
		foreach (view; views)
			vkDestroyImageView(device, view, null);
	}

	public static VkShaderModule compileShader(VkDevice device, string glslFile, string shaderStage)
	{
		import std.process;
		import std.file : read, exists;
		import std.path : setExtension;
		
		string spirvFile = setExtension(glslFile, ".spv");
		ubyte[] spirv;
		
		if (exists(spirvFile))
		{
			spirv = cast(ubyte[])read(spirvFile);
		}
		else
		{
			auto glslc = execute(["glslc", "-fshader-stage=" ~ shaderStage, glslFile, "-o", spirvFile], null,
				Config.suppressConsole);
			if (glslc.status == 0)
				spirv = cast(ubyte[])read(spirvFile);
			else
				throw new VulkanException("Failed to compile shader:\n" ~ glslc.output);
		}
		// Ensure uint32_t alignment
		assert(spirv.length % 4 == 0, "Shader bytecode misaligned.");
		//size_t len = spirv.length;
		//writefln("%s : %d", shaderFile, len);
		//spirv.length += uint.sizeof - spirv.length % uint.sizeof;
		//spirv[len .. $] = 0; // Zero padding area
		VkShaderModuleCreateInfo shaderInfo = {
			codeSize: spirv.length,
			pCode	: cast(uint*)spirv.ptr,
		};
		VkShaderModule shader;
		vkCreateShaderModule(device, &shaderInfo, null, &shader).enforceVK();
		return shader;
	}

	public static VkExtensionProperties[] getInstanceExtensions(const(char)[] filterLayer = null)
	{
		uint extensionCount;
		vkEnumerateInstanceExtensionProperties(filterLayer.ptr, &extensionCount, null).enforceVK();
		auto extensions = new VkExtensionProperties[extensionCount];
		vkEnumerateInstanceExtensionProperties(filterLayer.ptr, &extensionCount, extensions.ptr).enforceVK();
		return extensions;
	}

	public static VkLayerProperties[] getInstanceLayers()
	{
		uint layerCount;
		vkEnumerateInstanceLayerProperties(&layerCount, null).enforceVK();
		auto layers = new VkLayerProperties[layerCount];
		vkEnumerateInstanceLayerProperties(&layerCount, layers.ptr).enforceVK();
		return layers;
	}

	public static VkPhysicalDevice[] getPhysicalDevices(VkInstance instance)
	{
		uint deviceCount;
		vkEnumeratePhysicalDevices(instance, &deviceCount, null).enforceVK();
		auto physicalDevices = new VkPhysicalDevice[deviceCount];
		vkEnumeratePhysicalDevices(instance, &deviceCount, physicalDevices.ptr).enforceVK();
		return physicalDevices;
	}

	public static VkExtensionProperties[] getDeviceExtensions(VkPhysicalDevice physicalDevice,
		const(char)[] filterLayer = null)
	{
		uint extensionCount;
		vkEnumerateDeviceExtensionProperties(physicalDevice, filterLayer.ptr, &extensionCount, null).enforceVK();
		auto extensions = new VkExtensionProperties[extensionCount];
		vkEnumerateDeviceExtensionProperties(physicalDevice, filterLayer.ptr, &extensionCount, extensions.ptr)
			.enforceVK();
		return extensions;
	}

	public static VkLayerProperties[] getDeviceLayers(VkPhysicalDevice physicalDevice)
	{
		uint layerCount;
		vkEnumerateDeviceLayerProperties(physicalDevice, &layerCount, null).enforceVK();
		auto layers = new VkLayerProperties[layerCount];
		vkEnumerateDeviceLayerProperties(physicalDevice, &layerCount, layers.ptr).enforceVK();
		return layers;
	}

	public static VkQueueFamilyProperties[] getDeviceQueueFamilies(VkPhysicalDevice physicalDevice)
	{
		uint queueCount;
		vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueCount, null);
		auto queueFamilyProperties = new VkQueueFamilyProperties[queueCount];
		vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueCount, queueFamilyProperties.ptr);
		return queueFamilyProperties;
	}

	public static VkSurfaceFormatKHR[] getSurfaceFormats(VkPhysicalDevice physicalDevice, VkSurfaceKHR surface)
	{
		uint surfaceFormatCount;
		vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, &surfaceFormatCount, null).enforceVK();
		auto surfaceFormats = new VkSurfaceFormatKHR[surfaceFormatCount];
		vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, &surfaceFormatCount, surfaceFormats.ptr)
			.enforceVK();
		return surfaceFormats;
	}

	public static VkPresentModeKHR[] getPresentModes(VkPhysicalDevice physicalDevice, VkSurfaceKHR surface)
	{
		uint presentModeCount;
		vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, surface, &presentModeCount, null).enforceVK();
		auto presentModes = new VkPresentModeKHR[presentModeCount];
		vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, surface, &presentModeCount, presentModes.ptr)
			.enforceVK();
		return presentModes;
	}

	public static VkImage[] getSwapChainImages(VkDevice device, VkSwapchainKHR swapchain)
	{
		uint imageCount;
		vkGetSwapchainImagesKHR(device, swapchain, &imageCount, null);
		auto images = new VkImage[imageCount];
		vkGetSwapchainImagesKHR(device, swapchain, &imageCount, images.ptr);
		return images;
	}

	public static const(char)*[] getRequiredSDLExtensions(SDL_Window* window)
	{
		uint extensionCount;
		SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, null)
			.enforceSDLTrue("Failed to get required SDL extensions.");
		auto sdlExtensions = new const(char)*[extensionCount];
		SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, sdlExtensions.ptr)
			.enforceSDLTrue("Failed to get required SDL extensions.");
		return sdlExtensions;
	}

	public void printPhysicalDeviceDiagnostics()
	{
		import std.stdio;
		writeln("Vulkan Devices:");
		foreach (i; 0 .. physicalDevices.length)
		{
			writefln("    %2d: [ID:%d] %s", i, physicalDevicePropertiesList[i].deviceID,
				physicalDevicePropertiesList[i].deviceName.ptr.fromStringz);

			writeln("        Device extensions:");
			foreach (k, ref deviceExtension; deviceExtensionTable[i])
				writefln("            %3d: %s v%d.%d.%d", k, deviceExtension.extensionName.ptr.fromStringz,
					VK_VERSION_MAJOR(deviceExtension.specVersion),
					VK_VERSION_MINOR(deviceExtension.specVersion),
					VK_VERSION_PATCH(deviceExtension.specVersion));

			writeln("        Device layers:");
			foreach (k, ref deviceLayer; deviceLayerTable[i])
				writefln("            %3d: %s v%d.%d.%d\n                %s", k, deviceLayer.layerName.ptr.fromStringz,
					VK_VERSION_MAJOR(deviceLayer.implementationVersion),
					VK_VERSION_MINOR(deviceLayer.implementationVersion),
					VK_VERSION_PATCH(deviceLayer.implementationVersion),
					deviceLayer.description.ptr.fromStringz);

			writeln("        Device surface formats:");
			foreach (k, ref surfaceFormat; surfaceFormatTable[i])
				writefln("            %2d: %s %s", k, surfaceFormat.format, surfaceFormat.colorSpace);

			writeln("        Device present modes:");
			foreach (k, ref presentMode; presentModeTable[i])
				writefln("            %2d: %s", k, presentMode);

			foreach (j; 0 .. queueFamilyTable[i].length)
			{
				writeln("        Queue Family: ", j);
				writeln("            Queues in Family        : ", queueFamilyTable[i][j].queueCount);
				writeln("            Queue timestampValidBits: ", queueFamilyTable[i][j].timestampValidBits);
				writeln("            Queue surface support   : ",
					cast(bool)(queueFamilySurfaceSupportTable[i].length > 0 ? queueFamilySurfaceSupportTable[i][j]
					: VK_FALSE));

				if (queueFamilyTable[i][j].queueFlags & VK_QUEUE_GRAPHICS_BIT)
					writeln("            VK_QUEUE_GRAPHICS_BIT");
				if (queueFamilyTable[i][j].queueFlags & VK_QUEUE_COMPUTE_BIT)
					writeln("            VK_QUEUE_COMPUTE_BIT");
				if (queueFamilyTable[i][j].queueFlags & VK_QUEUE_TRANSFER_BIT)
					writeln("            VK_QUEUE_TRANSFER_BIT");
				if (queueFamilyTable[i][j].queueFlags & VK_QUEUE_SPARSE_BINDING_BIT)
					writeln("            VK_QUEUE_SPARSE_BINDING_BIT");
				if (queueFamilyTable[i][j].queueFlags & VK_QUEUE_PROTECTED_BIT)
					writeln("            VK_QUEUE_PROTECTED_BIT");
			}
		}
	}

	/// Use after querying device properties
	private bool isDeviceSuitable(size_t deviceIndex, out uint[] suitableQueueFamilies)
	{
		suitableQueueFamilies = null;

		if (surface)
			if (queueFamilySurfaceSupportTable[deviceIndex].length == 0
				|| surfaceFormatTable[deviceIndex].length == 0
				|| presentModeTable[deviceIndex].length == 0)
				return false;

		foreach (j; 0 .. queueFamilyTable[deviceIndex].length)
			if (isDeviceQueueFamilySuitable(deviceIndex, cast(uint)j))
				suitableQueueFamilies ~= cast(uint)j;

		return suitableQueueFamilies.length > 0;
	}

	/// Use after querying device properties.
	private bool isDeviceQueueFamilySuitable(size_t deviceIndex, uint queueFamilyIndex)
	{
		return (!surface || queueFamilySurfaceSupportTable[deviceIndex][queueFamilyIndex] == VK_TRUE)
			&& (queueFamilyTable[deviceIndex][queueFamilyIndex].queueFlags & VK_QUEUE_GRAPHICS_BIT);
	}
	//endregion
}

//region Error handling
class GraphicsException : Exception
{
	public this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
		@nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
}

class VulkanException : GraphicsException
{
	public this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
		@nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
}

import erupted.types : VkResult;

VkResult enforceVK(VkResult res)
{
	import std.conv : to;
	import std.exception : enforce;
	enforce!VulkanException(res == VkResult.VK_SUCCESS, res.to!string);
	return res;
}
//endregion
