local UI_TWEAKS_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/settings.lua"
local REACT_SETTINGS_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/react_settings.lua"
local RECIPE_COMPOSITION_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/recipe_composition.lua"
local UI_TWEAKS_COMPATIBILITY_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/compatibility.lua"
local DARK_UI_MODULE = "apasz_dark_ui_1::/gui/main/dark_ui_settings.lua"
local UI_TWEAKS_INTEGRATION_MODULE = "apasz_dark_ui_1::/gui/main/dark_ui_ui_tweaks.lua"
local UI_TWEAKS_RESOURCE = "apasz_ui_tweaks::/gui/ui_tweaks/ui_tweaks_settings.res"
local PALETTE_MODULE = "apasz_dark_ui_1::/gui/main/dark_ui_palette.lua"
local STORAGE_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/settings_storage.lua"

local centralValues = {
	game_bar_background_color = "vanilla",
	game_bar_border_color = "vanilla",
	game_bar_icon_color = "vanilla",
	game_bar_strip_color = "vanilla",
	game_bar_text_color = "vanilla",
	game_bar_state_contrast = "standard",
	game_bar_include_bulldozer = false,
}
local uiTweaksSettings = {
	API_VERSION = 1,
	RESOURCE_TYPE = "ui-tweaks-settings",
	CHANGED_EVENT = "uiTweaksSettingsChanged",
	get = function(sectionId, settingKey)
		assert(sectionId == "apasz.dark_ui")
		local value = centralValues[settingKey]
		assert(value ~= nil, "Missing test setting " .. tostring(settingKey))
		return value
	end,
}
package.loaded[UI_TWEAKS_MODULE] = uiTweaksSettings
package.loaded[UI_TWEAKS_INTEGRATION_MODULE] = dofile("content/gui/main/dark_ui_ui_tweaks.lua")
package.loaded[PALETTE_MODULE] = dofile("content/gui/main/dark_ui_palette.lua")

-- Upload validation loads scripts before the runtime resource API is available.
api = { gui = {} }
ug_require = function(path)
	error("Dark UI loaded a runtime dependency during validation: " .. path)
end
dofile("content/gui/main/dark_ui_game_bar_theme.script.lua")
local validationThemeConfig = data()
assert(type(validationThemeConfig.install) == "function")

local settings = dofile("content/gui/main/dark_ui_settings.lua")
package.loaded[DARK_UI_MODULE] = settings

local uiTweaksAvailable = true
local appConfig = {
	mainMenuState = {
		apasz_ui_tweaks_settings = {
			schemaVersion = 1,
			sections = {
				[settings.SECTION_ID] = {
					game_bar_background_color = "gray_50",
					game_bar_bulldozer_style = "background_only",
				},
				["another.mod"] = { enabled = true },
			},
		},
		unrelated = "preserved",
	},
}
local originalConfig = appConfig
local configWrites = 0
api = {
	gui = {},
	util = {
		getAppConfig = function()
			return appConfig
		end,
		setAppConfig = function(config, restart)
			assert(restart == false)
			appConfig = config
			configWrites = configWrites + 1
		end,
	},
	type = {
		AppConfig = {
			new = function(config)
				local copy = {}
				for key, value in pairs(config) do
					copy[key] = value
				end
				return copy
			end,
		},
	},
	res = {
		genericRep = {
			find = function(path)
				assert(path == UI_TWEAKS_RESOURCE)
				return uiTweaksAvailable and 201 or -1
			end,
		},
	},
}

local GAME_BAR_RECIPE_ID = 101
local EXISTING_GAME_BAR_RECIPE_ID = 102
local TOOL_BUTTON_RECIPE_ID = 103
local TOGGLE_BUTTON_RECIPE_ID = 104
local REGISTERED_BUTTON_RECIPE_ID = 105
local builtin = { ToolButton = function() end, ToggleButton = function() end }
local registeredButtonReplacement = function() end
local registeredButtonCalls = 0
local currentRecipe = "GameBar"
local existingButtonCalls = 0
local existingToolButton = function(...)
	existingButtonCalls = existingButtonCalls + 1
	return table.pack(...)
