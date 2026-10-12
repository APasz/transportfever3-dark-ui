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

local function defaultSelection()
	local result = {}
	for _, option in ipairs(settings.options) do
		result[option.stateKey] = option.default
	end
	return result
end

local selected = defaultSelection()
assert(selected.gameBarIncludeBulldozer == false)
assert(selected.gameBarStateContrast == "standard")
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
assert(settings.styleClass(settings.background, "dark_gray") == "dark-ui-background-dark-gray")
assert(not pcall(settings.styleClass, {}, "vanilla"))
assert(not pcall(settings.styleClass, settings.includeBulldozer, false))
assert(not pcall(settings.styleClasses, nil))
selected.gameBarIncludeBulldozer = "included"
assert(not pcall(settings.validate, selected))
selected = defaultSelection()
selected.gameBarBackgroundColor = "invalid"
assert(not pcall(settings.validate, selected))
assert(not pcall(settings.styleClasses, selected))

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
assert(#rules < 200, "Dark UI exceeded its stylesheet rule budget: " .. #rules)
resourceId = -1
assert(not pcall(data), "Dark UI accepted a missing palette")
resourceId = 10
local positive = defaultColors.Positive
defaultColors.Positive = {}
assert(not pcall(data), "Dark UI accepted an invalid status colour")
defaultColors.Positive = positive

local root = "#menu.gamebar!" .. settings.GAME_BAR_STYLE_CLASS
local target = " !" .. settings.BUTTON_STYLE_CLASS
local bySelector = {}
for _, rule in ipairs(rules) do
	assert(bySelector[rule.selector] == nil, "Duplicate stylesheet selector")
	bySelector[rule.selector] = rule
	assert(rule.selector:find(root .. "!", 1, true))
	assert(not rule.selector:find("menu.bulldozer", 1, true), "Dark UI reconstructs bulldozer styling")
	assert(rule.style.shadowColor == nil and rule.style.shadowWidth == nil)
	assert(rule.style.backgroundColor2 == nil)
	if rule.selector:find("R::GameBarInfoDisplay", 1, true) then
		assert(
			rule.selector:find("R::GameBarEarningsPlugin", 1, true)
				or rule.selector:find("R::GameBarTransportedPlugin", 1, true)
		)
	else
		assert(rule.selector:find(target, 1, true) or rule.selector:find("R::GameBarBackground !bottom", 1, true))
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
for _, included in ipairs({ false, true }) do
	local vanilla = defaultSelection()
	vanilla.gameBarIncludeBulldozer = included
	for _, rule in ipairs(rules) do
		assert(not matchesRootClasses(rule, settings.styleClasses(vanilla)), "Vanilla settings change existing styling")
	end
end
local suffixes = {
	normal = "!unchecked",
	selected = "!checked",
	idleHover = "!unchecked:hover",
	selectedHover = "!checked:hover",
	disabled = ":disabled",
}
for _, option in ipairs(settings.buttonColors) do
	for _, choice in ipairs(option.choices) do
		if choice.gray ~= nil then
			for _, contrast in ipairs(settings.stateContrast.choices) do
				local configured = defaultSelection()
				configured[option.stateKey] = choice.id
				configured.gameBarStateContrast = contrast.id
				local classes = settings.styleClasses(configured)
				local uniqueClasses = {}
				for _, className in ipairs(classes) do
					assert(not uniqueClasses[className], "Duplicate style class")
					uniqueClasses[className] = true
				end
				for _, state in ipairs(settings.colorStates) do
					local found
					for _, rule in ipairs(rules) do
						if
							rule.selector:sub(-#(target .. suffixes[state.id] .. option.child))
								== target .. suffixes[state.id] .. option.child
							and matchesRootClasses(rule, classes)
							and rule.style[option.property]
						then
							assert(found == nil, "Multiple colour rules match one state")
							found = rule
						end
					end
					assert(
						found,
						"Missing colour state "
							.. option.key
							.. "/"
							.. choice.id
							.. "/"
							.. contrast.id
							.. "/"
							.. state.id
					)
					local expected = choice.gray
					if state.offsetKey then
						expected = expected + contrast[state.offsetKey]
					end
					if state.scaleKey then
						expected = expected * contrast[state.scaleKey]
					end
					expected = math.max(0, math.min(255, expected)) / 255
					local color = found.style[option.property]
					for channel = 1, 3 do
						assert(math.abs(color[channel] - expected) < 1e-12)
					end
					assert(color[4] == 1)
					for _, other in ipairs(settings.buttonColors) do
						if other ~= option then
							assert(found.style[other.property] == nil, "Colour setting changes another property")
						end
					end
					if option == settings.border then
						assert(found.style.borderImage.fileName == "::/gui/main/design/disk_mini_contour.tga")
					end
					if gameStylesheetUtil then
						assert(#found.levels == (option == settings.icon and 3 or 2))
						assert(found.levels[1].id == "menu.gamebar")
						assert(found.levels[2].classList[1] == settings.BUTTON_STYLE_CLASS)
						if state.id == "disabled" then
							assert(found.levels[2].pseudoClassList[1] == "disabled")
						else
							assert(
								found.levels[2].classList[2]
									== ((state.id == "normal" or state.id == "idleHover") and "unchecked" or "checked")
							)
						end
						if state.id == "idleHover" or state.id == "selectedHover" then
							assert(found.levels[2].pseudoClassList[1] == "hover")
						end
						if option == settings.icon then
							assert(found.levels[3].element == "ImageView")
							assert(#found.levels[3].pseudoClassList == 0)
						end
					end
				end
			end
		end
	end
end
local borderless = assert(bySelector[root .. "!" .. settings.styleClass(settings.border, "none") .. target])
assert(borderless.style.borderImage.fileName == "")
for channel = 1, 4 do
	assert(borderless.style.borderColor[channel] == defaultColors.Invisible[channel])
end
for _, option in ipairs({ settings.strip, settings.text }) do
	for _, choice in ipairs(option.choices) do
		if choice.gray ~= nil then
			local prefix = root .. "!" .. settings.styleClass(option, choice.id)
			local selectors = option == settings.strip and { prefix .. " R::GameBarBackground !bottom" }
				or {
					prefix .. " R::GameBarMenuMiddle R::GameBarInfoDisplay R::GameBarEarningsPlugin TextView",
					prefix .. " R::GameBarMenuMiddle R::GameBarInfoDisplay R::GameBarTransportedPlugin TextView",
				}
			for _, selector in ipairs(selectors) do
				local rule = assert(bySelector[selector])
				local color = rule.style[option == settings.strip and "backgroundColor" or "color"]
				assert(math.abs(color[1] - choice.gray / 255) < 1e-12)
			end
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
