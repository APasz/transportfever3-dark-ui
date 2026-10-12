local UI_TWEAKS_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/settings.lua"
local REACT_SETTINGS_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/react_settings.lua"
local RECIPE_COMPOSITION_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/recipe_composition.lua"
local UI_TWEAKS_COMPATIBILITY_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/compatibility.lua"
local DARK_UI_MODULE = "apasz_dark_ui_1::/gui/main/dark_ui_settings.lua"
local UI_TWEAKS_INTEGRATION_MODULE = "apasz_dark_ui_1::/gui/main/dark_ui_ui_tweaks.lua"
local UI_TWEAKS_RESOURCE = "apasz_ui_tweaks::/gui/ui_tweaks/ui_tweaks_settings.res"

local centralValues = {
	game_bar_background_color = "vanilla",
	game_bar_border_color = "vanilla",
	game_bar_icon_color = "vanilla",
	game_bar_strip_color = "vanilla",
	game_bar_text_color = "vanilla",
	game_bar_state_contrast = "standard",
	game_bar_bulldozer_style = "vanilla",
}
local uiTweaksSettings = {
	API_VERSION = 1,
	RESOURCE_TYPE = "ui-tweaks-settings",
	CHANGED_EVENT = "uiTweaksSettingsChanged",
	get = function(sectionId, settingKey)
		assert(sectionId == "apasz.dark_ui")
		return assert(centralValues[settingKey], "Missing test setting " .. tostring(settingKey))
	end,
}
package.loaded[UI_TWEAKS_MODULE] = uiTweaksSettings
package.loaded[UI_TWEAKS_INTEGRATION_MODULE] = dofile("content/gui/main/dark_ui_ui_tweaks.lua")

local settings = dofile("content/gui/main/dark_ui_settings.lua")
package.loaded[DARK_UI_MODULE] = settings

local uiTweaksAvailable = true
api = {
	gui = {},
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
		if recipe == originalGameBar then
			return GAME_BAR_RECIPE_ID
		end
		if recipe == existingGameBar then
			return EXISTING_GAME_BAR_RECIPE_ID
		end
		return nil
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
	originalRecipeFn = {},
	recipeReplace = {
		[GAME_BAR_RECIPE_ID] = existingGameBar,
	},
}
ug_require = function(path)
	if path == "::/gui/main/react.lua" then
		return react
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
	local expectedCount = #settings.options + 1
	assert(#eventHandlers == #settings.options)
	assert(classes[1] == (scopeClass or settings.GAME_BAR_STYLE_CLASS))
	for _, option in ipairs(settings.options) do
		local choiceId = centralValues[option.key]
		assert(classSet[settings.styleClass(option, choiceId)])
		if option.overrideClass then
			local overridden = choiceId ~= settings.VANILLA_CHOICE_ID
			assert((classSet[option.overrideClass] == true) == overridden)
			if overridden then
				expectedCount = expectedCount + 1
			end
		end
	end
	assert(#classes == expectedCount)
end

local function installTheme()
	dofile("content/gui/main/dark_ui_game_bar_theme.script.lua")
	local themedGameBar
	local themeConfig = data()
	themeConfig.install({
		ReplaceRecipe = function(original, replacement)
			assert(original == originalGameBar)
			themedGameBar = replacement
		end,
	})
	return themeConfig, assert(themedGameBar)
end

resetHooks()
local themeConfig, themedGameBar = installTheme()
local gameBarParams = { test = true, customModField = {} }
assert(render(themedGameBar, gameBarParams) == gameBarParams, "Dark UI did not preserve the GameBar parameters")
assert(existingGameBarCalls == 1)
assert(originalGameBarCalls == 0)
assertCurrentClasses()

dispatch({
	sectionId = "another.mod",
	settingKey = "game_bar_background_color",
	value = "gray_50",
})
render(themedGameBar, { test = true })
assertCurrentClasses()

centralValues.game_bar_background_color = "gray_0"
dispatch({
	sectionId = settings.SECTION_ID,
	settingKey = "game_bar_background_color",
	value = "gray_0",
})
render(themedGameBar, { test = true })
assertCurrentClasses()
assert(states[1]:old() == "gray_0", "Dark UI did not apply a live background change")

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
	game_bar_background_color = "gray_50",
	game_bar_border_color = "gray_50",
	game_bar_icon_color = "gray_225",
	game_bar_strip_color = "gray_25",
	game_bar_text_color = "gray_200",
	game_bar_state_contrast = "subtle",
	game_bar_bulldozer_style = "included",
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

themeConfig.install({
	ReplaceRecipe = function()
		error("Dark UI installed its GameBar replacement twice")
	end,
})

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
assert(not pcall(dofile, "content/gui/main/dark_ui_game_bar_theme.script.lua"))
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
