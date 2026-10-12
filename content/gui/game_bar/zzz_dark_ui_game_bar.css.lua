local ssu = require("::/gui/main/stylesheetutil.lua")
local colorUtil = require("::/gui/main/color_util.tl")
local guiUtil = require("apasz_dark_ui_1::/gui/main/dark_ui_gui_util.lua")
local settings = require("apasz_dark_ui_1::/gui/main/dark_ui_settings.lua")

local DEFAULT_COLORS_RESOURCE = "::/gui/main/default_colors.gres"
local CONSTRUCTION_COLORS_RESOURCE = "::/gui/construction/construction.gres"
local GAME_BAR_ROOT = "#menu.gamebar!" .. settings.GAME_BAR_STYLE_CLASS
local GAME_BAR_BUTTON_SCOPE = "R::GameBarMenuMiddle !upper-layout"
local GAME_BAR_INFO_DISPLAY = " R::GameBarMenuMiddle R::GameBarInfoDisplay "
local VANILLA_INFO_RECIPES = {
	"R::GameBarEarningsPlugin",
	"R::GameBarTransportedPlugin",
}

local function gray(value)
	value = math.max(0, math.min(255, value))
	local channel = value / 255
	return { channel, channel, channel, 1 }
end

local colorStates = {
	{ id = "normal" },
	{ id = "selected", offsetKey = "selectedOffset" },
	{ id = "idleHover", offsetKey = "hoverOffset" },
	{ id = "selectedHover", offsetKey = "selectedHoverOffset" },
	{ id = "disabled", scaleKey = "disabledScale" },
}

local function stateGray(base, state, contrast)
	if state.scaleKey then
		return base * assert(contrast[state.scaleKey], "Missing state contrast scale " .. state.scaleKey)
	end
	if state.offsetKey then
		return base + assert(contrast[state.offsetKey], "Missing state contrast offset " .. state.offsetKey)
	end
	return base
end

local function button(root, selector)
	return {
		root = root,
		selector = selector,
		any = "",
		normal = "!unchecked",
		selected = "!checked",
		idleHover = "!unchecked:hover",
		selectedHover = "!checked:hover",
		idleActive = "!unchecked:active",
		selectedActive = "!checked:active",
		disabled = ":disabled",
	}
end

local buttons = {
	button(GAME_BAR_ROOT, GAME_BAR_BUTTON_SCOPE .. " R::ManagerToolButton ToolButton"),
	button(GAME_BAR_ROOT, GAME_BAR_BUTTON_SCOPE .. " R::ConstructionToolButton ToolButton"),
	button(GAME_BAR_ROOT, GAME_BAR_BUTTON_SCOPE .. " R::MapEditorToolButton ToolButton"),
	button(GAME_BAR_ROOT, GAME_BAR_BUTTON_SCOPE .. " R::NodeEditorButton ToggleButton"),
	button(GAME_BAR_ROOT, "ToggleButton!extra"),
}

local bulldozerButtons = {
	button(GAME_BAR_ROOT, GAME_BAR_BUTTON_SCOPE .. " #menu.bulldozer"),
	button(GAME_BAR_ROOT, GAME_BAR_BUTTON_SCOPE .. " #menu.moduleBulldozer"),
}

local FALLBACK_BULLDOZER_COLORS = {
	Bulldozer = { 1, 215 / 255, 0, 1 },
}
local REQUIRED_DEFAULT_COLORS = {
	"AccentVeryDark",
	"Invisible",
	"Negative",
	"NeutralDark",
	"NeutralMedium",
	"Positive",
}

local function getBulldozerColors()
	local colors = guiUtil.findResource(CONSTRUCTION_COLORS_RESOURCE)
	if colors == nil then
		return FALLBACK_BULLDOZER_COLORS
	end
	guiUtil.validateColor(colors.Bulldozer, CONSTRUCTION_COLORS_RESOURCE .. ".Bulldozer")
	return colors
end

local function targetSelector(target, classScope)
	local scopeSelector = classScope and "!" .. classScope or ""
	return target.root .. scopeSelector .. " " .. target.selector
end