end

local originalGameBar = function() end
local existingGameBarCalls = 0
local originalGameBarCalls = 0
local existingGameBar = function(params)
	existingGameBarCalls = existingGameBarCalls + 1
	return params
end
local expectedWrappedRecipe = existingGameBar
local states = {}
local stateCursor = 0
local eventHandlers = {}
local classes

local function makeState(initial)
	local state = { value = initial }
	function state:old()
		return self.value
	end
	function state:set(value)
		self.value = value
	end
	return state
end

local react = {
	GetRecipeId = function(recipe)
		if recipe == registeredButtonReplacement then
			return REGISTERED_BUTTON_RECIPE_ID
		end
		if recipe == builtin.ToolButton then
			return TOOL_BUTTON_RECIPE_ID
		end
		if recipe == builtin.ToggleButton then
			return TOGGLE_BUTTON_RECIPE_ID
		end
		if recipe == originalGameBar then
			return GAME_BAR_RECIPE_ID
		end
		if recipe == existingGameBar then
			return EXISTING_GAME_BAR_RECIPE_ID
		end
		return nil
	end,
	getCurrentRecipeName = function()
		return currentRecipe
	end,
	RegisterWrapperRecipe = function(_, wrappedRecipe, recipe)
		assert(wrappedRecipe == expectedWrappedRecipe)
		return recipe
	end,
	useStateLazy = function(initializer)
		stateCursor = stateCursor + 1
		if states[stateCursor] == nil then
			states[stateCursor] = makeState(initializer())
		end
		return states[stateCursor]
	end,
	onEvent = function(name, handler)
		assert(name == uiTweaksSettings.CHANGED_EVENT)
		eventHandlers[#eventHandlers + 1] = handler
	end,
	setStyleClasses = function(...)
		classes = { ... }
	end,
	CallOriginalRecipe = function(recipe, params)
		assert(recipe == originalGameBar)
		originalGameBarCalls = originalGameBarCalls + 1
		return params
	end,
}
_react = {
	originalRecipeFn = {
		[TOOL_BUTTON_RECIPE_ID] = function(...)
			return table.pack(...)
		end,
		[TOGGLE_BUTTON_RECIPE_ID] = function(...)
			return table.pack(...)
		end,
		[REGISTERED_BUTTON_RECIPE_ID] = function(...)
			registeredButtonCalls = registeredButtonCalls + 1
			return table.pack(...)
		end,
	},
	recipeReplace = {
		[GAME_BAR_RECIPE_ID] = existingGameBar,
		[TOOL_BUTTON_RECIPE_ID] = existingToolButton,
	},
}
ug_require = function(path)
	if path == "::/gui/main/react.lua" then
		return react
	end
	if path == "::/gui/main/builtin.lua" then
		return builtin
	end
	if path == "::/gui/game_bar/game_bar.tl" then
		return { GameBar = originalGameBar }
	end
	error("Unexpected require: " .. path)
end
package.loaded[UI_TWEAKS_COMPATIBILITY_MODULE] = {
	logWorkaround = function() end,
}
package.loaded[REACT_SETTINGS_MODULE] = dofile("../ui_tweaks/content/gui/ui_tweaks/react_settings.lua")
package.loaded[RECIPE_COMPOSITION_MODULE] = dofile("../ui_tweaks/content/gui/ui_tweaks/recipe_composition.lua")
package.loaded[STORAGE_MODULE] = dofile("../ui_tweaks/content/gui/ui_tweaks/settings_storage.lua")

local function resetHooks()
	states = {}
	stateCursor = 0
	eventHandlers = {}
end

local function render(recipe, ...)
	stateCursor = 0
	eventHandlers = {}
	return recipe(...)
end

local function dispatch(change)
	for _, handler in ipairs(eventHandlers) do
		handler(uiTweaksSettings.CHANGED_EVENT, change)
	end
end

local function assertCurrentClasses(scopeClass)
	local classSet = {}
	for _, className in ipairs(classes) do
		assert(not classSet[className], "Dark UI produced duplicate style classes")
		classSet[className] = true
	end
	assert(#eventHandlers == #settings.options)
	assert(classes[1] == (scopeClass or settings.GAME_BAR_STYLE_CLASS))
	local selected = {}
	for _, option in ipairs(settings.options) do
		selected[option.stateKey] = centralValues[option.key]
	end
	local expected = settings.styleClasses(selected, scopeClass)
	assert(#classes == #expected)
	for _, className in ipairs(expected) do
		assert(classSet[className])
	end
end

local function installTheme(themeConfig)
	if themeConfig == nil then
		dofile("content/gui/main/dark_ui_game_bar_theme.script.lua")
		themeConfig = data()
	end
	_react.recipeReplace[TOOL_BUTTON_RECIPE_ID] = existingToolButton
	_react.recipeReplace[TOGGLE_BUTTON_RECIPE_ID] = nil
	local themedGameBar
	themeConfig.install({
		ReplaceRecipe = function(original, replacement)
			assert(original == originalGameBar)
			themedGameBar = replacement
		end,
	})
	return themeConfig, assert(themedGameBar)
end

resetHooks()
local themeConfig, themedGameBar = installTheme(validationThemeConfig)
assert(configWrites == 1)
local migrated = appConfig.mainMenuState.apasz_ui_tweaks_settings.sections[settings.SECTION_ID]
assert(migrated.game_bar_background_color == "dark_gray" and migrated.game_bar_include_bulldozer == true)
assert(appConfig.mainMenuState.unrelated == "preserved")
assert(
	appConfig.mainMenuState.apasz_ui_tweaks_settings.sections["another.mod"]
		== originalConfig.mainMenuState.apasz_ui_tweaks_settings.sections["another.mod"]
)
assert(
	originalConfig.mainMenuState.apasz_ui_tweaks_settings.sections[settings.SECTION_ID].game_bar_background_color
		== "gray_50"
)
local gameBarParams = { test = true, customModField = {} }
assert(render(themedGameBar, gameBarParams) == gameBarParams, "Dark UI did not preserve the GameBar parameters")
assert(existingGameBarCalls == 1)
assert(originalGameBarCalls == 0)
assertCurrentClasses()

dispatch({
	sectionId = "another.mod",
	settingKey = "game_bar_background_color",
	value = "dark_gray",
})
render(themedGameBar, { test = true })
assertCurrentClasses()

centralValues.game_bar_background_color = "black"
dispatch({
	sectionId = settings.SECTION_ID,
	settingKey = "game_bar_background_color",
	value = "black",
})
render(themedGameBar, { test = true })
assertCurrentClasses()
assert(states[1]:old() == "black", "Dark UI did not apply a live background change")

centralValues.game_bar_background_color = "vanilla"
dispatch({
	sectionId = settings.SECTION_ID,
	settingKey = "game_bar_background_color",
	value = "vanilla",
})
render(themedGameBar, { test = true })
assertCurrentClasses()
assert(states[1]:old() == "vanilla", "Dark UI did not clear a live background override")

local configuredValues = {
	game_bar_background_color = "dark_gray",
	game_bar_border_color = "gray",
	game_bar_icon_color = "white",
	game_bar_strip_color = "black",
	game_bar_text_color = "light_gray",
	game_bar_state_contrast = "subtle",
	game_bar_include_bulldozer = true,
}
for _, option in ipairs(settings.options) do
	centralValues[option.key] = configuredValues[option.key]
end
centralValues.game_bar_button_shadow = "strong"
resetHooks()
render(themedGameBar, { test = true })
assertCurrentClasses()

dispatch({
	sectionId = settings.SECTION_ID,
	settingKey = "game_bar_button_shadow",
	value = "off",
})
render(themedGameBar, { test = true })
assertCurrentClasses()

local function hasButtonClass(params)
	local count = 0
	for className in (params.meta and params.meta.class or ""):gmatch("[^,%s]+") do
		if className == settings.BUTTON_STYLE_CLASS then
			count = count + 1
		end
	end
	assert(count <= 1, "Dark UI duplicated its button class")
	return count == 1
end

local toolButton = assert(_react.recipeReplace[TOOL_BUTTON_RECIPE_ID])
local toggleButton = assert(_react.recipeReplace[TOGGLE_BUTTON_RECIPE_ID])
local onClick = function() end
local reference = { is_react_ref_info = true, data = {} }
local params = {
	meta = { class = "third-party,unchecked", enabled = false, tooltip = "Custom tooltip" },
	onClick = onClick,
	customModField = {},
}
for _, parent in ipairs({ "ManagerToolButton", "ConstructionToolButton", "MapEditorToolButton" }) do
	currentRecipe = parent
	local previousCalls = existingButtonCalls
	local result = render(toolButton, reference, params)
	assert(existingButtonCalls == previousCalls + 1, "Dark UI bypassed or repeated an existing button replacement")
	assert(result.n == 2 and result[1] == reference)
	local configured = result[2]
	assert(configured ~= params and configured.meta ~= params.meta)
	assert(hasButtonClass(configured))
	assert(configured.meta.class == "third-party,unchecked," .. settings.BUTTON_STYLE_CLASS)
	assert(configured.meta.enabled == false and configured.meta.tooltip == params.meta.tooltip)
	assert(configured.onClick == onClick and configured.customModField == params.customModField)
	assert(params.meta.class == "third-party,unchecked", "Dark UI mutated incoming button classes")
end
currentRecipe = "AnotherModRecipe"
assert(render(toolButton, params)[1] == params, "Dark UI labelled an unrelated tool button")
assert(render(toggleButton, params)[1] == params, "Dark UI labelled an unrelated toggle button")
assert(render(toolButton, nil).n == 1)
currentRecipe = "NodeEditorButton"
assert(hasButtonClass(render(toggleButton, { value = 1 })[1]))
currentRecipe = "GameBar"
local extra = { meta = { class = "extra,third-party" }, value = 0 }
assert(hasButtonClass(render(toggleButton, reference, extra)[2]))
assert(extra.meta.class == "extra,third-party")
local style = { is_react_style_info = true, data = { class = "extra,style-argument" } }
local styleParams = { value = 1 }
for _, arguments in ipairs({ { style, reference, styleParams }, { reference, style, styleParams } }) do
	local result = render(toggleButton, table.unpack(arguments))
	assert(result[1] == arguments[1] and result[2] == arguments[2])
	assert(result[3].meta.class == "extra,style-argument," .. settings.BUTTON_STYLE_CLASS)
	assert(styleParams.meta == nil and style.data.class == "extra,style-argument")
end
local explicitMeta = { meta = { class = "extra,metadata" } }
assert(render(toggleButton, style, explicitMeta)[2].meta.class == "extra,metadata," .. settings.BUTTON_STYLE_CLASS)
local alreadyTagged = { meta = { class = "extra," .. settings.BUTTON_STYLE_CLASS } }
assert(render(toggleButton, alreadyTagged)[1] == alreadyTagged)

for _, id in ipairs({ "menu.bulldozer", "menu.moduleBulldozer" }) do
	currentRecipe = "ConstructionToolButton"
	centralValues.game_bar_include_bulldozer = false
	resetHooks()
	local bulldozer = { meta = { id = id, class = "third-party-bulldozer", enabled = false } }
	assert(render(toolButton, reference, bulldozer)[2] == bulldozer, "Excluded bulldozer styling was changed")
	assert(#eventHandlers == 1)
	centralValues.game_bar_include_bulldozer = true
	dispatch({ sectionId = settings.SECTION_ID, settingKey = settings.includeBulldozer.key, value = true })
	assert(hasButtonClass(render(toolButton, reference, bulldozer)[2]), "Live bulldozer inclusion was ignored")
	centralValues.game_bar_include_bulldozer = false
	dispatch({ sectionId = settings.SECTION_ID, settingKey = settings.includeBulldozer.key, value = false })
	assert(render(toolButton, reference, bulldozer)[2] == bulldozer, "Live bulldozer exclusion was ignored")
end
centralValues.game_bar_include_bulldozer = true
currentRecipe = "GameBar"
resetHooks()
render(themedGameBar, { test = true })
assertCurrentClasses()

themeConfig.install({
	ReplaceRecipe = function()
		error("Dark UI installed its GameBar replacement twice")
	end,
})

_react.recipeReplace[TOGGLE_BUTTON_RECIPE_ID] = registeredButtonReplacement
dofile("content/gui/main/dark_ui_game_bar_theme.script.lua")
data().install({ ReplaceRecipe = function() end })
currentRecipe = "NodeEditorButton"
local registeredResult = render(_react.recipeReplace[TOGGLE_BUTTON_RECIPE_ID], params)
assert(
	registeredButtonCalls == 1 and hasButtonClass(registeredResult[1]),
	"Dark UI bypassed a registered button replacement"
)
assert(registeredResult[1].onClick == onClick)
currentRecipe = "GameBar"

local previousExistingCalls = existingGameBarCalls
_react.recipeReplace[GAME_BAR_RECIPE_ID] = nil
expectedWrappedRecipe = originalGameBar
resetHooks()
dofile("content/gui/main/dark_ui_game_bar_theme.script.lua")
local originalThemeConfig = data()
assert(not pcall(originalThemeConfig.install, {}))
local originalThemedGameBar
originalThemeConfig.install({
	ReplaceRecipe = function(original, replacement)
		assert(original == originalGameBar)
		originalThemedGameBar = replacement
	end,
})
render(assert(originalThemedGameBar), { test = true })
assert(existingGameBarCalls == previousExistingCalls)
assert(originalGameBarCalls == 1)

local unregisteredGameBarCalls = 0
local unregisteredGameBar = function(params)
	unregisteredGameBarCalls = unregisteredGameBarCalls + 1
	return params
end
_react.recipeReplace[GAME_BAR_RECIPE_ID] = unregisteredGameBar
expectedWrappedRecipe = originalGameBar
resetHooks()
local _, unregisteredThemedGameBar = installTheme()
render(unregisteredThemedGameBar, { test = true })
assert(unregisteredGameBarCalls == 1)
assert(originalGameBarCalls == 1)
assert(configWrites == 1, "Dark UI rewrote already migrated settings")

dofile("content/gui/main/dark_ui_game_bar_theme.res.lua")
assert(data().data.order == 1000000)

uiTweaksAvailable = false
dofile("content/gui/main/dark_ui_game_bar_theme.script.lua")
local optionalThemeConfig = data()
local optionalReplacementCalled = false
optionalThemeConfig.install({
	ReplaceRecipe = function()
		optionalReplacementCalled = true
	end,
})
assert(not optionalReplacementCalled, "Dark UI installed its UIT theme without UI Tweaks")

uiTweaksAvailable = true
uiTweaksSettings.API_VERSION = 2
dofile("content/gui/main/dark_ui_game_bar_theme.script.lua")
local incompatibleSettingsOk, incompatibleSettingsError = pcall(data().install, {})
assert(not incompatibleSettingsOk)
assert(incompatibleSettingsError:find("Dark UI requires UI Tweaks settings API version 1", 1, true))
uiTweaksSettings.API_VERSION = 1

local modFile = assert(io.open("mod.json", "r"))
local modJson = modFile:read("*a")
modFile:close()
assert(modJson:find('"dependencies": null', 1, true), "Dark UI unexpectedly declares a dependency")
assert(not modJson:find('"modId": "apasz_ui_tweaks"', 1, true), "Dark UI declares UI Tweaks as a dependency")
for _, incompatibleTheme in ipairs({ "clear_ui_1", "Lo2k_Blue_UI", "Lo2k_Brown_UI", "Lo2k_Lavander_UI" }) do
	assert(
		modJson:find('"modId": "' .. incompatibleTheme .. '"', 1, true),
		"Dark UI does not declare its palette conflict with " .. incompatibleTheme
	)
end

print("Dark UI settings UI test passed")
