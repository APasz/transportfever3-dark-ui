local settings = {}
local uiTweaks = require("apasz_dark_ui_1::/gui/main/dark_ui_ui_tweaks.lua")
local palette = require("apasz_dark_ui_1::/gui/main/dark_ui_palette.lua")

local SETTINGS_API_VERSION = uiTweaks.API_VERSION

settings.SECTION_ID = "apasz.dark_ui"
settings.RESOURCE_TYPE = uiTweaks.RESOURCE_TYPE
settings.VANILLA_CHOICE_ID = "vanilla"
settings.NONE_CHOICE_ID = "none"
settings.GAME_BAR_STYLE_CLASS = "dark-ui-game-bar"
settings.BUTTON_STYLE_CLASS = "dark-ui-game-bar-button"

local GRAY_LEVELS = {
	{ id = "black", gray = 0, name = "Black" },
	{ id = "dark_gray", gray = palette.darkGray * 255, name = "Dark grey" },
	{ id = "gray", gray = 128, name = "Grey" },
	{ id = "light_gray", gray = 192, name = "Light grey" },
	{ id = "white", gray = 255, name = "White" },
}

local function makeColorChoices(includeNone)
	local choices = {
		{ id = settings.VANILLA_CHOICE_ID, label = "Vanilla" },
	}
	if includeNone then
		choices[#choices + 1] = {
			id = settings.NONE_CHOICE_ID,
			label = "None",
		}
	end
	for _, level in ipairs(GRAY_LEVELS) do
		choices[#choices + 1] = {
			id = level.id,
			label = level.name,
			gray = level.gray,
		}
	end
	return choices
end

settings.background = {
	key = "game_bar_background_color",
	stateKey = "gameBarBackgroundColor",
	classPrefix = "dark-ui-background-",
	overrideClass = "dark-ui-override-background",
	label = "Game bar background",
	kind = "dropdown",
	default = settings.VANILLA_CHOICE_ID,
	choices = makeColorChoices(false),
	property = "backgroundColor1",
	child = "",
}

settings.border = {
	key = "game_bar_border_color",
	stateKey = "gameBarBorderColor",
	classPrefix = "dark-ui-border-",
	overrideClass = "dark-ui-override-border",
	label = "Game bar border",
	kind = "dropdown",
	default = settings.VANILLA_CHOICE_ID,
	description = "None forcibly removes the ring; Vanilla preserves the game's border styling.",
	choices = makeColorChoices(true),
	property = "borderColor",
	child = "",
}

settings.icon = {
	key = "game_bar_icon_color",
	stateKey = "gameBarIconColor",
	classPrefix = "dark-ui-icon-",
	overrideClass = "dark-ui-override-icon",
	label = "Game bar icons",
	kind = "dropdown",
	default = settings.VANILLA_CHOICE_ID,
	choices = makeColorChoices(false),
	property = "color",
	child = " ImageView",
}

settings.strip = {
	key = "game_bar_strip_color",
	stateKey = "gameBarStripColor",
	classPrefix = "dark-ui-strip-",
	label = "Game bar strip",
	kind = "dropdown",
	default = settings.VANILLA_CHOICE_ID,
	choices = makeColorChoices(false),
}

settings.text = {
	key = "game_bar_text_color",
	stateKey = "gameBarTextColor",
	classPrefix = "dark-ui-text-",
	overrideClass = "dark-ui-override-text",
	label = "Built-in game bar info text",
	description = "Styles Earnings and Transported while preserving semantic and third-party plugin colours.",
	kind = "dropdown",
	default = settings.VANILLA_CHOICE_ID,
	choices = makeColorChoices(false),
}

settings.stateContrast = {
	key = "game_bar_state_contrast",
	stateKey = "gameBarStateContrast",
	classPrefix = "dark-ui-state-contrast-",
	label = "Game bar state contrast",
	description = "Controls the difference between normal, selected, hovered, and disabled button colours.",
	kind = "dropdown",
	default = "standard",
	choices = {
		{
			id = "subtle",
			label = "Subtle",
			selectedOffset = 10,
			hoverOffset = 20,
			selectedHoverOffset = 30,
			disabledScale = 0.7,
		},
		{
			id = "standard",
			label = "Standard",
			selectedOffset = 15,
			hoverOffset = 30,
			selectedHoverOffset = 45,
			disabledScale = 0.5,
		},
		{
			id = "strong",
			label = "Strong",
			selectedOffset = 25,
			hoverOffset = 50,
			selectedHoverOffset = 75,
			disabledScale = 0.3,
		},
	},
}

settings.includeBulldozer = {
	key = "game_bar_include_bulldozer",
	stateKey = "gameBarIncludeBulldozer",
	label = "Include bulldozer buttons",
	description = "Apply game bar button colours to both bulldozers; off preserves their existing styling.",
	kind = "toggle",
	default = false,
}