local function appendStateSelectors(selectors, target, state, child, classScope)
	local suffix = assert(target[state], "Unknown game bar button state: " .. state)
	assert(type(suffix) == "string", "Invalid game bar button state selector for " .. state)
	selectors[#selectors + 1] = targetSelector(target, classScope) .. suffix .. child
end

function data()
	local result = {}
	local add = ssu.makeAdder(result)
	local defaultColors = guiUtil.getResource(DEFAULT_COLORS_RESOURCE)
	for _, colorName in ipairs(REQUIRED_DEFAULT_COLORS) do
		guiUtil.validateColor(defaultColors[colorName], DEFAULT_COLORS_RESOURCE .. "." .. colorName)
	end
	local bulldozerColors = getBulldozerColors()
	local invisible = defaultColors.Invisible

	local function addButtons(targets, state, child, style, classScope)
		local selectors = {}
		for _, target in ipairs(targets) do
			appendStateSelectors(selectors, target, state, child, classScope)
		end
		add(table.concat(selectors, ", "), style)
	end

	local borderImage = { fileName = "::/gui/main/design/disk_mini_contour.tga" }

	local function addColorChoiceRules(option, property, child, targets, commonStyle)
		for _, choice in ipairs(option.choices) do
			if choice.gray ~= nil then
				local function addStateRule(state, contrast)
					local classScope = settings.styleClass(option, choice.id)
					if contrast ~= nil then
						classScope = classScope .. "!" .. settings.styleClass(settings.stateContrast, contrast.id)
					end
					local style = {
						[property] = gray(stateGray(choice.gray, state, contrast)),
					}
					if commonStyle then
						for key, value in pairs(commonStyle) do
							style[key] = value
						end
					end
					addButtons(targets, state.id, child, style, classScope)
				end

				for _, state in ipairs(colorStates) do
					if state.offsetKey == nil and state.scaleKey == nil then
						addStateRule(state, nil)
					else
						for _, contrast in ipairs(settings.stateContrast.choices) do
							addStateRule(state, contrast)
						end
					end
				end
			end
		end
	end

	addColorChoiceRules(settings.background, "backgroundColor1", "", buttons)
	addColorChoiceRules(settings.border, "borderColor", "", buttons, { borderImage = borderImage })
	addColorChoiceRules(settings.icon, "color", " ImageView", buttons)
	local noBorderStyle = {
		borderColor = invisible,
		borderImage = { fileName = "" },
	}
	local noBorderClass = settings.styleClass(settings.border, settings.NONE_CHOICE_ID)
	addButtons(buttons, "any", "", noBorderStyle, noBorderClass)

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

			local earningsText = root .. "R::GameBarEarningsPlugin TextView"
			add(earningsText .. "!positive", { color = defaultColors.Positive })
			add(earningsText .. "!negative", { color = defaultColors.Negative })
		end
	end

	local function restoreBulldozerBackground(classScope)
		local stateColors = {
			{ state = "normal", color = defaultColors.AccentVeryDark },
			{ state = "selected", color = bulldozerColors.Bulldozer },
			{ state = "idleHover", color = colorUtil.getHoverFromRaw(defaultColors.AccentVeryDark) },
			{ state = "selectedHover", color = colorUtil.getHoverFromRaw(bulldozerColors.Bulldozer) },
			{ state = "idleActive", color = colorUtil.getActiveFromRaw(defaultColors.AccentVeryDark) },
			{ state = "selectedActive", color = colorUtil.getActiveFromRaw(bulldozerColors.Bulldozer) },
		}
		for _, stateColor in ipairs(stateColors) do
			addButtons(bulldozerButtons, stateColor.state, "", {
				backgroundColor1 = stateColor.color,
			}, classScope)
		end
		addButtons(bulldozerButtons, "disabled", "", { backgroundColor1 = defaultColors.NeutralMedium }, classScope)
	end

	local function restoreBulldozerBorder(classScope)
		local borderStyle = {
			borderColor = invisible,
			borderImage = { fileName = "" },
		}
		addButtons(bulldozerButtons, "any", "", borderStyle, classScope)
	end

	local function restoreBulldozerIcon(classScope)
		addButtons(bulldozerButtons, "any", " ImageView", {
			color = bulldozerColors.Bulldozer,
		}, classScope)
		for _, state in ipairs({ "selected", "selectedHover", "selectedActive" }) do
			addButtons(bulldozerButtons, state, " ImageView", {
				color = defaultColors.AccentVeryDark,
			}, classScope)
		end
		addButtons(bulldozerButtons, "disabled", " ImageView", {
			color = defaultColors.NeutralDark,
		}, classScope)
	end

	for _, choice in ipairs(settings.bulldozerStyle.choices) do
		local classScope = settings.styleClass(settings.bulldozerStyle, choice.id)
		assert(type(choice.background) == "boolean", "Bulldozer background mode must be a boolean")
		assert(type(choice.border) == "boolean", "Bulldozer border mode must be a boolean")
		assert(type(choice.icon) == "boolean", "Bulldozer icon mode must be a boolean")
		if not choice.background then
			restoreBulldozerBackground(classScope .. "!" .. settings.background.overrideClass)
		end
		if not choice.border then
			restoreBulldozerBorder(classScope .. "!" .. settings.border.overrideClass)
		end
		if not choice.icon then
			restoreBulldozerIcon(classScope .. "!" .. settings.icon.overrideClass)
		end
	end

	return result
end
