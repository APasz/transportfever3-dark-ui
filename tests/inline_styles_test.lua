-- Runs the shipped React and styleutil code with a strict stand-in for the native API.
-- Native rendering, stylesheet precedence, and the reported limit still need an in-game check.
local gameSource = dofile("tests/game_source.lua").new(assert(arg[1], "Pass the TpF3 install path"))
local DARK_UI_MODULE = "apasz_dark_ui_1::/gui/main/dark_ui_settings.lua"
local GUI_UTIL_MODULE = "apasz_dark_ui_1::/gui/main/dark_ui_gui_util.lua"
local INTEGRATION_MODULE = "apasz_dark_ui_1::/gui/main/dark_ui_ui_tweaks.lua"
local UI_TWEAKS_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/settings.lua"
local REACT_SETTINGS_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/react_settings.lua"
local COMPOSITION_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/recipe_composition.lua"
local STORAGE_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/settings_storage.lua"

package.loaded[INTEGRATION_MODULE] = dofile("content/gui/main/dark_ui_ui_tweaks.lua")
package.loaded[GUI_UTIL_MODULE] = dofile("content/gui/main/dark_ui_gui_util.lua")
package.loaded["apasz_dark_ui_1::/gui/main/dark_ui_palette.lua"] = dofile("content/gui/main/dark_ui_palette.lua")
local settings = dofile("content/gui/main/dark_ui_settings.lua")
package.loaded[DARK_UI_MODULE] = settings

local function nativeConstructor(fields, validators)
	return {
		new = function(source)
			local instance = setmetatable({}, {
				__newindex = function(target, key, value)
					assert(fields[key], "Unexpected native field " .. key)
					if validators ~= nil and validators[key] ~= nil then
						validators[key](value)
					end
					rawset(target, key, value)
				end,
			})
			if source ~= nil then
				for key, value in pairs(source) do
					instance[key] = value
				end
			end
			return instance
		end,
	}
end

local styleAllocations = 0
local nativeImages = setmetatable({}, { __mode = "k" })
local imageAllocations = 0
local imageConstructor = nativeConstructor({ fileName = true })
local styleFields = {
	backgroundColor = true,
	backgroundColor1 = true,
	backgroundColor2 = true,
	backgroundImage1 = true,
	backgroundImage2 = true,
	borderWidth = true,
	borderColor = true,
	color = true,
	size = true,
	padding = true,
	fontSize = true,
	borderImage = true,
	anchorPoint = true,
}
local styleConstructor = nativeConstructor(styleFields, {
	borderImage = function(value)
		assert(nativeImages[value], "Border image must be a native NinePatch")
	end,
})
local newStyle = styleConstructor.new
styleConstructor.new = function()
	local style = newStyle()
	-- Native fields may return defaults even when the sheet never explicitly set them.
	getmetatable(style).__index = { fontSize = -1 }
	return style
end
local defaultColors = { Invisible = { 0.1, 0.2, 0.3, 0 } }
local uiTweaksAvailable = true
local recipeIds = {}
local nextRecipeId = 100
api = {
	gui = {
		NinePatch = {
			new = function()
				local image = imageConstructor.new()
				nativeImages[image] = true
				imageAllocations = imageAllocations + 1
				return image
			end,
		},
		genericRep = {
			find = function(path)
				assert(path == "::/gui/main/default_colors.gres")
				return 1
			end,
			get = function(id)
				assert(id == 1)
				return { data = defaultColors }
			end,
		},
		mouse = { Event = { Type = { Pressed = "pressed", Released = "released", PressedOutside = "pressedOutside" } } },
		StyleSheet = {
			new = function()
				styleAllocations = styleAllocations + 1
				return styleConstructor.new()
			end,
		},
		react = {
			detail = {
				makeRecipeId = function(name)
					assert(recipeIds[name] == nil, "Duplicate test recipe " .. name)
					nextRecipeId = nextRecipeId + 1
					recipeIds[name] = nextRecipeId
					return nextRecipeId
				end,
			},
			params = {
				builtin = {
					Component = nativeConstructor({ layout = true }),
					ImageView = nativeConstructor({ path = true, scaling = true }),
					ToolButton = nativeConstructor({
						toolName = true,
						toolDefinition = true,
						toolVariant = true,
						toolStack = true,
						content = true,
						showFn = true,
						hideFn = true,
					}),
					WithComponentParams = nativeConstructor({
						item = true,
						id = true,
						tooltip = true,
						enabled = true,
						onMouseOver = true,
						onAttention = true,
						onFocusChange = true,
						mouseTransparent = true,
						disableFocusableRecursive = true,
						styleSheet = true,
					}),
				},
			},
		},
	},
	type = {
		Vec2i = {
			new = function(x, y)
				return { x = x, y = y }
			end,
		},
		Vec4f = {
			new = function(x, y, z, w)
				return { x = x, y = y, z = z, w = w }
			end,
		},
	},
	res = {
		genericRep = {
			find = function(path)
				assert(path == "apasz_ui_tweaks::/gui/ui_tweaks/ui_tweaks_settings.res")
				return uiTweaksAvailable and 1 or -1
			end,
		},
	},
}
_react = {
	builtin = { WithComponentParams = 1, Component = 2, ToolButton = 3, ImageView = 4 },
	recipes = {},
	originalRecipeFn = {},
	recipeReplace = {},
	recipeMetas = {},
}
local nativeHandles = setmetatable({}, { __mode = "k" })
local reactEnvironment = setmetatable({
	type = function(value)
		return nativeHandles[value] and "userdata" or type(value)
	end,
	require = function(path)
		assert(path == "/scripts/string_util.tl")
		return {
			format = function(message, values)
				return (message:gsub("{(%w+)}", function(key)
					return tostring(values[key])
				end))
			end,
		}
	end,
	ug_require = function(path)
		assert(path == "/scripts/util.tl")
		return {}
	end,
	log = { verbose = function() end, warning = function() end, error = error },
	toString = tostring,
}, { __index = _G })
local react = gameSource.load("gui", "gui/main/react.lua", reactEnvironment)
local shippedEnqueueJoin = react.enqueueJoin
local queuedJoins, completedJoins = 0, 0
react.enqueueJoin = function(fn, scope)
	queuedJoins = queuedJoins + 1
	shippedEnqueueJoin(function()
		completedJoins = completedJoins + 1
		fn()
	end, scope)
