local DARK_UI_MODULE = "apasz_dark_ui_1::/gui/main/dark_ui_settings.lua"
local UI_TWEAKS_INTEGRATION_MODULE = "apasz_dark_ui_1::/gui/main/dark_ui_ui_tweaks.lua"
local PALETTE_MODULE = "apasz_dark_ui_1::/gui/main/dark_ui_palette.lua"

package.loaded[UI_TWEAKS_INTEGRATION_MODULE] = dofile("content/gui/main/dark_ui_ui_tweaks.lua")
local palette = dofile("content/gui/main/dark_ui_palette.lua")
package.loaded[PALETTE_MODULE] = palette
local settings = dofile("content/gui/main/dark_ui_settings.lua")
package.loaded[DARK_UI_MODULE] = settings
local schema = dofile("../ui_tweaks/content/gui/ui_tweaks/settings_schema.lua")
schema.validateSection(settings.section, "Dark UI")

assert(settings.includeBulldozer.default == false)
assert(settings.stateContrast.default == "standard")
assert(settings.includeBulldozer.kind == "toggle")
assert(settings.includeBulldozer.choices == nil)
assert(#settings.options == 7)
assert(#settings.background.choices == 6)
assert(#settings.border.choices == 7)
assert(settings.border.choices[2].id == settings.NONE_CHOICE_ID)
local expectedLevels = {
	{ id = "black", label = "Black", gray = 0 },
	{ id = "dark_gray", label = "Dark grey", gray = palette.darkGray * 255 },
	{ id = "gray", label = "Grey", gray = 128 },
	{ id = "light_gray", label = "Light grey", gray = 192 },
	{ id = "white", label = "White", gray = 255 },
}
for _, option in ipairs({ settings.background, settings.border, settings.icon, settings.strip, settings.text }) do
	local index = option == settings.border and 2 or 1
	for _, expected in ipairs(expectedLevels) do
		index = index + 1
		local choice = option.choices[index]
		assert(choice.id == expected.id and choice.label == expected.label and choice.gray == expected.gray)
	end
end
assert(not pcall(settings.textStyleClasses, nil))
assert(not pcall(settings.textStyleClasses, "invalid"))
assert(not pcall(settings.colorGray, settings.background, "black", "standard", "invalid"))
assert(not pcall(settings.colorGray, settings.background, "invalid", "standard", "normal"))
assert(not pcall(settings.colorGray, settings.background, "black", "invalid", "normal"))
assert(not pcall(settings.colorGray, settings.strip, "black", "standard", "normal"))
assert(settings.colorGray(settings.background, "vanilla", "standard", "normal") == nil)
local legacyColors = {
	[0] = "black",
	[25] = "dark_gray",
	[50] = "dark_gray",
	[75] = "dark_gray",
	[100] = "gray",
	[125] = "gray",
	[150] = "gray",
	[175] = "light_gray",
	[200] = "light_gray",
	[225] = "white",
	[255] = "white",
}
for gray, expected in pairs(legacyColors) do
	local stored = { game_bar_background_color = "gray_" .. gray, unrelated = "preserved" }
	local migrated = settings.migrateStoredValues(stored)
	assert(migrated.game_bar_background_color == expected)
	assert(migrated.unrelated == "preserved" and stored.game_bar_background_color == "gray_" .. gray)
	assert(settings.migrateStoredValues(migrated) == migrated)
end
for _, legacy in ipairs({ "included", "background_only", "border_only", "background_border", "vanilla" }) do
	local migrated = settings.migrateStoredValues({ game_bar_bulldozer_style = legacy })
	assert(migrated.game_bar_include_bulldozer == (legacy ~= "vanilla"))
end
local current = { game_bar_background_color = "dark_gray", game_bar_include_bulldozer = false }
assert(settings.migrateStoredValues(current) == current)
local explicitExcluded = { game_bar_include_bulldozer = false, game_bar_bulldozer_style = "included" }
assert(settings.migrateStoredValues(explicitExcluded) == explicitExcluded)
for _, invalid in ipairs({ "gray_256", "gray_24", "gray_-1", "unknown", false }) do
	assert(not pcall(settings.migrateStoredValues, { game_bar_background_color = invalid }))
end
assert(not pcall(settings.migrateStoredValues, { game_bar_state_contrast = "invalid" }))
assert(not pcall(settings.migrateStoredValues, { game_bar_include_bulldozer = "included" }))
assert(not pcall(settings.migrateStoredValues, { game_bar_bulldozer_style = "invalid" }))

local defaultColors = {
	Invisible = { 0, 0, 0, 0 },
	Positive = { 0.45, 0.56, 0.67, 1 },
	Negative = { 0.76, 0.65, 0.54, 1 },
}
local resourceId = 10
api = {
	gui = {
		genericRep = {
			find = function(path)
				assert(path == "::/gui/main/default_colors.gres")
				return resourceId
			end,
			get = function(id)
				assert(id == 10)
				return { data = defaultColors }
			end,
		},
	},
}
local guiUtil = dofile("content/gui/main/dark_ui_gui_util.lua")
package.loaded["apasz_dark_ui_1::/gui/main/dark_ui_gui_util.lua"] = guiUtil
assert(guiUtil.grayColor(0)[1] == 0 and guiUtil.grayColor(255)[1] == 1)
for _, invalid in ipairs({ -1, 256, "128", false, 0 / 0 }) do
	assert(not pcall(guiUtil.grayColor, invalid), "Dark UI accepted an invalid grey level")
end
assert(guiUtil.getResource("::/gui/main/default_colors.gres") == defaultColors)
resourceId = -1
assert(guiUtil.findResource("::/gui/main/default_colors.gres") == nil)
assert(not pcall(guiUtil.getResource, "::/gui/main/default_colors.gres"))
for _, invalid in ipairs({ "10", 10.5, math.huge, 0 / 0 }) do
	resourceId = invalid
	assert(not pcall(guiUtil.findResource, "::/gui/main/default_colors.gres"))
end
resourceId = 10
for _, color in ipairs({ { -0.1, 0, 0 }, { 0, 1.1, 0 }, { 0, 0, 0 / 0 }, { 0, 0, 0, 1.1 }, {} }) do
	assert(not pcall(guiUtil.validateColor, color, "test color"))
end
assert(guiUtil.validateColor({ 0, 0.5, 1 }, "test color"))
assert(not pcall(guiUtil.validateColor, nil, "test color"))
assert(guiUtil.validateAlpha(0, "test alpha") == 0)
assert(guiUtil.validateAlpha(1, "test alpha") == 1)
for _, alpha in ipairs({ -0.1, 1.1, 0 / 0, false, "0.5" }) do
	assert(not pcall(guiUtil.validateAlpha, alpha, "test alpha"))
end
dofile("content/gui/main/dark_ui_settings.res.lua")
assert(data().data == settings.section and data().type == settings.RESOURCE_TYPE)

local gameStylesheetUtil
if arg[1] then
	local gameSource = dofile("tests/game_source.lua").new(arg[1])
	local builtinSource = gameSource.read("gui", "gui/main/builtin.lua")
	assert(builtinSource:find('react.useState("unchecked")', 1, true))
	assert(builtinSource:find('and "checked" or "unchecked"', 1, true))
	local gameBarSource = gameSource.read("gui", "gui/game_bar/game_bar.tl")
	for _, recipe in ipairs({ "ManagerToolButton", "ConstructionToolButton", "MapEditorToolButton", "NodeEditorButton" }) do
		assert(
			gameBarSource:find('react.RegisterRecipe("' .. recipe .. '"', 1, true),
			"Missing game bar target " .. recipe
		)
	end
	for _, id in ipairs({ "menu.bulldozer", "menu.moduleBulldozer" }) do
		assert(gameBarSource:find('id = "' .. id .. '"', 1, true), "Missing bulldozer target " .. id)
	end
	assert(gameBarSource:find('class = "extra"', 1, true), "Missing context help button class")
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
	local environment = setmetatable({
		require = function(path)
			assert(path == "/scripts/table_util.tl")
			return { copy = copy }
		end,
	}, { __index = _G })
	gameStylesheetUtil = gameSource.load("gui", "gui/main/stylesheetutil.lua", environment)
end
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
assert(#rules == 12, "Dark UI exceeded its stylesheet rule budget: " .. #rules)
resourceId = -1
assert(not pcall(data), "Dark UI accepted a missing palette")
resourceId = 10
local positive = defaultColors.Positive
defaultColors.Positive = {}
assert(not pcall(data), "Dark UI accepted an invalid status colour")
defaultColors.Positive = positive

local root = "#menu.gamebar!" .. settings.GAME_BAR_STYLE_CLASS
local bySelector = {}
for _, rule in ipairs(rules) do
	assert(bySelector[rule.selector] == nil, "Duplicate stylesheet selector")
	bySelector[rule.selector] = rule
	assert(rule.selector:find(root .. "!", 1, true))
	assert(not rule.selector:find("menu.bulldozer", 1, true), "Dark UI reconstructs bulldozer styling")
	assert(rule.style.shadowColor == nil and rule.style.shadowWidth == nil)
	assert(rule.style.backgroundColor2 == nil)
	assert(rule.selector:find("R::GameBarInfoDisplay", 1, true))
	assert(
		rule.selector:find("R::GameBarEarningsPlugin", 1, true)
			or rule.selector:find("R::GameBarTransportedPlugin", 1, true)
	)
	assert(not rule.selector:find("ImageView", 1, true), "CSS masks inline icons")
	assert(rule.style.color ~= nil and rule.style.backgroundColor == nil and rule.style.backgroundColor1 == nil)
	assert(rule.style.borderColor == nil and rule.style.borderImage == nil)
	if gameStylesheetUtil then
		assert(rule.levels[1].id == "menu.gamebar")
		assert(rule.levels[#rule.levels].element == "TextView")
	end
end

local function matchesRootClasses(rule, classes)
	local classSet = {}
	for _, className in ipairs(classes) do
		classSet[className] = true
	end
	for className in rule.selector:match("^[^ ]+"):gmatch("!([%w%-]+)") do
		if not classSet[className] then
			return false
		end
	end
	return true
end
local vanillaClasses = settings.textStyleClasses(settings.VANILLA_CHOICE_ID)
for _, rule in ipairs(rules) do
	assert(not matchesRootClasses(rule, vanillaClasses), "Vanilla text settings change existing styling")
end
local colorCaseCount = 0
for _, option in ipairs(settings.buttonColors) do
	for _, choice in ipairs(option.choices) do
		for _, contrast in ipairs(settings.stateContrast.choices) do
			local offsets = {
				normal = 0,
				selected = contrast.selectedOffset,
				idleHover = contrast.hoverOffset,
				selectedHover = contrast.selectedHoverOffset,
			}
			for _, state in ipairs(settings.colorStates) do
				local actual = settings.colorGray(option, choice.id, contrast.id, state.id)
				if choice.gray == nil then
					assert(actual == nil, "Vanilla/None acquired a state colour")
				else
					local expected = state.id == "disabled" and choice.gray * contrast.disabledScale
						or choice.gray + assert(offsets[state.id], "Unknown colour state")
					expected = math.max(0, math.min(255, expected))
					assert(math.abs(actual - expected) < 1e-12, "Wrong state colour for " .. state.id)
				end
				colorCaseCount = colorCaseCount + 1
			end
		end
	end
end
for _, choice in ipairs(settings.text.choices) do
	local classes = settings.textStyleClasses(choice.id)
	assert(classes[1] == settings.GAME_BAR_STYLE_CLASS and classes[2] == choice.styleClass)
	assert(#classes == (choice.gray == nil and 2 or 3))
	if choice.gray ~= nil then
		assert(classes[3] == settings.text.overrideClass)
		local prefix = root .. "!" .. choice.styleClass
		for _, recipe in ipairs({ "GameBarEarningsPlugin", "GameBarTransportedPlugin" }) do
			local selector = prefix .. " R::GameBarMenuMiddle R::GameBarInfoDisplay R::" .. recipe .. " TextView"
			local color = assert(bySelector[selector]).style.color
			for channel = 1, 3 do
				assert(math.abs(color[channel] - choice.gray / 255) < 1e-12)
			end
			assert(color[4] == 1)
		end
	end
end
local earnings = root
	.. "!"
	.. settings.text.overrideClass
	.. " R::GameBarMenuMiddle R::GameBarInfoDisplay R::GameBarEarningsPlugin TextView"
for state, name in pairs({ positive = "Positive", negative = "Negative" }) do
	for channel = 1, 4 do
		assert(bySelector[earnings .. "!" .. state].style.color[channel] == defaultColors[name][channel])
	end
end
if gameStylesheetUtil then
	print("TpF3 stylesheet parser test passed (" .. #rules .. " compiled rules)")
end
print("Dark UI settings test passed (" .. #rules .. " rules)")
print("Dark UI state colour test passed (" .. colorCaseCount .. " cases)")
