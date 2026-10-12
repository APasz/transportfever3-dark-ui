local uiTweaks = {
	API_VERSION = 1,
	RESOURCE_TYPE = "ui-tweaks-settings",
}

local SETTINGS_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/settings.lua"
local SETTINGS_RESOURCE = "apasz_ui_tweaks::/gui/ui_tweaks/ui_tweaks_settings.res"

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

return uiTweaks