end
local styleutil = gameSource.load("gui", "gui/main/styleutil.tl")
local builtinSource = gameSource.read("gui", "gui/main/builtin.lua")
local toolDeclaration = assert(
	builtinSource:match("builtin%.ToolButton = (.-)\nbuiltin%.RadialMenuChild"),
	"Missing shipped ToolButton declaration"
)
local shippedToolButton = assert(load("return " .. toolDeclaration, "TpF3 ToolButton", "t", { react = react }))()
local builtin = {
	Component = react.DeclareBuiltinWithUserdata("Component", function() end),
	ImageView = react.DeclareBuiltinWithUserdata("ImageView", function() end),
	WithComponentParams = react.builtin.WithComponentParams,
	ToolButton = shippedToolButton,
	ToggleButton = react.RegisterRecipe("ToggleButton", function() end),
}
local toolbarPlugins, toolbarPluginBodies, toolbarRecipes = {}, {}, {}
for _, name in ipairs({ "ModToolbarStyleFixture", "ModToolbarIconProbe", "NonImageToolbarProbe", "SiblingIconProbe" }) do
	local recipe = react.RegisterRecipe(name, function(...)
		return assert(toolbarPluginBodies[name], "Missing toolbar plugin fixture")(...)
	end)
	toolbarRecipes[name] = recipe
	toolbarPlugins[#toolbarPlugins + 1] = { recipe = recipe }
end
local modButtonArea = { MainModButtonAreaExtension = {} }
react.getPlugins = function(extension)
	assert(extension == modButtonArea.MainModButtonAreaExtension)
	return toolbarPlugins
end
local gameBarBody = function() end
local gameBar = { GameBar = react.RegisterRecipe("GameBar", function(...)
	return gameBarBody(...)
end) }
local toolbarReplacement = react.RegisterRecipe("ModToolbarStyleReplacement", function(...)
	return toolbarPluginBodies.ModToolbarStyleFixture(...)
end)
_react.recipeReplace[react.GetRecipeId(toolbarRecipes.ModToolbarStyleFixture)] = toolbarReplacement
local guiUtil = package.loaded[GUI_UTIL_MODULE]
local shippedMergeStyleSheet = guiUtil.mergeStyleSheet
local mergedStyleCount = 0
guiUtil.mergeStyleSheet = function(base, overlay)
	if base ~= nil and #overlay.propertyNames > 0 then
		mergedStyleCount = mergedStyleCount + 1
	end
	return shippedMergeStyleSheet(base, overlay)
end
ug_require = function(path)
	if path == "::/gui/main/react.lua" then
		return react
	end
	if path == "::/gui/main/builtin.lua" then
		return builtin
	end
	if path == "::/gui/main/styleutil.tl" then
		return styleutil
	end
	if path == "::/gui/main/main_mod_button_area.tl" then
		return modButtonArea
	end
	assert(path == "::/gui/game_bar/game_bar.tl", "Unexpected runtime dependency " .. path)
	return gameBar
end

local selectedChoice = settings.VANILLA_CHOICE_ID
local selectedBackground = settings.VANILLA_CHOICE_ID
local selectedBorder = settings.VANILLA_CHOICE_ID
local selectedIcon = settings.VANILLA_CHOICE_ID
local selectedContrast = "standard"
local includeBulldozer = false
local uiTweaksSettings = {
	API_VERSION = 1,
	RESOURCE_TYPE = "ui-tweaks-settings",
	CHANGED_EVENT = "uiTweaksSettingsChanged",
	get = function(sectionId, key)
		assert(sectionId == settings.SECTION_ID)
		if key == settings.strip.key then
			return selectedChoice
		end
		if key == settings.background.key then
			return selectedBackground
		end
		if key == settings.border.key then
			return selectedBorder
		end
		if key == settings.icon.key then
			return selectedIcon
		end
		if key == settings.stateContrast.key then
			return selectedContrast
		end
		assert(key == settings.includeBulldozer.key)
		return includeBulldozer
	end,
}
package.loaded[UI_TWEAKS_MODULE] = uiTweaksSettings
package.loaded[REACT_SETTINGS_MODULE] = dofile("../ui_tweaks/content/gui/ui_tweaks/react_settings.lua")
package.loaded["apasz_ui_tweaks::/gui/ui_tweaks/compatibility.lua"] = { logWorkaround = function() end }
package.loaded[COMPOSITION_MODULE] = dofile("../ui_tweaks/content/gui/ui_tweaks/recipe_composition.lua")
package.loaded[STORAGE_MODULE] = {
	read = function()
		return { sections = {} }
	end,
}

local componentId = react.GetRecipeId(builtin.Component)
local existingReplacementCalls = 0
_react.recipeReplace[componentId] = function(...)
	existingReplacementCalls = existingReplacementCalls + 1
	return _react.originalRecipeFn[componentId](...)
end
local imageId = react.GetRecipeId(builtin.ImageView)
local existingImageCalls = 0
local hideImages = false
_react.recipeReplace[imageId] = function(...)
	existingImageCalls = existingImageCalls + 1
	if hideImages then
		return nil
	end
	return _react.originalRecipeFn[imageId](...)
end
local toolId = react.GetRecipeId(builtin.ToolButton)
local existingToolCalls = 0
_react.recipeReplace[toolId] = function(...)
	existingToolCalls = existingToolCalls + 1
	return _react.originalRecipeFn[toolId](...)
end
local function loadTheme()
	local environment = setmetatable({ type = reactEnvironment.type }, { __index = _G })
	assert(loadfile("content/gui/main/dark_ui_game_bar_theme.script.lua", "t", environment))()
	return environment.data()
end
local theme = loadTheme()
theme.install({
	ReplaceRecipe = function(original, replacement)
		_react.recipeReplace[react.GetRecipeId(original)] = replacement
	end,
})
local initialStyleCount = #settings.strip.choices
assert(styleAllocations == initialStyleCount, "Inline strip/reset styles were not cached at installation")
assert(imageAllocations == 2, "Border images were not shared across button recipes")
local invalidImageStyle = styleConstructor.new()
local imageOk, imageError = pcall(function()
	invalidImageStyle.borderImage = { fileName = "" }
end)
assert(not imageOk and imageError:find("native NinePatch", 1, true), "Test bridge accepted a plain Lua border image")

local background = react.RegisterRecipe("GameBarBackground", function(...)
	return builtin.Component(...)
end)
local unrelated = react.RegisterRecipe("AnotherModRecipe", function(...)
	return builtin.Component(...)
end)

local nextNodeId = 0
local function setInputActionConfig(internals, action, config)
	internals.inputActions = internals.inputActions or {}
	internals.inputActions[action] = config
end
local function newContext()
	local context = { states = {}, handlers = {}, nodes = {}, stateCursor = 0, steps = {}, internals = {} }
	function context:getCurrentRecipeId()
		return self.recipeId
	end
	function context:getCurrentRecipeName()
		return self.recipeName
	end
	function context:declareStateLazy(initialize)
		self.stateCursor = self.stateCursor + 1
		if self.states[self.stateCursor] == nil then
			local state = { value = initialize() }
			function state:old()
				return self.value
			end
			function state:set(value)
				self.value = value
			end
			self.states[self.stateCursor] = state
		end
		return self.states[self.stateCursor]
	end
	function context:declareState(initial)
		return self:declareStateLazy(function()
			return initial
		end)
	end
	function context:declareRef(initial)
		local ref = self:declareState(initial)
		ref.get = ref.old
		nativeHandles[ref] = true
		return ref
	end
	function context:declareRefLazy(initialize)
		local ref = self:declareStateLazy(initialize)
		ref.get = ref.old
		nativeHandles[ref] = true
		return ref
	end
	function context:useComponentInternals()
		self.internals.setInputActionConfig = setInputActionConfig
		return self.internals
	end
	function context:onStep(handler)
		self.steps[#self.steps + 1] = handler
	end
	function context:checkRecipeMatch(nodeId, expected)
		local node = assert(self.nodesById[nodeId], "Wrapped node belongs to another recipe context")
		assert(
			node.recipeId == expected,
			"Wrapper must return the direct wrapped child; metadata wrappers are forbidden"
		)
		return true
	end
	function context:onEvent(handler, name)
		assert(name == uiTweaksSettings.CHANGED_EVENT)
		self.handlers[#self.handlers + 1] = handler
	end
	function context:makeNodeWithProps(recipeId, localKey, props)
		if recipeId == _react.builtin.ToolButton or recipeId == react.GetRecipeId(builtin.ToggleButton) then
			local content = props.props[1].content
			assert(content == nil or self.nodesById[content] ~= nil, "Button content belongs to another recipe context")
		elseif recipeId == _react.builtin.WithComponentParams then
			assert(self.nodesById[props.props[1].item] ~= nil, "Metadata target belongs to another recipe context")
		end
		nextNodeId = nextNodeId + 1
		local nodeId = { sequence = nextNodeId }
		nativeHandles[nodeId] = true
		local node = { id = nodeId, recipeId = recipeId, localKey = localKey, props = props }
		self.nodes[#self.nodes + 1] = node
		self.nodesById[node.id] = node
		return node.id
	end
	function context:makeNodeRef(nodeId)
		return setmetatable({
			nodeId = nodeId,
			containsPosition = function(_, position)
				return position.x >= 0 and position.x < 10 and position.y >= 0 and position.y < 10
			end,
		}, {
			__newindex = function(_, key)
				error("no writable member '" .. key .. "'")
			end,
		})
	end
	function context:setResult(result)
		self.result = result
	end
	function context:renderProps(recipeId, props, name)
		self.recipeName = name
		self.recipeId = recipeId
		self.stateCursor = 0
		self.handlers = {}
		self.nodes = {}
		self.nodesById = {}
		self.steps = {}
		self.internals = {}
		_react.recipes[recipeId](self, props)
		reactEnvironment._reactDoExecuteJoins()
		local node = self.nodes[#self.nodes]
		return node and node.props.props[1]
	end
	function context:render(recipe, ...)
		local previousCalls = existingReplacementCalls
		local result =
			self:renderProps(react.GetRecipeId(recipe), { props = table.pack(...) }, react.GetRecipeName(recipe))
		if recipe == background or recipe == unrelated then
			assert(
				existingReplacementCalls == previousCalls + 1,
				"Strip styling bypassed or repeated the existing replacement"
			)
		end
		return result
	end
	function context:dispatch(sectionId, key, value)
		for _, handler in ipairs(self.handlers) do
			handler(uiTweaksSettings.CHANGED_EVENT, { sectionId = sectionId, settingKey = key, value = value })
		end
	end
	return context
end

local imageConstructorRecipe = react.RegisterRecipe("ImageConstructorFixture", function(...)
	return builtin.ImageView(...)
end)
local constructorContext = newContext()
constructorContext:render(imageConstructorRecipe)
assert(#constructorContext.nodes == 1 and #constructorContext.states == 0)
local nativeImageParams = setmetatable({ path = "copied-image.tga" }, {
	__index = function(_, key)
		error("no readable member '" .. key .. "'")
	end,
})
nativeHandles[nativeImageParams] = true
local copiedImage = constructorContext:render(imageConstructorRecipe, nativeImageParams)
assert(copiedImage ~= nativeImageParams and copiedImage.path == nativeImageParams.path)
hideImages = true
assert(constructorContext:render(imageConstructorRecipe) == nil and #constructorContext.nodes == 0)
hideImages = false
print("Dark UI ImageView constructor compatibility test passed (empty, native parameters, hidden replacement)")

-- Save cards change their icon count while TileElement keeps its own node refs.
local tileBuiltinFields = {
	BoxLayout = { orientation = true, children = true },
	FloatingLayout = { children = true },
	FloatingLayoutChild = { localKey = true, item = true, h = true, v = true },
	TextView = { text = true },
	Button = { content = true, onClick = true, onDoubleClick = true },
}
local nextBuiltinId = _react.builtin.ImageView
for name, fields in pairs(tileBuiltinFields) do
	nextBuiltinId = nextBuiltinId + 1
	_react.builtin[name] = nextBuiltinId
	api.gui.react.params.builtin[name] = nativeConstructor(fields)
	local declare = name == "FloatingLayoutChild" and react.DeclareBuiltinLayoutChildWithUserdata
		or react.DeclareBuiltinWithUserdata
	builtin[name] = declare(name, function() end)
end
builtin.type = { Orientation = { Horizontal = 0, Vertical = 1 }, ImageViewScaling = { AutoFit = 0 } }
api.gui.react.detail.IAForward = nativeConstructor({ targetRef = true, targetAction = true })
api.type["enum"] = { InputMode = { Gamepad = "gamepad" } }
api.util = {
	getInputMode = function()
		return "mouse"
	end,
}
local tilelist = gameSource.load(
	"gui",
	"gui/main/tile_list_react_util.tl",
	setmetatable({
		ug_require = function(path)
			if path == "/gui/main/builtin.lua" then
				return builtin
			end
			if path == "/gui/main/react.lua" then
				return react
			end
			if path == "/gui/main/gui_react_util.tl" then
				local function spacer()
					return builtin.Component({})
				end
				return { makeHorizontalSpacer = spacer, makeVerticalSpacer = spacer, Clipper = builtin.Component }
			end
			assert(path == "/gui/main/callout_react_util.tl")
			return {}
		end,
		_ = function(text)
			return text
		end,
	}, { __index = _G })
)
local tileContext = newContext()
local tileParams = {
	title = "Savegame regression",
	infoIcons = {},
	createButtons = function()
		return { builtin.Button({ content = builtin.Component({}) }) }
	end,
	createImage = function()
		return builtin.ImageView({ path = "savegame-preview.tga" })
	end,
}
local tileStateCount
for _, iconCount in ipairs({ 0, 3, 1, 0, 2, 0 }) do
	tileParams.infoIcons = {}
	for _ = 1, iconCount do
		tileParams.infoIcons[#tileParams.infoIcons + 1] = { path = "info-icon.tga", label = "Save info" }
	end
	local joinsBefore = queuedJoins
	tileContext:render(tilelist.TileElement, tileParams)
	assert(queuedJoins == joinsBefore + 1 and completedJoins == queuedJoins, "Image cleanup was not batched per render")
	assert(
		tileStateCount == nil or #tileContext.states == tileStateCount,
		"Image count changed TileElement's hook slots"
	)
	tileStateCount = #tileContext.states
end
print("Dark UI Load Game TileElement regression test passed (shipped recipe; changing icon counts)")

local imageHandles = setmetatable({}, { __mode = "k" })
local imageLifetimeRecipe = react.RegisterRecipe("MenuImageLifetimeProbe", function(count)
	for _ = 1, count do
		local image = builtin.ImageView({ path = "menu-image.tga" })
		imageHandles[image] = true
	end
	return builtin.Component({})
end)
local lifetimeContext = newContext()
for count = 1, 20 do
	lifetimeContext:render(imageLifetimeRecipe, count)
	collectgarbage("collect")
	local retainedImages = 0
	for _ in pairs(imageHandles) do
		retainedImages = retainedImages + 1
	end
	assert(retainedImages == count, "Icon tracking retained images from a previous render")
end
assert(#lifetimeContext.states == 0, "Image tracking injected state into a menu recipe")
print("Dark UI image tracking lifetime test passed (render cleanup; no injected hook slots)")

local invalidMetadataWrapper = react.RegisterWrapperRecipe("InvalidMetadataWrapperProbe", builtin.Component, function()
	return _react.originalRecipeFn[componentId]({ meta = { id = "invalid-wrapper-child" } })
end)
local invalidWrapperContext = newContext()
local wrapperOk, wrapperError = pcall(invalidWrapperContext.render, invalidWrapperContext, invalidMetadataWrapper)
assert(
	not wrapperOk and wrapperError:find("direct wrapped child", 1, true),
	"Test bridge accepted the wrapper structure that crashed the game"
)

local onMouseOver = function() end
local params = {
	meta = {
		id = "menu.gamebar.bottom",
		class = "bottom,third-party",
		tooltip = "Preserved",
		onMouseOver = onMouseOver,
	},
	layout = {},
}
local context = newContext()
local vanilla = context:render(background, params)
local vanillaStyle = assert(vanilla.styleSheet, "Vanilla did not explicitly clear the inline strip style")
assert(next(vanillaStyle) == nil, "Vanilla overrides the game's stylesheet")
local cachedStyles = {}
for _ = 1, 2 do
	for _, choice in ipairs(settings.strip.choices) do
		selectedChoice = choice.id
		context:dispatch(settings.SECTION_ID, settings.strip.key, choice.id)
		local nativeMeta = context:render(background, params)
		assert(nativeMeta.id == params.meta.id and nativeMeta.tooltip == params.meta.tooltip)
		assert(nativeMeta.onMouseOver == onMouseOver)
		assert(context.nodes[1].recipeId == componentId)
		assert(context.nodes[1].props.style.class == params.meta.class)
		assert(context.nodes[1].props.props[1].meta == nil, "React did not strip metadata from native Component params")
		assert(context.nodes[1].props.props[1].layout == params.layout)
		assert(context.nodes[2].recipeId == _react.builtin.WithComponentParams)
		assert(nativeMeta.item == context.nodes[1].id, "Inline style was not forwarded to the original component")
		assert(params.meta.styleSheet == nil, "Inline strip styling mutated incoming metadata")
		if choice.gray == nil then
			assert(nativeMeta.styleSheet == vanillaStyle, "Returning to Vanilla did not clear an inline override")
			cachedStyles[choice.id] = vanillaStyle
		else
			local style = assert(nativeMeta.styleSheet, "Inline style did not reach WithComponentParams")
			local color = style.backgroundColor
			assert(color.x == choice.gray / 255 and color.y == color.x and color.z == color.x and color.w == 1)
			assert(cachedStyles[choice.id] == nil or cachedStyles[choice.id] == style, "Inline styles were recreated")
			cachedStyles[choice.id] = style
		end
	end
end
assert(styleAllocations == initialStyleCount + mergedStyleCount)

selectedChoice = "black"
context:dispatch("another.mod", settings.strip.key, selectedChoice)
assert(
	context:render(background, params).styleSheet == cachedStyles.white,
	"Unrelated settings event changed the strip"
)
context:dispatch(settings.SECTION_ID, settings.background.key, selectedChoice)
assert(context:render(background, params).styleSheet == cachedStyles.white)
context:dispatch(settings.SECTION_ID, settings.strip.key, selectedChoice)
assert(context:render(background, params).styleSheet == cachedStyles.black)

local reference = {
	set = function(self, value)
		self.value = value
	end,
}
local refArgument = react.ref({ reference })
local styleArgument = react.style({ class = "external-class" })
for _, arguments in ipairs({ { refArgument, styleArgument, params }, { styleArgument, refArgument, params } }) do
	assert(context:render(background, table.unpack(arguments)).styleSheet == cachedStyles.black)
	assert(reference.value.nodeId == context.nodes[1].id, "Inline styling changed the component reference")
	assert(styleArgument.data.class == "external-class")
end

local unrelatedContext = newContext()
assert(unrelatedContext:render(unrelated, params).styleSheet == nil, "Inline styling escaped GameBarBackground")
assert(#unrelatedContext.states == 0)
local otherParams = { meta = { id = "another.mod.bottom", class = "bottom" } }
assert(unrelatedContext:render(background, otherParams).styleSheet == nil, "Inline styling changed another component")
assert(#unrelatedContext.states == 0)

local foreignStyle = styleConstructor.new()
local originalForeignFields = {}
local foreignImage = imageConstructor.new()
foreignImage.fileName = "mod-image.tga"
nativeImages[foreignImage] = true
for name in pairs(styleFields) do
	if name:find("Image", 1, true) then
		foreignStyle[name] = foreignImage
	elseif name == "fontSize" then
		foreignStyle[name] = 17
	else
		foreignStyle[name] = { x = 0.1, y = 0.2, z = 0.3, w = 0.4 }
	end
	originalForeignFields[name] = foreignStyle[name]
end
local function assertMergedStyle(actual, overrides)
	assert(actual ~= foreignStyle, "Dark UI mutated the supplied sheet")
	for name in pairs(styleFields) do
		assert(foreignStyle[name] == originalForeignFields[name], "Style merging mutated the source's " .. name)
		local expected = overrides[name]
		if expected == nil then
			expected = foreignStyle[name]
		end
		assert(actual[name] == expected, "Style merging lost or replaced " .. name)
	end
end
local foreignParams = { meta = { id = params.meta.id, styleSheet = foreignStyle } }
local mergedStrip = context:render(background, foreignParams).styleSheet
assertMergedStyle(mergedStrip, { backgroundColor = mergedStrip.backgroundColor })
assert(mergedStrip.backgroundColor.x == 0)
foreignStyle.padding = { x = 9, y = 8, z = 7, w = 6 }
originalForeignFields.padding = foreignStyle.padding
local updatedStrip = context:render(background, foreignParams).styleSheet
assertMergedStyle(updatedStrip, { backgroundColor = updatedStrip.backgroundColor })
assert(updatedStrip.padding ~= mergedStrip.padding, "In-place source changes were cached away")
context:dispatch(settings.SECTION_ID, settings.strip.key, settings.VANILLA_CHOICE_ID)
assert(
	context:render(background, foreignParams).styleSheet == foreignStyle,
	"Vanilla replaced another mod's inline style"
)
context:dispatch(settings.SECTION_ID, settings.strip.key, "invalid")
assert(not pcall(context.render, context, background, params), "Invalid inline colour was silently accepted")

local componentReplacement = _react.recipeReplace[componentId]
theme.install({
	ReplaceRecipe = function()
		error("Strip styling installed twice")
	end,
})
assert(
	_react.recipeReplace[componentId] == componentReplacement
		and styleAllocations == initialStyleCount + mergedStyleCount
)
uiTweaksAvailable = false
loadTheme().install({
	ReplaceRecipe = function()
		error("Inline styling installed without UI Tweaks")
	end,
})
assert(
	_react.recipeReplace[componentId] == componentReplacement
		and styleAllocations == initialStyleCount + mergedStyleCount
)
print("Dark UI inline strip React bridge test passed (shipped React/styleutil; native rendering not tested)")

uiTweaksAvailable = true
local function buttonParent(name, recipe, makeContent)
	local function body(...)
		local arguments = table.pack(...)
		local params = arguments[arguments.n]
		local configured = {}
		for key, value in pairs(params) do
			configured[key] = value
		end
		configured.content = params.content
			or (makeContent and makeContent() or builtin.ImageView({ path = "test-icon.tga" }))
		arguments[arguments.n] = configured
		return recipe(table.unpack(arguments, 1, arguments.n))
	end
	if name == "GameBar" then
		gameBarBody = body
		return gameBar.GameBar
	end
	if toolbarRecipes[name] ~= nil then
		toolbarPluginBodies[name] = body
		return toolbarRecipes[name]
	end
	return react.RegisterRecipe(name, body)
end
local toolParent = buttonParent("ManagerToolButton", builtin.ToolButton)
local toggleParent = buttonParent("NodeEditorButton", builtin.ToggleButton)
local constructionParent = buttonParent("ConstructionToolButton", builtin.ToolButton)
local unrelatedToolParent = buttonParent("AnotherToolParent", builtin.ToolButton)

local function newButton(parent, params, isTool)
	local button = { parent = newContext(), native = newContext(), params = params }
	function button:render()
		self.nativeNode = nil
		local previousToolCalls = existingToolCalls
		local nativeMeta = self.parent:render(parent, self.params)
		assert(
			existingToolCalls == previousToolCalls + (isTool and 1 or 0),
			"Styling bypassed or repeated a ToolButton replacement"
		)
		for _, node in ipairs(self.parent.nodes) do
			if node.recipeId == react.GetRecipeId(isTool and builtin.ToolButton or builtin.ToggleButton) then
				self.nativeNode = node
			end
			assert(_react.recipeMetas[node.recipeId] == nil, "Inline styling introduced a recipe context boundary")
		end
		assert(self.nativeNode ~= nil)
		if isTool then
			self.native:renderProps(self.nativeNode.recipeId, self.nativeNode.props, "ToolButton")
		end
		return nativeMeta
	end
	function button:step()
		for _, current in ipairs({ self.parent, self.native }) do
			for _, handler in ipairs(current.steps) do
				handler()
			end
		end
	end
	function button:change(option, value)
		self.parent:dispatch(settings.SECTION_ID, option.key, value)
	end
	return button
end

local activeTool, activeVariant
local expectedTool = { name = "Manager" }
local toolStack = {
	get = function()
		return {
			getApi = function()
				return {
					getActiveTool = function()
						return activeTool, activeVariant
					end,
				}
			end,
		}
	end,
}
local attentionCalls = 0
local changedValues = {}
local showFn, hideFn = function() end, function() end
local function buttonParams()
	return {
		meta = {
			id = "test.button",
			tooltip = "Preserved button tooltip",
			onAttention = function()
				attentionCalls = attentionCalls + 1
			end,
			onMouseOver = onMouseOver,
		},
	}
end
local toolParams = buttonParams()
toolParams.toolName = "Manager"
toolParams.toolVariant = "main"
toolParams.toolStack = toolStack
toolParams.showFn, toolParams.hideFn = showFn, hideFn
local toolButton = newButton(toolParent, toolParams, true)

local foreignContentContext = newContext()
foreignContentContext:render(unrelated, {})
local foreignContentParams = buttonParams()
foreignContentParams.content = foreignContentContext.nodes[1].id
local contentContext = newContext()
local contentOk, contentError = pcall(contentContext.render, contentContext, toolParent, foreignContentParams)
assert(
	not contentOk and contentError:find("content belongs to another recipe context", 1, true),
	"Test bridge accepted a foreign content node"
)
local toggleParams = buttonParams()
toggleParams.value = 0
toggleParams.onValueChange = function(value)
	changedValues[#changedValues + 1] = value
end
local toggleButton = newButton(toggleParent, toggleParams, false)
local buttons = { toolButton, toggleButton }
local cases = {
	{ id = "normal", checked = false, attention = false, enabled = true },
	{ id = "selected", checked = true, attention = false, enabled = true },
	{ id = "idleHover", checked = false, attention = true, enabled = true },
	{ id = "selectedHover", checked = true, attention = true, enabled = true },
	{ id = "disabled", checked = true, attention = true, enabled = false },
}
local function assertGray(color, gray)
	local channel = gray / 255
	assert(
		color ~= nil and color.x == channel and color.y == channel and color.z == channel and color.w == 1,
		string.format("Expected grey %.17g, got %s", channel, tostring(color and color.x))
	)
end

local cachedBackgrounds = {}
local function assertBackground(nativeMeta, expected)
	local style = assert(nativeMeta.styleSheet, "Inline button background did not reach native metadata")
	local color = assert(style.backgroundColor1)
	assertGray(color, expected)
	assert(
		cachedBackgrounds[expected] == nil or cachedBackgrounds[expected] == style,
		"Button background style was recreated"
	)
	cachedBackgrounds[expected] = style
	assert(nativeMeta.tooltip == toolParams.meta.tooltip and nativeMeta.onMouseOver == onMouseOver)
end

local backgroundCaseCount = 0
for _, choice in ipairs(settings.background.choices) do
	if choice.gray ~= nil then
		selectedBackground = choice.id
		for _, contrast in ipairs(settings.stateContrast.choices) do
			selectedContrast = contrast.id
			for _, case in ipairs(cases) do
				activeTool = case.checked and expectedTool or nil
				activeVariant = "main"
				toolParams.meta.enabled = case.enabled
				toggleParams.meta.enabled = case.enabled
				toggleParams.value = case.checked and 1 or 0
				for _, button in ipairs(buttons) do
					button:change(settings.background, choice.id)
					button:change(settings.stateContrast, contrast.id)
					button:render().onAttention(case.attention)
					button:step()
					local meta = button:render()
					assertBackground(meta, settings.colorGray(settings.background, choice.id, contrast.id, case.id))
					assert(button.params.meta.styleSheet == nil, "Inline background mutated original params")
					backgroundCaseCount = backgroundCaseCount + 1
				end
				assert(
					toolButton.native.internals.styleClasses == (case.checked and "checked" or "unchecked"),
					"Inline selection differs from the shipped ToolButton"
				)
			end
		end
	end
end
assert(attentionCalls == backgroundCaseCount, "Existing attention callback was lost or repeated")
assert(toolButton.nativeNode.props.props[1].showFn == showFn and toolButton.nativeNode.props.props[1].hideFn == hideFn)
assert(toolButton.parent.nodes[2].props.props[1].item == toolButton.parent.nodes[1].id)

local referenceContext = newContext()
for _, prefix in ipairs({ { refArgument, styleArgument }, { styleArgument, refArgument } }) do
	local nativeMeta = referenceContext:render(toolParent, prefix[1], prefix[2], toolParams)
	assert(nativeMeta.onAttention ~= nil)
	assert(
		referenceContext.nodesById[reference.value.nodeId].recipeId == _react.builtin.ToolButton,
		"Inline background lost the original button reference"
	)
	assert(
		#refArgument.data == 1 and refArgument.data[1] == reference,
		"Inline background mutated the original reference list"
	)
	assert(styleArgument.data.class == "external-class")
end

local nativeReference = newContext():declareRef(nil)
local nativeReferenceArgument = react.ref(nativeReference)
referenceContext:render(toolParent, nativeReferenceArgument, toolParams)
assert(
	referenceContext.nodesById[nativeReference:get().nodeId].recipeId == toolId,
	"Styling lost a native button reference"
)
assert(nativeReferenceArgument.data == nativeReference, "Styling mutated the original reference argument")

local extraParent = buttonParent("ModToolbarStyleFixture", builtin.ToggleButton)
local extraStyle = react.style({ class = "extra,third-party" })
local gameBarParent = buttonParent("GameBar", builtin.ToggleButton)
for _, parent in ipairs({ extraParent, toolbarReplacement, gameBarParent }) do
	for _, prefix in ipairs({ { extraStyle, nativeReferenceArgument }, { nativeReferenceArgument, extraStyle } }) do
		local extraContext = newContext()
		local extraParams = buttonParams()
		extraParams.value = 0
		local meta = extraContext:render(parent, prefix[1], prefix[2], extraParams)
		assertBackground(meta, settings.colorGray(settings.background, selectedBackground, selectedContrast, "normal"))
		local node = extraContext.nodesById[nativeReference:get().nodeId]
		assert(
			node.recipeId == react.GetRecipeId(builtin.ToggleButton) and node.props.style.class == extraStyle.data.class
		)
		assert(extraParams.meta.class == nil, "Styling mutated incoming button classes")
	end
end
local outsideToolbar = buttonParent("UnrelatedModWindow", builtin.ToggleButton)
for _, prefix in ipairs({ { extraStyle, nativeReferenceArgument }, { nativeReferenceArgument, extraStyle } }) do
	local outsideContext = newContext()
	local outsideParams = buttonParams()
	assert(outsideContext:render(outsideToolbar, prefix[1], prefix[2], outsideParams).styleSheet == nil)
	assert(#outsideContext.states == 0, "Toolbar hooks leaked into an unrelated extra button")
	outsideParams.meta.class = "extra"
	assert(outsideContext:render(outsideToolbar, outsideParams).styleSheet == nil)
end
for _, class in ipairs({ "third-party", "extraordinary" }) do
	local unstyledContext = newContext()
	local unstyledParams = buttonParams()
	unstyledParams.meta.class = class
	assert(unstyledContext:render(extraParent, unstyledParams).styleSheet == nil)
	assert(#unstyledContext.states == 0, "A toolbar plugin button without the extra class was styled")
end
print("Dark UI toolbar targeting test passed (GameBar, registered plugins/replacements, unrelated extra buttons)")

for _, field in ipairs({ "value", "initialValue" }) do
	local invalidParams = buttonParams()
	invalidParams[field] = false
	local invalidToggle = newButton(toggleParent, invalidParams, false)
	local ok, message = pcall(invalidToggle.render, invalidToggle)
	assert(not ok and message:find("invalid toggle value", 1, true), "Styling accepted an invalid toggle value")
end

local parentMouseCalls = 0
local observingParent = react.RegisterRecipe("MapEditorToolButton", function(params)
	react.onMouseEvent(function()
		parentMouseCalls = parentMouseCalls + 1
		return true
	end)
	local configured = {}
	for key, value in pairs(params) do
		configured[key] = value
	end
	configured.content = builtin.Component({})
	return builtin.ToolButton(configured)
end)
local observingButton = newButton(observingParent, buttonParams(), true)
observingButton:render().onAttention(true)
observingButton:render()
assert(observingButton.parent.internals.mouseListener({
	type = api.gui.mouse.Event.Type.Pressed,
	button = 0,
	x = 20,
	y = 20,
}) == true)
assert(parentMouseCalls == 1, "Inline background replaced the parent's mouse listener")
assertBackground(
	observingButton:render(),
	settings.colorGray(settings.background, selectedBackground, selectedContrast, "idleHover")
)

selectedBackground, selectedContrast = "gray", "standard"
for _, button in ipairs(buttons) do
	button.params.meta.enabled = true
	button:change(settings.background, selectedBackground)
	button:change(settings.stateContrast, selectedContrast)
	button:render().onAttention(true)
	button:step()
	button:render()
	local mouse = api.gui.mouse.Event.Type
	local function mouseEvent(kind, mouseButton)
		assert(
			button.parent.internals.mouseListener({ type = kind, button = mouseButton, x = 5, y = 5, handled = true })
				== false,
			"Inline styling consumed a button action"
		)
	end
	mouseEvent(mouse.Pressed, 1)
	assertBackground(button:render(), settings.colorGray(settings.background, "gray", "standard", "selectedHover"))
	mouseEvent(mouse.Pressed, 0)
	assertBackground(button:render(), settings.colorGray(settings.background, "gray", "standard", "selected"))
	button:render().onAttention(false)
	button:render().onAttention(true)
	assertBackground(button:render(), settings.colorGray(settings.background, "gray", "standard", "selected"))
	mouseEvent(mouse.Released, 0)
	assertBackground(button:render(), settings.colorGray(settings.background, "gray", "standard", "selectedHover"))
	mouseEvent(mouse.Pressed, 0)
	mouseEvent(mouse.PressedOutside, 0)
	assertBackground(button:render(), settings.colorGray(settings.background, "gray", "standard", "selectedHover"))
	button.params.meta.enabled = false
	mouseEvent(mouse.Pressed, 0)
	assertBackground(button:render(), settings.colorGray(settings.background, "gray", "standard", "disabled"))
	button:render().onAttention(false)
	button.params.meta.enabled = true
	assertBackground(button:render(), settings.colorGray(settings.background, "gray", "standard", "selected"))
	mouseEvent(mouse.Released, 0)
end

activeVariant = "another-variant"
toolButton:step()
assertBackground(toolButton:render(), settings.colorGray(settings.background, "gray", "standard", "normal"))
assert(toolButton.native.internals.styleClasses == "unchecked")
toolParams.toolName = nil
toolParams.toolDefinition = expectedTool
activeVariant = "main"
toolButton:step()
assertBackground(toolButton:render(), settings.colorGray(settings.background, "gray", "standard", "selected"))

toggleParams.value = nil
toggleButton:render()
local originalCallback = toggleParams.onValueChange
local nativeToggle = toggleButton.nativeNode.props.props[1]
nativeToggle.onValueChange(1)
assert(changedValues[#changedValues] == 1 and toggleParams.onValueChange == originalCallback)
assertBackground(toggleButton:render(), settings.colorGray(settings.background, "gray", "standard", "selected"))
nativeToggle = toggleButton.nativeNode.props.props[1]
nativeToggle.onValueChange(0)
assert(changedValues[#changedValues] == 0)
assertBackground(toggleButton:render(), settings.colorGray(settings.background, "gray", "standard", "normal"))
local initialToggleParams = buttonParams()
initialToggleParams.initialValue = 1
local initialToggle = newButton(toggleParent, initialToggleParams, false)
assertBackground(initialToggle:render(), settings.colorGray(settings.background, "gray", "standard", "selected"))
local alreadyTaggedParams = buttonParams()
alreadyTaggedParams.meta.class = "third-party-button"
local alreadyTagged = newButton(toolParent, alreadyTaggedParams, true)
assertBackground(alreadyTagged:render(), settings.colorGray(settings.background, "gray", "standard", "normal"))

for _, missingStack in ipairs({
	{
		get = function()
			return nil
		end,
	},
	{
		get = function()
			return {
				getApi = function()
					return nil
				end,
			}
		end,
	},
}) do
	local unavailableParams = buttonParams()
	unavailableParams.toolStack = missingStack
	local unavailableTool = newButton(toolParent, unavailableParams, true)
	unavailableTool:render()
	unavailableTool:step()
	assertBackground(unavailableTool:render(), settings.colorGray(settings.background, "gray", "standard", "normal"))
end

for _, button in ipairs(buttons) do
	button:change(settings.background, "gray")
	local expectedBackground = button:render().styleSheet.backgroundColor1
	button:change(settings.background, settings.VANILLA_CHOICE_ID)
	assert(button:render().styleSheet == vanillaStyle, "Returning to Vanilla did not clear a button background")
	button.params.meta.styleSheet = foreignStyle
	assert(button:render().styleSheet == foreignStyle)
	button:change(settings.background, "gray")
	local merged = button:render().styleSheet
	assertMergedStyle(merged, { backgroundColor1 = merged.backgroundColor1 })
	assert(merged.backgroundColor1 == expectedBackground)
	button.params.meta.styleSheet = nil
end

local unrelatedButtonContext = newContext()
assert(unrelatedButtonContext:render(unrelatedToolParent, toolParams).styleSheet == nil)
local bulldozerParams = buttonParams()
bulldozerParams.meta.id = "menu.bulldozer"
assert(
	unrelatedButtonContext:render(constructionParent, bulldozerParams).styleSheet == vanillaStyle,
	"Excluded bulldozer received an inline background"
)
includeBulldozer = true
unrelatedButtonContext:dispatch(settings.SECTION_ID, settings.includeBulldozer.key, true)
unrelatedButtonContext:render(constructionParent, bulldozerParams)
assert(
	unrelatedButtonContext:render(constructionParent, bulldozerParams).onAttention ~= nil
		and #unrelatedButtonContext.steps == 1,
	"Bulldozer inclusion did not enable the inline background"
)
includeBulldozer = false
unrelatedButtonContext:dispatch(settings.SECTION_ID, settings.includeBulldozer.key, false)
assert(unrelatedButtonContext:render(constructionParent, bulldozerParams).styleSheet == vanillaStyle)

local distinctBackgrounds = 0
for _ in pairs(cachedBackgrounds) do
	distinctBackgrounds = distinctBackgrounds + 1
end
assert(
	styleAllocations == initialStyleCount + distinctBackgrounds + mergedStyleCount,
	"Inline background cache grew beyond the used colours"
)
print(
	"Dark UI inline button React bridge test passed ("
		.. backgroundCaseCount
		.. " state/colour/contrast cases; native interaction not tested)"
)

local combinedStyles = {}
local cachedIconStyles = {}
local coloredBorderImage, clearedBorderImage
local function colorSignature(color)
	if color == nil then
		return "vanilla"
	end
	return string.format("%.17g,%.17g,%.17g,%.17g", color.x, color.y, color.z, color.w)
end

local function assertIconStyle(button, choiceId, contrastId, stateId)
	local content = button.nativeNode.props.props[1].content
	local node = assert(button.parent.nodesById[content], "Styled icon left its owning recipe context")
	local gray = settings.colorGray(settings.icon, choiceId, contrastId, stateId)
	assert(node.recipeId == _react.builtin.WithComponentParams, "Icon colour did not reach native metadata")
	local meta = node.props.props[1]
	assert(button.parent.nodesById[meta.item].recipeId == _react.builtin.ImageView, "Icon node was replaced")
	local style = assert(meta.styleSheet)
	if gray == nil then
		assert(style == vanillaStyle, "Vanilla did not explicitly clear an inline icon override")
		return
	end
	local color = assert(style.color)
	assertGray(color, gray)
	assert(style.backgroundColor == nil and style.backgroundColor1 == nil and style.borderColor == nil)
	assert(style.borderImage == nil and style.backgroundColor2 == nil)
	assert(cachedIconStyles[gray] == nil or cachedIconStyles[gray] == style, "Icon colour style was recreated")
	cachedIconStyles[gray] = style
end

local function assertCombinedStyle(meta, backgroundId, borderId, contrastId, stateId)
	local backgroundGray = settings.colorGray(settings.background, backgroundId, contrastId, stateId)
	local borderGray = settings.colorGray(settings.border, borderId, contrastId, stateId)
	if backgroundGray == nil and borderId == settings.VANILLA_CHOICE_ID then
		assert(meta.styleSheet == vanillaStyle, "Vanilla choices did not explicitly clear the button style")
		return
	end
	local style = assert(meta.styleSheet, "Combined inline style did not reach native metadata")

	if backgroundGray == nil then
		assert(style.backgroundColor1 == nil, "Border styling changed a Vanilla background")
	else
		assertGray(style.backgroundColor1, backgroundGray)
	end
	if borderId == settings.VANILLA_CHOICE_ID then
		assert(style.borderColor == nil and style.borderImage == nil, "Background styling changed a Vanilla border")
	elseif borderId == settings.NONE_CHOICE_ID then
		local color = assert(style.borderColor)
		local expected = defaultColors.Invisible
		assert(color.x == expected[1] and color.y == expected[2] and color.z == expected[3] and color.w == expected[4])
		assert(style.borderImage.fileName == "", "None retained the border image")
		assert(clearedBorderImage == nil or clearedBorderImage == style.borderImage, "Empty border image was recreated")
		clearedBorderImage = style.borderImage
	else
		assertGray(style.borderColor, borderGray)
		assert(
			style.borderImage.fileName == settings.border.imageFile,
			"Coloured border did not restore its contour image"
		)
		assert(
			coloredBorderImage == nil or coloredBorderImage == style.borderImage,
			"Border contour image was recreated"
		)
		coloredBorderImage = style.borderImage
	end
	assert(style.backgroundColor == nil and style.color == nil and style.backgroundColor2 == nil)
	local signature = table.concat({
		colorSignature(style.backgroundColor1),
		colorSignature(style.borderColor),
		style.borderImage and style.borderImage.fileName or "vanilla",
	}, "|")
	assert(
		combinedStyles[signature] == nil or combinedStyles[signature] == style,
		"Identical combined styles were recreated"
	)
	combinedStyles[signature] = style
end

local combinedCaseCount = 0
for _, backgroundChoice in ipairs(settings.background.choices) do
	selectedBackground = backgroundChoice.id
	for _, borderChoice in ipairs(settings.border.choices) do
		selectedBorder = borderChoice.id
		for _, iconChoice in ipairs(settings.icon.choices) do
			selectedIcon = iconChoice.id
			for _, contrast in ipairs(settings.stateContrast.choices) do
				selectedContrast = contrast.id
				for _, case in ipairs(cases) do
					activeTool, activeVariant = case.checked and expectedTool or nil, "main"
					toolParams.meta.enabled, toggleParams.meta.enabled = case.enabled, case.enabled
					toggleParams.value = case.checked and 1 or 0
					for _, button in ipairs(buttons) do
						button:change(settings.background, selectedBackground)
						button:change(settings.border, selectedBorder)
						button:change(settings.icon, selectedIcon)
						button:change(settings.stateContrast, selectedContrast)
						button:render().onAttention(case.attention)
						button:step()
						assertCombinedStyle(
							button:render(),
							selectedBackground,
							selectedBorder,
							selectedContrast,
							case.id
						)
						assertIconStyle(button, selectedIcon, selectedContrast, case.id)
						assert(button.params.meta.styleSheet == nil)
						combinedCaseCount = combinedCaseCount + 1
					end
				end
			end
		end
	end
end

selectedBackground, selectedIcon, selectedContrast = "gray", "vanilla", "standard"
activeTool = nil
toggleParams.value = 0
for _, button in ipairs(buttons) do
	button.params.meta.enabled = true
	button:change(settings.background, selectedBackground)
	button:change(settings.stateContrast, selectedContrast)
	button:change(settings.icon, selectedIcon)
	button:render().onAttention(false)
	button:step()
	for _, borderId in ipairs({ "none", "white", "vanilla", "none" }) do
		button:change(settings.border, borderId)
		assertCombinedStyle(button:render(), selectedBackground, borderId, selectedContrast, "normal")
	end
	button:change(settings.background, "vanilla")
	button.params.meta.styleSheet = foreignStyle
	local merged = button:render().styleSheet
	assertMergedStyle(merged, { borderColor = merged.borderColor, borderImage = merged.borderImage })
	assert(merged.borderImage.fileName == "" and merged.borderColor.w == 0)
	button:change(settings.border, "vanilla")
	assert(button:render().styleSheet == foreignStyle, "Vanilla choices replaced a third-party inline style")
	button.params.meta.styleSheet = nil
end

local uniqueCombinedStyles = 0
for _ in pairs(combinedStyles) do
	uniqueCombinedStyles = uniqueCombinedStyles + 1
end

selectedBackground, selectedBorder, selectedIcon = "vanilla", "vanilla", "gray"
activeTool, activeVariant = nil, "main"
for _, parent in ipairs({ toolParent, toggleParent }) do
	local isTool = parent == toolParent
	local iconParams = buttonParams()
	iconParams.meta.styleSheet = foreignStyle
	if not isTool then
		iconParams.value = 0
	end
	local iconButton = newButton(parent, iconParams, isTool)
	assert(iconButton:render().styleSheet == foreignStyle, "Icon-only styling replaced the button's inline style")
	assertIconStyle(iconButton, selectedIcon, selectedContrast, "normal")
	iconButton:render().onAttention(true)
	iconButton:render()
	assertIconStyle(iconButton, selectedIcon, selectedContrast, "idleHover")
	local mouse = api.gui.mouse.Event.Type
	iconButton.parent.internals.mouseListener({ type = mouse.Pressed, button = 0, x = 5, y = 5 })
	iconButton:render()
	assertIconStyle(iconButton, selectedIcon, selectedContrast, "normal")
	iconButton.parent.internals.mouseListener({ type = mouse.Released, button = 0, x = 5, y = 5 })
	iconButton:render()
	assertIconStyle(iconButton, selectedIcon, selectedContrast, "idleHover")
	iconParams.meta.enabled = false
	iconButton:render()
	assertIconStyle(iconButton, selectedIcon, selectedContrast, "disabled")
	iconParams.meta.enabled = true
	iconButton:render().onAttention(false)
	for _, choiceId in ipairs({ "white", "vanilla", "gray", "vanilla" }) do
		iconButton:change(settings.icon, choiceId)
		assert(iconButton:render().styleSheet == foreignStyle)
		assertIconStyle(iconButton, choiceId, selectedContrast, "normal")
	end
	iconButton:change(settings.icon, "invalid")
	assert(not pcall(iconButton.render, iconButton), "Invalid icon colour was silently accepted")
end

local imageRef = { set = reference.set }
local imageParams = { meta = { class = "third-party-icon", tooltip = "Icon tooltip" }, path = "mod-icon.tga" }
local metadataParent = buttonParent("ModToolbarIconProbe", builtin.ToggleButton, function()
	return builtin.ImageView(react.ref({ imageRef }), imageParams)
end)
local metadataParams = buttonParams()
metadataParams.meta.class = "extra,mod-toolbar"
local metadataButton = newButton(metadataParent, metadataParams, false)
for _, choice in ipairs(settings.icon.choices) do
	selectedIcon = choice.id
	metadataButton:change(settings.icon, selectedIcon)
	local calls = existingImageCalls
	metadataButton:render()
	assert(existingImageCalls == calls + 1, "Icon styling bypassed or repeated an active ImageView replacement")
	local imageNode = metadataButton.parent.nodes[1]
	assert(imageRef.value.nodeId == imageNode.id and imageNode.recipeId == imageId, "Icon reference was changed")
	assert(imageNode.props.style.class == imageParams.meta.class and imageNode.props.props[1].path == imageParams.path)
	local originalMeta = metadataButton.parent.nodes[2].props.props[1]
	assert(originalMeta.tooltip == imageParams.meta.tooltip and originalMeta.item == imageNode.id)
	local content = metadataButton.nativeNode.props.props[1].content
	local contentMeta = metadataButton.parent.nodesById[content].props.props[1]
	assert(contentMeta.item == metadataButton.parent.nodes[2].id, "Icon metadata was lost")
	local expectedStyle = choice.gray == nil and vanillaStyle
		or cachedIconStyles[settings.colorGray(settings.icon, choice.id, selectedContrast, "normal")]
	assert(contentMeta.styleSheet == expectedStyle)
	assert(imageParams.meta.styleSheet == nil, "Inline icon styling mutated incoming metadata")
end

imageParams.meta.styleSheet = foreignStyle
metadataButton:change(settings.icon, "gray")
metadataButton:render()
local mergedIcon =
	metadataButton.parent.nodesById[metadataButton.nativeNode.props.props[1].content].props.props[1].styleSheet
assertMergedStyle(mergedIcon, { color = mergedIcon.color })
assert(mergedIcon.color.x == settings.colorGray(settings.icon, "gray", selectedContrast, "normal") / 255)
metadataButton:change(settings.icon, "vanilla")
metadataButton:render()
assert(metadataButton.parent.nodes[2].props.props[1].styleSheet == foreignStyle, "Vanilla replaced a mod icon style")

selectedIcon = "gray"
local nonImageParent = buttonParent("NonImageToolbarProbe", builtin.ToggleButton, function()
	return builtin.Component({})
end)
local nonImageParams = buttonParams()
nonImageParams.meta.class = "extra"
local nonImageButton = newButton(nonImageParent, nonImageParams, false)
nonImageButton:render()
assert(nonImageButton.nativeNode.props.props[1].content == nonImageButton.parent.nodes[1].id)
assert(#nonImageButton.parent.nodes == 3, "Icon styling changed non-image content")

local siblingParent = buttonParent("SiblingIconProbe", builtin.ToggleButton, function()
	builtin.ImageView({ path = "unrelated-image.tga" })
	return builtin.ImageView({ path = "button-image.tga" })
end)
local siblingButton = newButton(siblingParent, nonImageParams, false)
siblingButton:render()
assertIconStyle(siblingButton, selectedIcon, selectedContrast, "normal")
local styledContent = siblingButton.parent.nodesById[siblingButton.nativeNode.props.props[1].content]
assert(styledContent.props.props[1].item == siblingButton.parent.nodes[2].id, "Icon styling selected a sibling image")
assert(#siblingButton.parent.nodes == 5, "Icon styling added metadata to an unrelated image")

local untargeted = newButton(unrelatedToolParent, buttonParams(), true)
untargeted:render()
assert(untargeted.nativeNode.props.props[1].content == untargeted.parent.nodes[1].id)
assert(#untargeted.parent.nodes == 3, "Icon styling escaped the toolbar button targets")
local excluded = newButton(constructionParent, bulldozerParams, true)
excluded:render()
assertIconStyle(excluded, "vanilla", selectedContrast, "normal")
includeBulldozer = true
excluded:change(settings.includeBulldozer, true)
excluded:render()
assertIconStyle(excluded, selectedIcon, selectedContrast, "normal")
includeBulldozer = false
excluded:change(settings.includeBulldozer, false)
excluded:render()
assertIconStyle(excluded, "vanilla", selectedContrast, "normal")

-- Model the reported native retention: missing metadata leaves an existing override in place.
local function applyNativeStyle(previous, meta)
	if meta.styleSheet ~= nil then
		return meta.styleSheet
	end
	return previous
end
assert(applyNativeStyle(foreignStyle, {}) == foreignStyle, "Reset fixture discarded a retained native style")

local function updateRetainedStyles(button, retained)
	local meta = button:render()
	retained.button = applyNativeStyle(retained.button, meta)
	local content = button.nativeNode.props.props[1].content
	local node = button.parent.nodesById[content]
	if node.recipeId == _react.builtin.WithComponentParams then
		retained.icon = applyNativeStyle(retained.icon, node.props.props[1])
	end
end

selectedBackground, selectedBorder, selectedIcon, selectedContrast = "gray", "none", "black", "standard"
for _, parent in ipairs({ toolParent, toggleParent, constructionParent }) do
	local resetParams = buttonParams()
	resetParams.meta.class = "extra"
	local isBulldozer = parent == constructionParent
	if isBulldozer then
		resetParams.meta.id = "menu.bulldozer"
	end
	includeBulldozer = true
	local resetButton = newButton(parent, resetParams, parent ~= toggleParent)
	local retained = {}
	updateRetainedStyles(resetButton, retained)
	assert(retained.button.backgroundColor1 ~= nil and retained.button.borderImage.fileName == "")
	assert(retained.icon.color.x == 0)
	resetButton:change(settings.background, "vanilla")
	updateRetainedStyles(resetButton, retained)
	assert(retained.button.backgroundColor1 == nil, "Partial reset retained the button background")
	assert(retained.button.borderImage.fileName == "", "Partial reset discarded the requested None border")
	assert(retained.icon.color.x == 0)
	if isBulldozer then
		includeBulldozer = false
		resetButton:change(settings.includeBulldozer, false)
	else
		resetButton:change(settings.border, "vanilla")
		resetButton:change(settings.icon, "vanilla")
	end
	updateRetainedStyles(resetButton, retained)
	assert(
		retained.button == vanillaStyle and retained.icon == vanillaStyle,
		"Reset retained native button/icon styles"
	)
	assert(next(retained.button) == nil and next(retained.icon) == nil)
	assert(resetParams.meta.styleSheet == nil, "Reset mutated caller metadata")
	assert(resetButton.nativeNode.localKey == nil, "Reset changed the button's identity")
	if isBulldozer then
		includeBulldozer = true
		resetButton:change(settings.includeBulldozer, true)
		updateRetainedStyles(resetButton, retained)
		assert(retained.button.borderImage.fileName == "" and retained.icon.color.x == 0)
	end
end

local resetStrip = newContext()
selectedChoice = "black"
local retainedStrip = applyNativeStyle(nil, resetStrip:render(background, params))
assert(retainedStrip.backgroundColor.x == 0)
resetStrip:dispatch(settings.SECTION_ID, settings.strip.key, "vanilla")
retainedStrip = applyNativeStyle(retainedStrip, resetStrip:render(background, params))
assert(retainedStrip == vanillaStyle and next(retainedStrip) == nil, "Reset retained the native strip style")
print("Dark UI retained native-style reset test passed (buttons, icons, strip, partial reset, bulldozer exclusion)")

selectedBackground, selectedBorder, selectedIcon = "black", "none", "vanilla"
for _, parent in ipairs({ toolParent, toggleParent }) do
	local modParams = buttonParams()
	modParams.meta.styleSheet = foreignStyle
	modParams.value = parent == toggleParent and 0 or nil
	local modButton = newButton(parent, modParams, parent == toolParent)
	local merged = applyNativeStyle(nil, modButton:render())
	assertMergedStyle(merged, {
		backgroundColor1 = merged.backgroundColor1,
		borderColor = merged.borderColor,
		borderImage = merged.borderImage,
	})
	assert(merged.backgroundColor1.x == 0 and merged.borderColor.w == 0 and merged.borderImage.fileName == "")
	modButton:change(settings.background, "vanilla")
	merged = applyNativeStyle(merged, modButton:render())
	assertMergedStyle(merged, { borderColor = merged.borderColor, borderImage = merged.borderImage })
	assert(merged.backgroundColor1 == foreignStyle.backgroundColor1, "Partial reset lost the mod's background")
	modButton:change(settings.border, "vanilla")
	assert(applyNativeStyle(merged, modButton:render()) == foreignStyle, "Reset did not restore the original mod sheet")
end
print("Dark UI mod stylesheet compatibility test passed (13 native fields, source mutation, partial/full reset)")

local uniqueIconStyles = 0
for _ in pairs(cachedIconStyles) do
	uniqueIconStyles = uniqueIconStyles + 1
end
assert(
	styleAllocations == initialStyleCount + uniqueCombinedStyles + uniqueIconStyles + mergedStyleCount,
	"Combined style cache grew beyond distinct output styles"
)
assert(imageAllocations == 2, "Border images were recreated during colour changes")
print(
	"Dark UI inline border/icon React bridge test passed ("
		.. combinedCaseCount
		.. " combined cases; native rendering not tested)"
)
