local ssu = require("::/gui/main/stylesheetutil.lua")
local guiUtil = require("apasz_dark_ui_1::/gui/main/dark_ui_gui_util.lua")
local settings = require("apasz_dark_ui_1::/gui/main/dark_ui_settings.lua")

local DEFAULT_COLORS_RESOURCE = "::/gui/main/default_colors.gres"
local GAME_BAR_ROOT = "#menu.gamebar!" .. settings.GAME_BAR_STYLE_CLASS
local GAME_BAR_INFO_DISPLAY = " R::GameBarMenuMiddle R::GameBarInfoDisplay "
local VANILLA_INFO_RECIPES = {
	"R::GameBarEarningsPlugin",
	"R::GameBarTransportedPlugin",
}

local gray = guiUtil.grayColor

function data()
	local result = {}
	local add = ssu.makeAdder(result)
	local defaultColors = guiUtil.getResource(DEFAULT_COLORS_RESOURCE)
	for _, colorName in ipairs({ "Negative", "Positive" }) do
		guiUtil.validateColor(defaultColors[colorName], DEFAULT_COLORS_RESOURCE .. "." .. colorName)
	end
	for _, choice in ipairs(settings.text.choices) do
		if choice.gray ~= nil then
			local root = GAME_BAR_ROOT .. "!" .. choice.styleClass .. GAME_BAR_INFO_DISPLAY
			local textSelectors = {}
			for _, recipe in ipairs(VANILLA_INFO_RECIPES) do
				textSelectors[#textSelectors + 1] = root .. recipe .. " TextView"
			end
			add(table.concat(textSelectors, ", "), { color = gray(choice.gray) })
		end
	end
	local earningsText = GAME_BAR_ROOT
		.. "!"
		.. settings.text.overrideClass
		.. GAME_BAR_INFO_DISPLAY
		.. "R::GameBarEarningsPlugin TextView"
	add(earningsText .. "!positive", { color = defaultColors.Positive })
	add(earningsText .. "!negative", { color = defaultColors.Negative })
	return result
end
