local settings = {}
local uiTweaks = require("apasz_dark_ui_1::/gui/main/dark_ui_ui_tweaks.lua")
local palette = require("apasz_dark_ui_1::/gui/main/dark_ui_palette.lua")

local SETTINGS_API_VERSION = uiTweaks.API_VERSION

settings.SECTION_ID = "apasz.dark_ui"
settings.RESOURCE_TYPE = uiTweaks.RESOURCE_TYPE
settings.VANILLA_CHOICE_ID = "vanilla"
settings.NONE_CHOICE_ID = "none"
settings.GAME_BAR_STYLE_CLASS = "dark-ui-game-bar"

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
	label = "Game bar background",
	kind = "dropdown",
	default = settings.VANILLA_CHOICE_ID,
	description = "Built-in game bar buttons only; mod toolbar backgrounds use standard styling like the Layers button.",
	choices = makeColorChoices(false),
	stateful = true,
}

settings.border = {
	key = "game_bar_border_color",
	label = "Game bar border",
	kind = "dropdown",
	default = settings.VANILLA_CHOICE_ID,
	description = "Built-in buttons only. None removes the ring; Vanilla preserves the game's border styling.",
	choices = makeColorChoices(true),
	stateful = true,
	imageFile = "::/gui/main/design/disk_mini_contour.tga",
}

settings.icon = {
	key = "game_bar_icon_color",
	label = "Game bar icons",
	kind = "dropdown",
	default = settings.VANILLA_CHOICE_ID,
	description = "Applies to built-in and mod toolbar icons.",
	choices = makeColorChoices(false),
	stateful = true,
}

settings.strip = {
	key = "game_bar_strip_color",
	label = "Game bar strip",
	kind = "dropdown",
	default = settings.VANILLA_CHOICE_ID,
	choices = makeColorChoices(false),
}

settings.text = {
	key = "game_bar_text_color",
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
	{ id = "normal" },
	{ id = "selected", offsetKey = "selectedOffset" },
	{ id = "idleHover", offsetKey = "hoverOffset" },
	{ id = "selectedHover", offsetKey = "selectedHoverOffset" },
	{ id = "disabled", scaleKey = "disabledScale" },
}

local settingKeys = {}
local choicesByOption = {}
local classPrefixes = {}
for _, option in ipairs(settings.options) do
	assert(type(option.key) == "string" and option.key ~= "", "Dark UI setting key is required")
	assert(settingKeys[option.key] == nil, "Dark UI has duplicate setting key " .. option.key)
	settingKeys[option.key] = true
	if option.kind == "toggle" then
		assert(type(option.default) == "boolean", "Dark UI toggle default must be a boolean")
		choicesByOption[option] = {}
	else
		assert(option.kind == "dropdown", "Unsupported Dark UI option kind " .. tostring(option.kind))
		if option.classPrefix ~= nil then
			assert(
				type(option.classPrefix) == "string" and option.classPrefix ~= "",
				"Dark UI setting class prefix is required"
			)
			assert(
				classPrefixes[option.classPrefix] == nil,
				"Dark UI has duplicate setting class prefix " .. option.classPrefix
			)
			classPrefixes[option.classPrefix] = true
		end
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
			if option.classPrefix ~= nil then
				local cssChoiceId = choice.id:gsub("[^a-z0-9-]", "-")
				assert(
					cssChoiceIds[cssChoiceId] == nil,
					"Dark UI has colliding CSS choice ids for " .. option.key .. ": " .. choice.id
				)
				choice.styleClass = option.classPrefix .. cssChoiceId
				cssChoiceIds[cssChoiceId] = true
			end
			choicesById[choice.id] = choice
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
		if option.stateful then
			assert(colorOptions[option], "Invalid Dark UI button colour option")
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

local colorStatesById = {}
for _, state in ipairs(settings.colorStates) do
	colorStatesById[state.id] = state
end

function settings.colorGray(option, choiceId, contrastId, stateId)
	local choice = validateChoice(option, choiceId)
	assert(option.stateful == true, "Dark UI state colours require a button colour option")
	local contrast = validateChoice(settings.stateContrast, contrastId)
	local state = assert(colorStatesById[stateId], "Invalid Dark UI colour state " .. tostring(stateId))
	if choice.gray == nil then
		return nil
	end
	local gray = choice.gray
	if state.scaleKey then
		gray = gray * assert(contrast[state.scaleKey], "Missing state contrast scale " .. state.scaleKey)
	elseif state.offsetKey then
		gray = gray + assert(contrast[state.offsetKey], "Missing state contrast offset " .. state.offsetKey)
	end
	return math.max(0, math.min(255, gray))
end

function settings.textStyleClasses(choiceId)
	local choice = validateChoice(settings.text, choiceId)
	local classes = { settings.GAME_BAR_STYLE_CLASS, choice.styleClass }
	if choiceId ~= settings.VANILLA_CHOICE_ID then
		classes[#classes + 1] = settings.text.overrideClass
	end
	return classes
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
