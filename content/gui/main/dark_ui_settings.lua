local settings = {}
local uiTweaks = require("apasz_dark_ui_1::/gui/main/dark_ui_ui_tweaks.lua")

local SETTINGS_API_VERSION = uiTweaks.API_VERSION

settings.SECTION_ID = "apasz.dark_ui"
settings.RESOURCE_TYPE = uiTweaks.RESOURCE_TYPE
settings.VANILLA_CHOICE_ID = "vanilla"
settings.NONE_CHOICE_ID = "none"
settings.GAME_BAR_STYLE_CLASS = "dark-ui-game-bar"

local GRAY_LEVELS = {
	{ gray = 0, name = "Black" },
	{ gray = 25, name = "Onyx" },
	{ gray = 50, name = "Charcoal" },
	{ gray = 75, name = "Graphite" },
	{ gray = 100, name = "Slate" },
	{ gray = 125, name = "Pewter" },
	{ gray = 150, name = "Ash" },
	{ gray = 175, name = "Silver" },
	{ gray = 200, name = "Mist" },
	{ gray = 225, name = "Pearl" },
	{ gray = 255, name = "White" },
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
			id = "gray_" .. level.gray,
			label = level.name .. " (" .. level.gray .. ")",
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

settings.bulldozerStyle = {
	key = "game_bar_bulldozer_style",
	stateKey = "gameBarBulldozerStyle",
	classPrefix = "dark-ui-bulldozer-",
	label = "Bulldozer styling",
	kind = "dropdown",
	default = settings.VANILLA_CHOICE_ID,
	choices = {
		{
			id = settings.VANILLA_CHOICE_ID,
			label = "Vanilla",
			background = false,
			border = false,
			icon = false,
		},
		{
			id = "included",
			label = "Included",
			background = true,
			border = true,
			icon = true,
		},
		{
			id = "background_only",
			label = "Background only",
			background = true,
			border = false,
			icon = false,
		},
		{
			id = "border_only",
			label = "Border only",
			background = false,
			border = true,
			icon = false,
		},
		{
			id = "background_border",
			label = "Background + Border",
			background = true,
			border = true,
			icon = false,
		},
	},
}

settings.options = {
	settings.background,
	settings.border,
	settings.icon,
	settings.strip,
	settings.text,
	settings.stateContrast,
	settings.bulldozerStyle,
}

local settingKeys = {}
local styleClassesByOption = {}
local stateKeys = {}
local classPrefixes = {}
for _, option in ipairs(settings.options) do
	assert(type(option.key) == "string" and option.key ~= "", "Dark UI setting key is required")
	assert(type(option.stateKey) == "string" and option.stateKey ~= "", "Dark UI setting state key is required")
	assert(
		type(option.classPrefix) == "string" and option.classPrefix ~= "",
		"Dark UI setting class prefix is required"
	)
	assert(settingKeys[option.key] == nil, "Dark UI has duplicate setting key " .. option.key)
	assert(stateKeys[option.stateKey] == nil, "Dark UI has duplicate setting state key " .. option.stateKey)
	assert(
		classPrefixes[option.classPrefix] == nil,
		"Dark UI has duplicate setting class prefix " .. option.classPrefix
	)
	settingKeys[option.key] = true
	stateKeys[option.stateKey] = true
	classPrefixes[option.classPrefix] = true

	assert(option.kind == "dropdown", "Dark UI option " .. option.key .. " must be a dropdown")
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
		choicesById[choice.id] = option.classPrefix .. cssChoiceId
		cssChoiceIds[cssChoiceId] = true
	end
	assert(choicesById[option.default] ~= nil, "Dark UI has an invalid default for " .. option.key)
	styleClassesByOption[option] = choicesById
end

local function settingDefinition(option)
	local definition = {
		key = option.key,
		label = option.label,
		description = option.description,
		kind = option.kind,
		default = option.default,
	}
	definition.options = {}
	for _, choice in ipairs(option.choices) do
		definition.options[#definition.options + 1] = {
			id = choice.id,
			label = choice.label,
		}
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
	assert(type(option) == "table" and styleClassesByOption[option] ~= nil, "Dark UI setting option is not registered")
	local choicesById = styleClassesByOption[option]
	if choicesById[choiceId] ~= nil then
		return choicesById[choiceId]
	end
	error("Dark UI has an invalid " .. option.key .. ": " .. tostring(choiceId), 3)
end

function settings.styleClass(option, choiceId)
	return validateChoice(option, choiceId)
end

function settings.styleClasses(selected, scopeClass)
	assert(type(selected) == "table", "Dark UI settings must be a table")
	if scopeClass == nil then
		scopeClass = settings.GAME_BAR_STYLE_CLASS
	end
	assert(type(scopeClass) == "string" and scopeClass ~= "", "Dark UI style scope class is required")
	local classes = { scopeClass }
	for _, option in ipairs(settings.options) do
		local choiceId = selected[option.stateKey]
		classes[#classes + 1] = settings.styleClass(option, choiceId)
		if option.overrideClass ~= nil and choiceId ~= settings.VANILLA_CHOICE_ID then
			classes[#classes + 1] = option.overrideClass
		end
	end
	return classes
end

function settings.validate(selected)
	assert(type(selected) == "table", "Dark UI settings must be a table")
	for _, option in ipairs(settings.options) do
		validateChoice(option, selected[option.stateKey])
	end
end

return settings
