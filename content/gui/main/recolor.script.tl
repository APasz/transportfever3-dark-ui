local record ColorInternal
	makeFromHSVa : function(number, number, number) : GResColor
end

local internal = ug_require "::/gui/main/color_internal.lua" as ColorInternal

-- Enable temporarily when diagnosing
local debugLoggingEnabled = false

local monochromeHue = 0
local monochromeSaturation = 0.0
local baseBrightness = 0.03
local accentBrightness = 0.15

local data : OverwriteGuiRes = {}

local function makeMonochrome(brightness : number) : GResColor
	return internal.makeFromHSVa(monochromeHue, monochromeSaturation, brightness)
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

	if debugLoggingEnabled then
		debugPrint(
			"[Dark UI] applied palette: baseBrightness="
			.. tostring(baseBrightness)
			.. ", accentBrightness=" .. tostring(accentBrightness)
		)
	end
end

return data
