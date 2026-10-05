local record Logger
	debug : function(string)
end

local record Logging
	new : function(string, boolean) : Logger
end

local debugLoggingEnabled = ug_require "apasz_dark_ui_1::/gui/main/logging_config.tl" as boolean
local logging = ug_require "apasz_dark_ui_1::/gui/main/logging.lua" as Logging
local logger = logging.new("Dark UI", debugLoggingEnabled)

local baseBrightness = 0.03
local accentBrightness = 0.15

local data : OverwriteGuiRes = {}

local function makeMonochrome(brightness : number) : GResColor
	return { brightness, brightness, brightness, 1.0 }
end

data.overwrite = function(_params : table)
	local colorRes = api.gui.genericRep.get(api.gui.genericRep.find("/gui/main/default_colors.gres"))
	local colors = colorRes.data as DefaultColors

	colors.BaseVeryDark = makeMonochrome(baseBrightness)
	colors.BaseDark = makeMonochrome(baseBrightness + 0.03)
	colors.BaseDarkMedium = makeMonochrome(baseBrightness + 0.06)
	colors.BaseMedium = makeMonochrome(baseBrightness + 0.09)
	colors.BaseLightMedium = makeMonochrome(baseBrightness + 0.12)
	colors.BaseLight = makeMonochrome(baseBrightness + 0.15)
	colors.BaseVeryLight = makeMonochrome(baseBrightness + 0.23)

	colors.AccentVeryDark = makeMonochrome(accentBrightness)
	colors.AccentDark = makeMonochrome(accentBrightness + 0.10)
	colors.AccentMedium = makeMonochrome(accentBrightness + 0.30)
	colors.AccentLight = makeMonochrome(accentBrightness + 0.50)
	colors.AccentVeryLight = makeMonochrome(accentBrightness + 0.60)

	colorRes:setData(colors as table)

	logger.debug(
		"Applied palette: baseBrightness="
		.. tostring(baseBrightness)
		.. ", accentBrightness=" .. tostring(accentBrightness)
	)
end

return data
