local uiTweaks = {
	API_VERSION = 1,
	RESOURCE_TYPE = "ui-tweaks-settings",
}

local SETTINGS_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/settings.lua"
local SETTINGS_RESOURCE = "apasz_ui_tweaks::/gui/ui_tweaks/ui_tweaks_settings.res"
local GAME_BAR_MODULES = {
	{
		name = "recipeComposition",
		path = "apasz_ui_tweaks::/gui/ui_tweaks/recipe_composition.lua",
		functions = { "interceptActive", "wrapActive", "render" },
	},
	{
		name = "reactSettings",
		path = "apasz_ui_tweaks::/gui/ui_tweaks/react_settings.lua",
		functions = { "useValue" },
	},
	{
		name = "storage",
		path = "apasz_ui_tweaks::/gui/ui_tweaks/settings_storage.lua",
		functions = { "read", "saveSections" },
	},
}
local warnedIncompatible = false

local function disableGameBar(reason)
	if not warnedIncompatible then
		log.warning(
			"[Dark UI] Game bar customisation disabled: "
				.. reason
				.. ". Update or reinstall UI Tweaks and Dark UI together."
		)
		warnedIncompatible = true
	end
	return nil
end

function uiTweaks.isAvailable()
	local resourceId = api.res.genericRep.find(SETTINGS_RESOURCE)
	assert(type(resourceId) == "number", "Dark UI received an invalid UI Tweaks resource id")
	return resourceId >= 0
end

function uiTweaks.requireSettings()
	if not uiTweaks.isAvailable() then
		return nil
	end
	local settings = require(SETTINGS_MODULE)
	assert(type(settings) == "table", "Dark UI received an invalid UI Tweaks settings module")
	assert(
		settings.API_VERSION == uiTweaks.API_VERSION,
		"Dark UI requires UI Tweaks settings API version " .. uiTweaks.API_VERSION
	)
	assert(
		settings.RESOURCE_TYPE == uiTweaks.RESOURCE_TYPE,
		"Dark UI received an incompatible UI Tweaks settings resource type"
	)
	return settings
end

function uiTweaks.requireGameBarModules()
	if uiTweaks.requireSettings() == nil then
		return nil
	end

	local modules = {}
	for _, dependency in ipairs(GAME_BAR_MODULES) do
		-- A failed require leaves the engine's module path stack unbalanced.
		local chunk, loadError = resolveutil.loadfile(dependency.path)
		if chunk == nil then
			if loadError == "Could not find file " .. dependency.path then
				return disableGameBar("UI Tweaks is missing " .. dependency.path)
			end
			error("Dark UI could not load " .. dependency.path .. ": " .. tostring(loadError))
		end

		local module = require(dependency.path)
		assert(type(module) == "table", "Dark UI received an invalid UI Tweaks module: " .. dependency.path)
		for _, name in ipairs(dependency.functions) do
			if module[name] == nil then
				return disableGameBar("UI Tweaks does not provide " .. dependency.path .. ": " .. name)
			end
			assert(
				type(module[name]) == "function",
				"Dark UI received an invalid UI Tweaks function: " .. dependency.path .. ": " .. name
			)
		end
		modules[dependency.name] = module
	end
	return modules
end

return uiTweaks
