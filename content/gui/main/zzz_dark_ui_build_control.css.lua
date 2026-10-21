local ssu = require("::/gui/main/stylesheetutil.lua")
local colorUtil = require("::/gui/main/color_util.tl")
local guiUtil = require("apasz_dark_ui_1::/gui/main/dark_ui_gui_util.lua")

local DEFAULT_COLORS_RESOURCE = "::/gui/main/default_colors.gres"
local TRANSPARENCY_RESOURCE = "::/gui/main/transparency.gres"

function data()
	local result = {}
	local add = ssu.makeAdder(result)
	local defaultColors = guiUtil.getResource(DEFAULT_COLORS_RESOURCE)
	local transparency = guiUtil.getResource(TRANSPARENCY_RESOURCE)
	local background = guiUtil.validateColor(defaultColors.AccentDark, DEFAULT_COLORS_RESOURCE .. ".AccentDark")
	local alpha = guiUtil.validateAlpha(transparency.Low, TRANSPARENCY_RESOURCE .. ".Low")

	add("BuildControlComp::SpeedSlopeLabel", {
		backgroundColor1 = colorUtil.withTransparencyRaw(background, alpha),
	})
	return result
end
