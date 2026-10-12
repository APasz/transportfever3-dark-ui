local ssu = require("::/gui/main/stylesheetutil.lua")
local guiUtil = require("apasz_dark_ui_1::/gui/main/dark_ui_gui_util.lua")
local settings = require("apasz_dark_ui_1::/gui/main/dark_ui_settings.lua")

local DEFAULT_COLORS_RESOURCE = "::/gui/main/default_colors.gres"
local GAME_BAR_ROOT = "#menu.gamebar!" .. settings.GAME_BAR_STYLE_CLASS
local BUTTON_SELECTOR = " !" .. settings.BUTTON_STYLE_CLASS
local GAME_BAR_INFO_DISPLAY = " R::GameBarMenuMiddle R::GameBarInfoDisplay "
local VANILLA_INFO_RECIPES = {
	"R::GameBarEarningsPlugin",
	"R::GameBarTransportedPlugin",
}

local function gray(value)
	local channel = value / 255
	return { channel, channel, channel, 1 }
end

function data()
	local result = {}
	local add = ssu.makeAdder(result)
	local defaultColors = guiUtil.getResource(DEFAULT_COLORS_RESOURCE)
	for _, colorName in ipairs({ "Invisible", "Negative", "Positive" }) do
		guiUtil.validateColor(defaultColors[colorName], DEFAULT_COLORS_RESOURCE .. "." .. colorName)
	end
	local borderImage = { fileName = "::/gui/main/design/disk_mini_contour.tga" }
	for _, option in ipairs(settings.buttonColors) do
		for _, rule in ipairs(settings.colorRules(option)) do
			local style = { [option.property] = gray(rule.gray) }
			if option == settings.border then
				style.borderImage = borderImage
			end
			add(GAME_BAR_ROOT .. "!" .. rule.className .. BUTTON_SELECTOR .. rule.state.selector .. option.child, style)
		end
	end
	add(GAME_BAR_ROOT .. "!" .. settings.styleClass(settings.border, settings.NONE_CHOICE_ID) .. BUTTON_SELECTOR, {
		borderColor = defaultColors.Invisible,
		borderImage = { fileName = "" },
	})
	for _, choice in ipairs(settings.strip.choices) do
		if choice.gray ~= nil then
			add(
				GAME_BAR_ROOT
					.. "!"
					.. settings.styleClass(settings.strip, choice.id)
					.. " R::GameBarBackground !bottom",
				{ backgroundColor = gray(choice.gray) }
			)
		end
	end
	for _, choice in ipairs(settings.text.choices) do
		if choice.gray ~= nil then
			local root = GAME_BAR_ROOT .. "!" .. settings.styleClass(settings.text, choice.id) .. GAME_BAR_INFO_DISPLAY
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
