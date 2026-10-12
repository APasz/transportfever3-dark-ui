local DARK_UI_MODULE = "apasz_dark_ui_1::/gui/main/dark_ui_settings.lua"
local UI_TWEAKS_INTEGRATION_MODULE = "apasz_dark_ui_1::/gui/main/dark_ui_ui_tweaks.lua"

package.loaded[UI_TWEAKS_INTEGRATION_MODULE] = dofile("content/gui/main/dark_ui_ui_tweaks.lua")
local settings = dofile("content/gui/main/dark_ui_settings.lua")

local function defaultSelection()
	local result = {}
	for _, option in ipairs(settings.options) do
		result[option.stateKey] = option.default
	end
	return result
end

local selected = defaultSelection()
assert(selected.gameBarBackgroundColor == "vanilla")
assert(selected.gameBarBorderColor == "vanilla")
assert(selected.gameBarIconColor == "vanilla")
assert(selected.gameBarStripColor == "vanilla")
assert(selected.gameBarTextColor == "vanilla")
assert(selected.gameBarButtonShadow == nil)
assert(settings.shadow == nil)
assert(selected.gameBarStateContrast == "standard")
assert(selected.gameBarBulldozerStyle == "vanilla")
local defaultClasses = settings.styleClasses(selected)
assert(#defaultClasses == #settings.options + 1)
assert(defaultClasses[1] == settings.GAME_BAR_STYLE_CLASS)
assert(defaultClasses[2] == "dark-ui-background-vanilla")
assert(defaultClasses[#defaultClasses] == "dark-ui-bulldozer-vanilla")
assert(settings.section.id == "apasz.dark_ui")
assert(settings.section.settings[1].key == "game_bar_background_color")
assert(settings.section.settings[2].key == "game_bar_border_color")
assert(settings.section.settings[3].key == "game_bar_icon_color")
assert(settings.section.settings[4].key == "game_bar_strip_color")
assert(settings.section.settings[5].key == "game_bar_text_color")
assert(#settings.section.settings == 7)
assert(settings.section.settings[6].key == "game_bar_state_contrast")
assert(settings.section.settings[7].key == "game_bar_bulldozer_style")
assert(settings.section.settings[7].kind == "dropdown")
assert(#settings.bulldozerStyle.choices == 5)
assert(settings.section.settings[1].options[1].gray == nil)
assert(#settings.background.choices == 12)
assert(#settings.border.choices == 13)
assert(settings.border.choices[2].id == settings.NONE_CHOICE_ID)
local labels = {}
local function choiceById(option, choiceId)
	for _, choice in ipairs(option.choices) do
		if choice.id == choiceId then
			return choice
		end
	end
	error("Missing choice " .. choiceId .. " for " .. option.key)
end
for _, backgroundChoice in ipairs(settings.background.choices) do
	for _, option in ipairs({ settings.border, settings.icon, settings.strip, settings.text }) do
		local matchingChoice = choiceById(option, backgroundChoice.id)
		assert(matchingChoice.gray == backgroundChoice.gray)
	end
	assert(not labels[backgroundChoice.label])
	labels[backgroundChoice.label] = true
end
assert(settings.styleClass(settings.background, "gray_50") == "dark-ui-background-gray-50")

local configuredSelection = defaultSelection()
configuredSelection.gameBarBackgroundColor = "gray_50"
configuredSelection.gameBarBorderColor = "gray_100"
configuredSelection.gameBarIconColor = "gray_225"
configuredSelection.gameBarStripColor = "gray_25"
configuredSelection.gameBarTextColor = "gray_200"
-- Removed settings can remain in persisted saves without affecting the active schema.
configuredSelection.gameBarButtonShadow = "strong"
configuredSelection.gameBarBulldozerStyle = "background_border"
settings.validate(configuredSelection)
local configuredClasses = settings.styleClasses(configuredSelection)
local overrideClasses = {}
for _, className in ipairs(configuredClasses) do
	overrideClasses[className] = true
end
assert(#configuredClasses == #defaultClasses + 3)
assert(overrideClasses[settings.background.overrideClass])
assert(overrideClasses[settings.border.overrideClass])
assert(overrideClasses[settings.icon.overrideClass])
local borderlessSelection = defaultSelection()
borderlessSelection.gameBarBorderColor = settings.NONE_CHOICE_ID
assert(settings.styleClasses(borderlessSelection)[4] == settings.border.overrideClass)
assert(not pcall(settings.styleClass, {}, "vanilla"))
assert(not pcall(settings.styleClasses, nil))
configuredSelection.gameBarBackgroundColor = "invalid"
assert(not pcall(settings.validate, configuredSelection))
assert(not pcall(settings.styleClasses, configuredSelection))

local defaultColors = {
	Invisible = { 0, 0, 0, 0 },
	AccentVeryDark = { 0.11, 0.11, 0.11, 1 },
	AccentDark = { 0.22, 0.22, 0.22, 1 },
	AccentMedium = { 0.44, 0.44, 0.44, 1 },
	NeutralVeryDark = { 0.12, 0.12, 0.12, 1 },
	NeutralDark = { 0.34, 0.34, 0.34, 1 },
	NeutralMedium = { 0.56, 0.56, 0.56, 1 },
	NeutralLight = { 0.78, 0.78, 0.78, 1 },
	Positive = { 0.45, 0.56, 0.67, 1 },
	Negative = { 0.76, 0.65, 0.54, 1 },
}
local constructionColors = {
	Bulldozer = { 0.91, 0.81, 0.01, 1 },
	BulldozerLighter = { 0.98, 0.96, 0.37, 1 },
}
local constructionResource = { data = constructionColors }
local guiResourceIds = {
	["::/gui/main/default_colors.gres"] = 10,
	["::/gui/construction/construction.gres"] = 11,
}
api = {
	gui = {
		genericRep = {
			find = function(path)
				return guiResourceIds[path] or -1
			end,
			get = function(resourceId)
				if resourceId == 10 then
					return { data = defaultColors }
				end
				if resourceId == 11 then
					return constructionResource
				end
				error("Unexpected GUI resource id " .. tostring(resourceId))
			end,
		},
	},
}
local guiUtil = dofile("content/gui/main/dark_ui_gui_util.lua")
package.loaded["apasz_dark_ui_1::/gui/main/dark_ui_gui_util.lua"] = guiUtil
assert(guiUtil.getResource("::/gui/main/default_colors.gres") == defaultColors)
assert(guiUtil.findResource("::/gui/main/missing.gres") == nil)
assert(not pcall(guiUtil.getResource, "::/gui/main/missing.gres"))
assert(not pcall(guiUtil.findResource, ""))
for _, resourceId in ipairs({ "10", 10.5, math.huge, 0 / 0 }) do
	guiResourceIds["::/gui/main/invalid.gres"] = resourceId
	assert(not pcall(guiUtil.findResource, "::/gui/main/invalid.gres"), "Dark UI accepted an invalid resource id")
end
guiResourceIds["::/gui/main/invalid.gres"] = nil
assert(guiUtil.validateAlpha(0, "test alpha") == 0)
assert(guiUtil.validateAlpha(1, "test alpha") == 1)
for _, alpha in ipairs({ -0.1, 1.1, 0 / 0, false, "0.5" }) do
	assert(not pcall(guiUtil.validateAlpha, alpha, "test alpha"))
end
assert(not pcall(guiUtil.validateAlpha, nil, "test alpha"))
local validColor = { 0.1, 0.2, 0.3, 0.4 }
assert(guiUtil.validateColor(validColor, "test color") == validColor)
assert(guiUtil.validateColor({ 0, 0.5, 1 }, "test color"))
for _, color in ipairs({ { -0.1, 0, 0 }, { 0, 1.1, 0 }, { 0, 0, 0 / 0 }, { 0, 0, 0, 1.1 }, {} }) do
	assert(not pcall(guiUtil.validateColor, color, "test color"))
end
assert(not pcall(guiUtil.validateColor, nil, "test color"))

package.loaded[DARK_UI_MODULE] = settings
dofile("content/gui/main/dark_ui_settings.res.lua")
assert(data().type == settings.RESOURCE_TYPE)
assert(data().data == settings.section)
local gameStylesheetUtil
local function shiftColor(color, amount)
	return { math.min(color[1] + amount, 1), math.min(color[2] + amount, 1), math.min(color[3] + amount, 1), color[4] }
end
local colorUtil = {
	getHoverFromRaw = function(color)
		return shiftColor(color, 0.2)
	end,
	getActiveFromRaw = function(color)
		return shiftColor(color, 0.1)
	end,
}
if arg[1] then
	-- TpF3 loads the packaged base files; legacy loose GUI files may be outdated.
	local gameSource = dofile("tests/game_source.lua").new(arg[1])
	local builtinSource = gameSource.read("gui", "gui/main/builtin.lua")
	local nativeToolButton = assert(
		builtinSource:match('builtin%.ToolButton%s*=%s*react%.DeclareBuiltinWithUserdata%("ToolButton",(.-)\nbuiltin%.'),
		"Could not inspect TpF3's ToolButton state classes"
	)
	assert(nativeToolButton:find('react.useState("unchecked")', 1, true), "TpF3 changed the idle ToolButton class")
	assert(nativeToolButton:find('and "checked" or "unchecked"', 1, true), "TpF3 changed the selected ToolButton class")
	assert(nativeToolButton:find("react.setStyleClasses(checkedState:old())", 1, true))
	local nativeGameBarStyles = gameSource.read("gui", "gui/game_bar/game_bar.css.lua")
	for _, stateClass in ipairs({ "unchecked", "checked" }) do
		assert(
			nativeGameBarStyles:find("ToolButton!" .. stateClass, 1, true),
			"TpF3's game-bar stylesheet no longer uses ToolButton!" .. stateClass
		)
	end
	string.split = function(value, separator)
		local result = {}
		local start = 1
		while true do
			local position = value:find(separator, start, true)
			if position == nil then
				result[#result + 1] = value:sub(start)
				return result
			end
			result[#result + 1] = value:sub(start, position - 1)
			start = position + #separator
		end
	end
	string.strip = function(value)
		return value:match("^%s*(.-)%s*$")
	end
	string.ends = function(value, suffix)
		return value:sub(-#suffix) == suffix
	end
	local function copy(value)
		if type(value) ~= "table" then
			return value
		end
		local result = {}
		for key, child in pairs(value) do
			result[key] = copy(child)
		end
		return result
	end
	local dependencies = {
		["/scripts/table_util.tl"] = { copy = copy },
	}
	local environment = setmetatable({
		require = function(path)
			return assert(dependencies[path], "Unexpected stylesheet dependency " .. path)
		end,
	}, { __index = _G })
	gameStylesheetUtil = gameSource.load("gui", "gui/main/stylesheetutil.lua", environment)
	local mathUtil = gameSource.load("scripts", "scripts/mathutil.lua")
	local colorEnvironment = setmetatable({
		ug_require = function(path)
			assert(path == "/scripts/mathutil.lua")
			return mathUtil
		end,
	}, { __index = _G })
	local colorInternal = gameSource.load("gui", "gui/main/color_internal.lua", colorEnvironment)
	colorEnvironment.ug_require = function(path)
		if path == "::/scripts/mathutil.lua" then
			return mathUtil
		end
		assert(path == "::/gui/main/color_internal.lua")
		return colorInternal
	end
	colorUtil = gameSource.load("gui", "gui/main/color_util.tl", colorEnvironment)
end
package.loaded["::/gui/main/color_util.tl"] = colorUtil
package.loaded["::/gui/main/stylesheetutil.lua"] = {
	makeAdder = function(rules)
		local gameAdder = gameStylesheetUtil and gameStylesheetUtil.makeAdder(rules)
		return function(selector, style)
			for alternative in selector:gmatch("[^,]+") do
				local sourceSelector = alternative:match("^%s*(.-)%s*$")
				if gameAdder then
					gameAdder(sourceSelector, style)
					local rule = rules[#rules]
					rule.selector = sourceSelector
					rule.style = rule.styleSheet
				else
					rules[#rules + 1] = { selector = sourceSelector, style = style }
				end
			end
		end
	end,
}
dofile("content/gui/game_bar/zzz_dark_ui_game_bar.css.lua")
local rules = data()

guiResourceIds["::/gui/construction/construction.gres"] = nil
local fallbackRules = data()
guiResourceIds["::/gui/construction/construction.gres"] = 11
constructionResource = { data = {} }
assert(not pcall(data), "Dark UI accepted an invalid construction color resource")
constructionResource = { data = constructionColors }
guiResourceIds["::/gui/main/default_colors.gres"] = nil
assert(not pcall(data), "Dark UI accepted a missing default color resource")
guiResourceIds["::/gui/main/default_colors.gres"] = 10

local function hasSelector(rule, expectedSelector)
	return rule.selector == expectedSelector
end

local function ruleStyle(expectedSelector, property)
	for index, rule in ipairs(rules) do
		if hasSelector(rule, expectedSelector) and rule.style[property] then
			return rule.style[property], index
		end
	end
	error("Missing " .. property .. " for " .. expectedSelector)
end

local function ruleColor(selectorPart, property)
	return ruleStyle(selectorPart, property)[1]
end

local function fallbackRuleColor(expectedSelector, property)
	for _, rule in ipairs(fallbackRules) do
		if hasSelector(rule, expectedSelector) and rule.style[property] then
			return rule.style[property][1]
		end
	end
	error("Missing fallback " .. property .. " for " .. expectedSelector)
end

local gameBarRoot = "#menu.gamebar!" .. settings.GAME_BAR_STYLE_CLASS
local gameBarButtonScope = " R::GameBarMenuMiddle !upper-layout "
local toolButton = gameBarButtonScope .. "R::ConstructionToolButton ToolButton"
local toggleButton = gameBarButtonScope .. "R::NodeEditorButton ToggleButton"
local standardContrast = "!dark-ui-state-contrast-standard"
local background = gameBarRoot .. "!dark-ui-background-gray-50" .. toolButton
local backgroundWithContrast = gameBarRoot .. "!dark-ui-background-gray-50" .. standardContrast .. toolButton
local border = gameBarRoot .. "!dark-ui-border-gray-50" .. toolButton
local borderWithContrast = gameBarRoot .. "!dark-ui-border-gray-50" .. standardContrast .. toolButton
local icon = gameBarRoot .. "!dark-ui-icon-gray-225" .. toolButton
local iconWithContrast = gameBarRoot .. "!dark-ui-icon-gray-225" .. standardContrast .. toolButton
assert(ruleColor(background .. "!unchecked", "backgroundColor1") == 50 / 255)
assert(ruleColor(backgroundWithContrast .. "!unchecked:hover", "backgroundColor1") == 80 / 255)
assert(ruleColor(backgroundWithContrast .. "!checked:hover", "backgroundColor1") == 95 / 255)
assert(ruleColor(backgroundWithContrast .. ":disabled", "backgroundColor1") == 25 / 255)
assert(ruleColor(border .. "!unchecked", "borderColor") == 50 / 255)
assert(ruleColor(borderWithContrast .. "!checked:hover", "borderColor") == 95 / 255)
assert(ruleColor(borderWithContrast .. ":disabled", "borderColor") == 25 / 255)
assert(
	ruleStyle(borderWithContrast .. "!checked", "borderImage").fileName == "::/gui/main/design/disk_mini_contour.tga"
)
assert(
	ruleStyle(borderWithContrast .. "!checked:hover", "borderImage").fileName
		== "::/gui/main/design/disk_mini_contour.tga"
)
assert(
	ruleStyle(borderWithContrast .. ":disabled", "borderImage").fileName == "::/gui/main/design/disk_mini_contour.tga"
)
assert(ruleColor(icon .. "!unchecked ImageView", "color") == 225 / 255)
assert(ruleColor(iconWithContrast .. "!checked:hover ImageView", "color") == 1)
assert(ruleColor(iconWithContrast .. ":disabled ImageView", "color") == 112.5 / 255)
local toggleBackground = gameBarRoot .. "!dark-ui-background-gray-50" .. toggleButton
local toggleBackgroundWithContrast = gameBarRoot .. "!dark-ui-background-gray-50" .. standardContrast .. toggleButton
assert(ruleColor(toggleBackground .. "!unchecked", "backgroundColor1") == 50 / 255)
assert(ruleColor(toggleBackgroundWithContrast .. "!checked:hover", "backgroundColor1") == 95 / 255)
local extraToggleBackground = gameBarRoot .. "!dark-ui-background-gray-50 ToggleButton!extra"
assert(ruleColor(extraToggleBackground .. "!unchecked", "backgroundColor1") == 50 / 255)
local subtleBackground = gameBarRoot .. "!dark-ui-background-gray-50!dark-ui-state-contrast-subtle" .. toolButton
local strongBackground = gameBarRoot .. "!dark-ui-background-gray-50!dark-ui-state-contrast-strong" .. toolButton
assert(ruleColor(subtleBackground .. "!checked:hover", "backgroundColor1") == 80 / 255)
assert(ruleColor(subtleBackground .. ":disabled", "backgroundColor1") == 35 / 255)
assert(ruleColor(strongBackground .. "!checked:hover", "backgroundColor1") == 125 / 255)
assert(ruleColor(strongBackground .. ":disabled", "backgroundColor1") == 15 / 255)

local noBorder = gameBarRoot .. "!dark-ui-border-none" .. toolButton
assert(ruleStyle(noBorder, "borderImage").fileName == "")
assert(ruleColor(noBorder, "borderColor") == defaultColors.Invisible[1])
local strip = gameBarRoot .. "!dark-ui-strip-gray-25 R::GameBarBackground !bottom"
assert(ruleColor(strip, "backgroundColor") == 25 / 255)
local infoText = gameBarRoot .. "!dark-ui-text-gray-200 R::GameBarMenuMiddle R::GameBarInfoDisplay "
local earningsText = infoText .. "R::GameBarEarningsPlugin TextView"
local transportedText = infoText .. "R::GameBarTransportedPlugin TextView"
assert(ruleColor(earningsText, "color") == 200 / 255)
assert(ruleColor(transportedText, "color") == 200 / 255)
assert(ruleColor(earningsText .. "!positive", "color") == defaultColors.Positive[1])
assert(ruleColor(earningsText .. "!negative", "color") == defaultColors.Negative[1])
local foundRoadButtonIconRule = false
local bulldozerRestorationProperties = {}
for _, choice in ipairs(settings.bulldozerStyle.choices) do
	bulldozerRestorationProperties[choice.id] = {}
end
for _, rule in ipairs(rules) do
	assert(not rule.selector:find("dark-ui-background-vanilla", 1, true))
	assert(not rule.selector:find("dark-ui-border-vanilla", 1, true))
	assert(not rule.selector:find("dark-ui-icon-vanilla", 1, true))
	assert(not rule.selector:find("dark-ui-strip-vanilla", 1, true))
	assert(not rule.selector:find("dark-ui-text-vanilla", 1, true))
	assert(not rule.selector:find("dark-ui-shadow-", 1, true))
	assert(rule.style.shadowColor == nil and rule.style.shadowWidth == nil, "Dark UI overrides button shadows")
	assert(not rule.selector:find("!active", 1, true), "Dark UI uses an invalid selected-button class")
	assert(not rule.selector:find("!inactive", 1, true), "Dark UI uses an invalid idle-button class")
	assert(not rule.selector:find("gray_", 1, true))
	assert(rule.selector:find(gameBarRoot .. "!", 1, true))
	assert(rule.style.backgroundColor2 == nil, "Dark UI unnecessarily overrides a secondary background layer")
	if rule.selector:find("R::GameBarInfoDisplay", 1, true) then
		assert(
			rule.selector:find("R::GameBarEarningsPlugin", 1, true)
				or rule.selector:find("R::GameBarTransportedPlugin", 1, true),
			"Dark UI has an unscoped GameBar info-display rule"
		)
	end
	if rule.selector:find(" ToolButton", 1, true) then
		assert(
			rule.selector:find("R::ConstructionToolButton ToolButton", 1, true)
				or rule.selector:find("R::ManagerToolButton ToolButton", 1, true)
				or rule.selector:find("R::MapEditorToolButton ToolButton", 1, true),
			"Dark UI has a generic ToolButton rule"
		)
	end
	if
		rule.selector:find("dark-ui-icon-gray-225", 1, true)
		and rule.selector:find(toolButton .. "!unchecked ImageView", 1, true)
	then
		foundRoadButtonIconRule = true
	end
	if rule.selector:find("menu.bulldozer", 1, true) then
		for _, choice in ipairs(settings.bulldozerStyle.choices) do
			local className = settings.styleClass(settings.bulldozerStyle, choice.id)
			if rule.selector:find(gameBarRoot .. "!" .. className, 1, true) then
				for property in pairs(rule.style) do
					bulldozerRestorationProperties[choice.id][property] = true
				end
			end
		end
	end
end
assert(foundRoadButtonIconRule)
local vanilla = bulldozerRestorationProperties.vanilla
assert(vanilla.backgroundColor1 and vanilla.borderImage and vanilla.color)
local function vanillaBulldozerButton(option)
	return gameBarRoot
		.. "!dark-ui-bulldozer-vanilla!"
		.. option.overrideClass
		.. gameBarButtonScope
		.. "#menu.bulldozer"
end
local vanillaBulldozerBackground = vanillaBulldozerButton(settings.background)
local vanillaBulldozerIcon = vanillaBulldozerButton(settings.icon)
assert(ruleColor(vanillaBulldozerBackground .. "!unchecked", "backgroundColor1") == defaultColors.AccentVeryDark[1])
assert(
	ruleColor(vanillaBulldozerBackground .. "!unchecked:hover", "backgroundColor1")
		== colorUtil.getHoverFromRaw(defaultColors.AccentVeryDark)[1]
)
assert(
	ruleColor(vanillaBulldozerBackground .. "!unchecked:active", "backgroundColor1")
		== colorUtil.getActiveFromRaw(defaultColors.AccentVeryDark)[1]
)
assert(ruleColor(vanillaBulldozerBackground .. "!checked", "backgroundColor1") == constructionColors.Bulldozer[1])
assert(
	ruleColor(vanillaBulldozerBackground .. "!checked:hover", "backgroundColor1")
		== colorUtil.getHoverFromRaw(constructionColors.Bulldozer)[1]
)
assert(
	ruleColor(vanillaBulldozerBackground .. "!checked:active", "backgroundColor1")
		== colorUtil.getActiveFromRaw(constructionColors.Bulldozer)[1]
)
assert(ruleColor(vanillaBulldozerBackground .. ":disabled", "backgroundColor1") == defaultColors.NeutralMedium[1])
assert(fallbackRuleColor(vanillaBulldozerBackground .. "!checked", "backgroundColor1") == 1)
assert(ruleColor(vanillaBulldozerIcon .. " ImageView", "color") == constructionColors.Bulldozer[1])
assert(ruleColor(vanillaBulldozerIcon .. "!checked ImageView", "color") == defaultColors.AccentVeryDark[1])
assert(ruleColor(vanillaBulldozerIcon .. "!checked:hover ImageView", "color") == defaultColors.AccentVeryDark[1])
assert(ruleColor(vanillaBulldozerIcon .. ":disabled ImageView", "color") == defaultColors.NeutralDark[1])
local _, selectedIconRuleIndex = ruleStyle(vanillaBulldozerIcon .. "!checked ImageView", "color")
local _, disabledIconRuleIndex = ruleStyle(vanillaBulldozerIcon .. ":disabled ImageView", "color")
assert(disabledIconRuleIndex > selectedIconRuleIndex, "Selected bulldozer icons override the disabled state")
local included = bulldozerRestorationProperties.included
assert(next(included) == nil)
local backgroundOnly = bulldozerRestorationProperties.background_only
assert(not backgroundOnly.backgroundColor1)
assert(backgroundOnly.borderImage and backgroundOnly.color)
local borderOnly = bulldozerRestorationProperties.border_only
assert(borderOnly.backgroundColor1 and not borderOnly.borderImage)
assert(borderOnly.color)
local backgroundBorder = bulldozerRestorationProperties.background_border
assert(not backgroundBorder.backgroundColor1 and not backgroundBorder.borderImage)
assert(backgroundBorder.color)

local function matchesRootClasses(rule, classes)
	local selectedClasses = {}
	for _, className in ipairs(classes) do
		selectedClasses[className] = true
	end
	for className in rule.selector:match("^[^ ]+"):gmatch("!([%w%-]+)") do
		if not selectedClasses[className] then
			return false
		end
	end
	return true
end
for _, choice in ipairs(settings.bulldozerStyle.choices) do
	local vanillaSelection = defaultSelection()
	vanillaSelection.gameBarBulldozerStyle = choice.id
	local classes = settings.styleClasses(vanillaSelection)
	for _, rule in ipairs(rules) do
		assert(not matchesRootClasses(rule, classes), "Vanilla settings override existing UI styling")
	end
end
local backgroundSelection = defaultSelection()
backgroundSelection.gameBarBackgroundColor = "gray_50"
local backgroundClasses = settings.styleClasses(backgroundSelection)
local matchedRestoration = false
for _, rule in ipairs(rules) do
	if matchesRootClasses(rule, backgroundClasses) then
		assert(
			rule.style.borderColor == nil and rule.style.color == nil,
			"Background setting overrides other properties"
		)
		if rule.selector:find("#menu.bulldozer", 1, true) then
			matchedRestoration = true
		end
	end
end
assert(matchedRestoration, "An explicit background override did not preserve Vanilla bulldozer colours")

if gameStylesheetUtil then
	local function parsedRule(expectedSelector)
		for _, rule in ipairs(rules) do
			if rule.selector == expectedSelector then
				return rule
			end
		end
		error("Missing compiled rule for " .. expectedSelector)
	end
	local parsedBackground = parsedRule(background .. "!unchecked")
	assert(#parsedBackground.levels == 5)
	assert(parsedBackground.levels[1].id == "menu.gamebar")
	assert(parsedBackground.levels[1].classList[1] == settings.GAME_BAR_STYLE_CLASS)
	assert(parsedBackground.levels[1].classList[2] == settings.styleClass(settings.background, "gray_50"))
	assert(parsedBackground.levels[4].element == "R::ConstructionToolButton")
	assert(parsedBackground.levels[5].element == "ToolButton")
	assert(parsedBackground.levels[5].classList[1] == "unchecked")
	local parsedHoveredIcon = parsedRule(iconWithContrast .. "!checked:hover ImageView")
	assert(parsedHoveredIcon.levels[5].classList[1] == "checked")
	assert(parsedHoveredIcon.levels[5].pseudoClassList[1] == "hover")
	assert(parsedHoveredIcon.levels[6].element == "ImageView")
	assert(#parsedHoveredIcon.levels[6].pseudoClassList == 0)
	local parsedDisabledIcon = parsedRule(iconWithContrast .. ":disabled ImageView")
	assert(parsedDisabledIcon.levels[5].pseudoClassList[1] == "disabled")
	assert(parsedDisabledIcon.levels[6].element == "ImageView")
	assert(#parsedDisabledIcon.levels[6].pseudoClassList == 0)
	for _, rule in ipairs(rules) do
		assert(rule.pseudoClassList == nil, "Dark UI is using TpF3's obsolete selector schema")
		local expectedPseudoClass = rule.selector:match(":(hover)")
			or rule.selector:match(":(disabled)")
			or rule.selector:match(":(active)")
		if expectedPseudoClass then
			local found = false
			for _, level in ipairs(rule.levels) do
				if level.pseudoClassList[1] == expectedPseudoClass then
					found = true
				end
			end
			assert(found, "TpF3 discarded a " .. expectedPseudoClass .. " state")
		end
	end
	assert(#rules < 2600, "Dark UI exceeded its stylesheet rule budget: " .. #rules)
	print("TpF3 stylesheet parser test passed (" .. #rules .. " compiled rules)")
end

print("Dark UI settings test passed")
