local record Logger
	debug : function(string)
end

local record Logging
	new : function(string, boolean) : Logger
end

local record Palette
	baseBrightness : number
	accentBrightness : number
	darkGray : number
end

local debugLoggingEnabled = ug_require "apasz_dark_ui_1::/gui/main/logging_config.tl" as boolean
local logging = ug_require "apasz_dark_ui_1::/gui/main/logging.lua" as Logging
local logger = logging.new("Dark UI", debugLoggingEnabled)

local palette = ug_require "apasz_dark_ui_1::/gui/main/dark_ui_palette.lua" as Palette
local baseBrightness = palette.baseBrightness
local accentBrightness = palette.accentBrightness
local DEFAULT_COLORS_RESOURCE = "::/gui/main/default_colors.gres"

local data : OverwriteGuiRes = {}

local function makeMonochrome(brightness : number) : GResColor
	return { brightness, brightness, brightness, 1.0 }
end

data.overwrite = function(_params : table)
	local resourceId = api.gui.genericRep.find(DEFAULT_COLORS_RESOURCE)
	assert(resourceId >= 0, "Dark UI could not find the game's default colour palette")
	local colorRes = api.gui.genericRep.get(resourceId)
	assert(colorRes ~= nil and type(colorRes.data) == "table", "Dark UI received an invalid default colour palette")
	local colors = colorRes.data as DefaultColors

	colors.BaseVeryDark = makeMonochrome(baseBrightness)
	colors.BaseDark = makeMonochrome(baseBrightness + 0.03)
	colors.BaseDarkMedium = makeMonochrome(palette.darkGray)
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