settings.options = {
	settings.background,
	settings.border,
	settings.icon,
	settings.strip,
	settings.text,
	settings.stateContrast,
	settings.includeBulldozer,
}

settings.buttonColors = {}
local colorOptions = {}
settings.colorStates = {
	{ id = "normal", selector = "!unchecked" },
	{ id = "selected", selector = "!checked", offsetKey = "selectedOffset" },
	{ id = "idleHover", selector = "!unchecked:hover", offsetKey = "hoverOffset" },
	{ id = "selectedHover", selector = "!checked:hover", offsetKey = "selectedHoverOffset" },
	{ id = "disabled", selector = ":disabled", scaleKey = "disabledScale" },
}

local settingKeys = {}
local choicesByOption = {}
local stateKeys = {}
local classPrefixes = {}
for _, option in ipairs(settings.options) do
	assert(type(option.key) == "string" and option.key ~= "", "Dark UI setting key is required")
	assert(type(option.stateKey) == "string" and option.stateKey ~= "", "Dark UI setting state key is required")
	assert(settingKeys[option.key] == nil, "Dark UI has duplicate setting key " .. option.key)
	assert(stateKeys[option.stateKey] == nil, "Dark UI has duplicate setting state key " .. option.stateKey)
	settingKeys[option.key] = true
	stateKeys[option.stateKey] = true
	if option.kind == "toggle" then
		assert(type(option.default) == "boolean", "Dark UI toggle default must be a boolean")
		choicesByOption[option] = {}
	else
		assert(option.kind == "dropdown", "Unsupported Dark UI option kind " .. tostring(option.kind))
		assert(
			type(option.classPrefix) == "string" and option.classPrefix ~= "",
			"Dark UI setting class prefix is required"
		)
		assert(
			classPrefixes[option.classPrefix] == nil,
			"Dark UI has duplicate setting class prefix " .. option.classPrefix
		)
		classPrefixes[option.classPrefix] = true
		assert(type(option.choices) == "table", "Dark UI dropdown " .. option.key .. " has no choices")
		local choicesById = {}
		local cssChoiceIds = {}
		for _, choice in ipairs(option.choices) do
			assert(type(choice.id) == "string" and choice.id ~= "", "Dark UI choice id is required for " .. option.key)
			assert(
				type(choice.label) == "string" and choice.label ~= "",
				"Dark UI choice label is required for " .. option.key
			)
			assert(choicesById[choice.id] == nil, "Dark UI has duplicate choice " .. choice.id .. " for " .. option.key)
			local cssChoiceId = choice.id:gsub("[^a-z0-9-]", "-")
			assert(
				cssChoiceIds[cssChoiceId] == nil,
				"Dark UI has colliding CSS choice ids for " .. option.key .. ": " .. choice.id
			)
			choice.styleClass = option.classPrefix .. cssChoiceId
			choicesById[choice.id] = choice
			cssChoiceIds[cssChoiceId] = true
			if choice.gray ~= nil then
				assert(
					type(choice.gray) == "number" and choice.gray >= 0 and choice.gray <= 255,
					"Invalid Dark UI grey level"
				)
				colorOptions[option] = true
			end
		end
		assert(choicesById[option.default] ~= nil, "Dark UI has an invalid default for " .. option.key)
		choicesByOption[option] = choicesById
		if option.property ~= nil then
			assert(colorOptions[option] and type(option.child) == "string", "Invalid Dark UI button colour option")
			settings.buttonColors[#settings.buttonColors + 1] = option
		end
	end
end

local function settingDefinition(option)
	local definition = {
		key = option.key,
		label = option.label,
		description = option.description,
		kind = option.kind,
		default = option.default,
	}
	if option.kind == "dropdown" then
		definition.options = {}
		for _, choice in ipairs(option.choices) do
			definition.options[#definition.options + 1] = {
				id = choice.id,
				label = choice.label,
			}
		end
	end
	return definition
end

local sectionSettings = {}
for _, option in ipairs(settings.options) do
	sectionSettings[#sectionSettings + 1] = settingDefinition(option)
end

settings.section = {
	apiVersion = SETTINGS_API_VERSION,
	id = settings.SECTION_ID,
	title = "Dark UI",
	order = 100,
	settings = sectionSettings,
}

local function validateChoice(option, choiceId)
	assert(type(option) == "table" and choicesByOption[option] ~= nil, "Dark UI setting option is not registered")
	assert(option.kind == "dropdown", "Dark UI style choices require a dropdown")
	local choicesById = choicesByOption[option]
	if choicesById[choiceId] ~= nil then
		return choicesById[choiceId]
	end
	error("Dark UI has an invalid " .. option.key .. ": " .. tostring(choiceId), 3)
end

function settings.styleClass(option, choiceId)
	return validateChoice(option, choiceId).styleClass
end

local function stateGray(gray, state, contrast)
	if state.scaleKey then
		gray = gray * assert(contrast[state.scaleKey], "Missing state contrast scale " .. state.scaleKey)
	elseif state.offsetKey then
		gray = gray + assert(contrast[state.offsetKey], "Missing state contrast offset " .. state.offsetKey)
	end
	return math.max(0, math.min(255, gray))
end

local colorRulesByOption = {}
local colorClassesByOption = {}
for _, option in ipairs(settings.buttonColors) do
	local rules = {}
	local classesByChoice = {}
	local seenClasses = {}
	for _, choice in ipairs(option.choices) do
		if choice.gray ~= nil then
			local classesByContrast = {}
			for _, contrast in ipairs(settings.stateContrast.choices) do
				local classes = {}
				for _, state in ipairs(settings.colorStates) do
					local value = stateGray(choice.gray, state, contrast)
					local className = option.classPrefix
						.. state.id
						.. "-"
						.. string.format("%.3f", value):gsub("%.", "-")
					classes[#classes + 1] = className
					if not seenClasses[className] then
						rules[#rules + 1] = { state = state, gray = value, className = className }
						seenClasses[className] = true
					end
				end
				classesByContrast[contrast.id] = classes
			end
			classesByChoice[choice.id] = classesByContrast
		end
	end
	colorRulesByOption[option] = rules
	colorClassesByOption[option] = classesByChoice
end

function settings.colorRules(option)
	return assert(colorRulesByOption[option], "Dark UI colour option is not registered")
end

function settings.styleClasses(selected, scopeClass)
	assert(type(selected) == "table", "Dark UI settings must be a table")
	if scopeClass == nil then
		scopeClass = settings.GAME_BAR_STYLE_CLASS
	end
	assert(type(scopeClass) == "string" and scopeClass ~= "", "Dark UI style scope class is required")
	settings.validate(selected)
	local classes = { scopeClass }
	for _, option in ipairs(settings.options) do
		local choiceId = selected[option.stateKey]
		if option.kind == "dropdown" then
			classes[#classes + 1] = settings.styleClass(option, choiceId)
			if option.overrideClass ~= nil and choiceId ~= settings.VANILLA_CHOICE_ID then
				classes[#classes + 1] = option.overrideClass
			end
			local colorClasses = colorClassesByOption[option]
			local byContrast = colorClasses and colorClasses[choiceId]
			if byContrast then
				for _, className in ipairs(byContrast[selected[settings.stateContrast.stateKey]]) do
					classes[#classes + 1] = className
				end
			end
		end
	end
	return classes
end

function settings.validate(selected)
	assert(type(selected) == "table", "Dark UI settings must be a table")
	for _, option in ipairs(settings.options) do
		if option.kind == "toggle" then
			assert(type(selected[option.stateKey]) == "boolean", "Dark UI " .. option.key .. " must be a boolean")
		else
			validateChoice(option, selected[option.stateKey])
		end
	end
end

local LEGACY_BULLDOZER_CHOICES = {
	vanilla = false,
	included = true,
	background_only = true,
	border_only = true,
	background_border = true,
}

local function migrateColor(choiceId)
	local grayText = type(choiceId) == "string" and choiceId:match("^gray_(%d+)$")
	local gray = grayText and tonumber(grayText)
	assert(
		gray and (gray == 255 or gray <= 225 and gray % 25 == 0),
		"Invalid legacy Dark UI colour " .. tostring(choiceId)
	)
	local nearest = GRAY_LEVELS[1]
	for _, level in ipairs(GRAY_LEVELS) do
		if math.abs(level.gray - gray) < math.abs(nearest.gray - gray) then
			nearest = level
		end
	end
	return nearest.id
end

function settings.migrateStoredValues(stored)
	assert(type(stored) == "table", "Dark UI persisted settings must be a table")
	local migrated
	local function replace(key, value)
		if migrated == nil then
			migrated = {}
			for storedKey, storedValue in pairs(stored) do
				migrated[storedKey] = storedValue
			end
		end
		migrated[key] = value
	end
	for _, option in ipairs(settings.options) do
		local value = stored[option.key]
		if value ~= nil then
			if option.kind == "toggle" then
				assert(type(value) == "boolean", "Dark UI persisted toggle must be a boolean")
			elseif choicesByOption[option][value] == nil then
				assert(colorOptions[option], "Invalid persisted Dark UI choice " .. tostring(value))
				replace(option.key, migrateColor(value))
			end
		end
	end
	local legacyBulldozer = stored.game_bar_bulldozer_style
	if stored[settings.includeBulldozer.key] == nil and legacyBulldozer ~= nil then
		local included = LEGACY_BULLDOZER_CHOICES[legacyBulldozer]
		assert(type(included) == "boolean", "Invalid legacy Dark UI bulldozer choice " .. tostring(legacyBulldozer))
		replace(settings.includeBulldozer.key, included)
	end
	return migrated or stored
end

return settings
