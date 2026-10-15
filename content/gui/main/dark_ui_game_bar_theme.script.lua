local uiTweaks = require("apasz_dark_ui_1::/gui/main/dark_ui_ui_tweaks.lua")
local installed = false
local TOGGLE_UNCHECKED = 0
local TOGGLE_CHECKED = 1
local LEFT_MOUSE_BUTTON = 0

local function install(replacementApi)
	if installed then
		return
	end
	if uiTweaks.requireSettings() == nil then
		return
	end
	assert(
		type(replacementApi) == "table" and type(replacementApi.ReplaceRecipe) == "function",
		"Dark UI requires the React replacement API"
	)

	local recipeComposition = require("apasz_ui_tweaks::/gui/ui_tweaks/recipe_composition.lua")
	local reactSettings = require("apasz_ui_tweaks::/gui/ui_tweaks/react_settings.lua")
	local settings = require("apasz_dark_ui_1::/gui/main/dark_ui_settings.lua")
	local storage = require("apasz_ui_tweaks::/gui/ui_tweaks/settings_storage.lua")
	local react = ug_require("::/gui/main/react.lua")
	local builtin = ug_require("::/gui/main/builtin.lua")
	local guiUtil = require("apasz_dark_ui_1::/gui/main/dark_ui_gui_util.lua")
	local styleutil = ug_require("::/gui/main/styleutil.tl")
	local gameBar = ug_require("::/gui/game_bar/game_bar.tl")
	local unpackValues = assert(table.unpack or unpack, "Dark UI requires a Lua unpack function")
	local toolButtonRecipes = {
		ManagerToolButton = true,
		ConstructionToolButton = true,
		MapEditorToolButton = true,
	}
	local bulldozerIds = {
		["menu.bulldozer"] = true,
		["menu.moduleBulldozer"] = true,
	}

	local function shallowCopy(source)
		local copy = {}
		for key, value in pairs(source or {}) do
			copy[key] = value
		end
		return copy
	end

	local persisted = storage.read()
	local storedValues = persisted.sections[settings.SECTION_ID]
	if storedValues ~= nil then
		local migrated = settings.migrateStoredValues(storedValues)
		if migrated ~= storedValues then
			local sections = shallowCopy(persisted.sections)
			sections[settings.SECTION_ID] = migrated
			storage.saveSections(sections)
		end
	end

	local function hasClass(classes, expected)
		if classes == nil then
			return false
		end
		assert(type(classes) == "string", "Dark UI received invalid button style classes")
		for className in classes:gmatch("[^,%s]+") do
			if className == expected then
				return true
			end
		end
		return false
	end

	-- Submit an empty sheet to clear overrides on reused native components.
	local vanillaInlineStyle = api.gui.StyleSheet.new()

	local function makeInlineButtonStyleCache()
		local function newBorderCache()
			return { byBorderGray = {}, byBorderMode = {} }
		end
		local withoutBackground = newBorderCache()
		local byBackgroundGray = {}
		local borderImage = api.gui.NinePatch.new()
		borderImage.fileName = settings.border.imageFile
		local noBorderImage = api.gui.NinePatch.new()
		noBorderImage.fileName = ""
		local colorsResource = "::/gui/main/default_colors.gres"
		local noBorderColor =
			guiUtil.validateColor(guiUtil.getResource(colorsResource).Invisible, colorsResource .. ".Invisible")
		return function(backgroundGray, borderChoiceId, borderGray)
			if backgroundGray == nil and borderChoiceId == settings.VANILLA_CHOICE_ID then
				return vanillaInlineStyle
			end
			local cache = withoutBackground
			if backgroundGray ~= nil then
				cache = byBackgroundGray[backgroundGray]
				if cache == nil then
					cache = newBorderCache()
					byBackgroundGray[backgroundGray] = cache
				end
			end
			local borderCache, borderKey
			if borderGray ~= nil then
				borderCache, borderKey = cache.byBorderGray, borderGray
			else
				borderCache, borderKey = cache.byBorderMode, borderChoiceId
			end
			local style = borderCache[borderKey]
			if style == nil then
				local colors = {}
				if backgroundGray ~= nil then
					colors.backgroundColor1 = guiUtil.grayColor(backgroundGray)
				end
				if borderChoiceId == settings.NONE_CHOICE_ID then
					colors.borderColor = noBorderColor
				elseif borderGray ~= nil then
					colors.borderColor = guiUtil.grayColor(borderGray)
				end
				style = styleutil.makeStyle(colors)
				if borderChoiceId ~= settings.VANILLA_CHOICE_ID then
					style.borderImage = borderChoiceId == settings.NONE_CHOICE_ID and noBorderImage or borderImage
				end
				borderCache[borderKey] = style
			end
			return style
		end
	end

	local function makeInlineIconStyler()
		local stylesByGray = {}
		local imagesByContext = setmetatable({}, { __mode = "k" })
		recipeComposition.interceptActive(builtin.ImageView, "ImageView", function(renderOriginal)
			return function(...)
				local context = react.getCallingRecipeCtx()
				local images = imagesByContext[context]
				if images == nil then
					images = { hasInlineStyleByNode = {}, cleanupPending = false }
					images.clear = function()
						for node in pairs(images.hasInlineStyleByNode) do
							images.hasInlineStyleByNode[node] = nil
						end
						images.cleanupPending = false
					end
					imagesByContext[context] = images
				end
				-- Image counts can change before a recipe's own hooks. Track no hook state here.
				if not images.cleanupPending then
					images.cleanupPending = true
					react.enqueueJoin(images.clear, "Dark UI icon tracking")
				end
				local count = select("#", ...)
				local params = count > 0 and select(count, ...) or nil
				local node = renderOriginal(...)
				if node ~= nil then
					images.hasInlineStyleByNode[node] = type(params) == "table"
						and params.meta ~= nil
						and params.meta.styleSheet ~= nil
				end
				return node
			end
		end)

		return function(content, gray)
			local images = imagesByContext[react.getCallingRecipeCtx()]
			local hasInlineStyle = images and images.hasInlineStyleByNode[content]
			if hasInlineStyle == nil then
				-- Tinting an unknown content container could also recolour text.
				return content
			end
			if gray == nil and hasInlineStyle then
				return content
			end
			assert(not hasInlineStyle, "Dark UI icon styling cannot merge an existing inline stylesheet")
			local style = gray == nil and vanillaInlineStyle or stylesByGray[gray]
			if style == nil then
				style = styleutil.makeStyle({ color = guiUtil.grayColor(gray) })
				stylesByGray[gray] = style
			end
			return builtin.WithComponentParams({ item = content, styleSheet = style })
		end
	end

	local getInlineButtonStyle = makeInlineButtonStyleCache()
	local styleInlineIcon = makeInlineIconStyler()
	local function makeInlineButtonStyle(name, renderOriginal)
		local mouseEvents = api.gui.mouse.Event.Type
		local isToolButton = name == "ToolButton"
		local function toggleChecked(value)
			assert(value == TOGGLE_UNCHECKED or value == TOGGLE_CHECKED, "Dark UI received an invalid toggle value")
			return value == TOGGLE_CHECKED
		end

		-- Content nodes belong to the calling recipe; keep construction in that context.
		return function(arguments, applyOverrides)
			local params = arguments[arguments.n]
			local meta = params.meta or {}
			local initialValue = params.value
			if initialValue == nil then
				initialValue = params.initialValue
			end
			if initialValue == nil then
				initialValue = TOGGLE_UNCHECKED
			end
			local checked = react.useState(not isToolButton and toggleChecked(initialValue))
			local attention = react.useState(false)
			local pressed = react.useState(false)
			local buttonRef = react.useNodeRef()
			local backgroundChoiceId = reactSettings.useValue(settings.SECTION_ID, settings.background.key):old()
			local borderChoiceId = reactSettings.useValue(settings.SECTION_ID, settings.border.key):old()
			local iconChoiceId = reactSettings.useValue(settings.SECTION_ID, settings.icon.key):old()
			if not applyOverrides then
				backgroundChoiceId, borderChoiceId, iconChoiceId =
					settings.VANILLA_CHOICE_ID, settings.VANILLA_CHOICE_ID, settings.VANILLA_CHOICE_ID
			end
			local contrastId = reactSettings.useValue(settings.SECTION_ID, settings.stateContrast.key):old()
			if isToolButton then
				react.onStep(function()
					local stack = params.toolStack and params.toolStack:get()
					local stackApi = stack and stack:getApi()
					local activeTool, variant
					if stackApi ~= nil then
						activeTool, variant = stackApi.getActiveTool()
					end
					local matches = activeTool ~= nil
						and (activeTool == params.toolDefinition or activeTool.name == params.toolName)
						and (params.toolVariant == nil or params.toolVariant == variant)
					checked:set(matches)
				end)
			end
			local previousMouseListener = react.getCallingRecipeCtx():useComponentInternals().mouseListener
			react.onMouseEvent(function(event)
				if event.button == LEFT_MOUSE_BUTTON then
					if event.type == mouseEvents.Pressed then
						local button = buttonRef:get()
						if button ~= nil and button:containsPosition(api.type.Vec2i.new(event.x, event.y)) then
							pressed:set(true)
						end
					elseif event.type == mouseEvents.Released or event.type == mouseEvents.PressedOutside then
						pressed:set(false)
					end
				end
				if previousMouseListener ~= nil then
					return previousMouseListener(event)
				end
				return false
			end)

			local configured = shallowCopy(params)
			configured.meta = shallowCopy(meta)
			configured.meta.onAttention = function(value)
				assert(type(value) == "boolean", "Dark UI attention state must be a boolean")
				attention:set(value)
				if meta.onAttention ~= nil then
					meta.onAttention(value)
				end
			end
			if not isToolButton then
				configured.onValueChange = function(value)
					checked:set(toggleChecked(value))
					if params.onValueChange ~= nil then
						params.onValueChange(value)
					end
				end
			end
			local isChecked = checked:old()
			if not isToolButton and params.value ~= nil then
				isChecked = toggleChecked(params.value)
			end
			assert(
				meta.enabled == nil or type(meta.enabled) == "boolean",
				"Dark UI button enabled state must be a boolean"
			)
			local stateId
			if meta.enabled == false then
				stateId = "disabled"
			elseif attention:old() and not pressed:old() then
				stateId = isChecked and "selectedHover" or "idleHover"
			else
				stateId = isChecked and "selected" or "normal"
			end
			local backgroundGray = settings.colorGray(settings.background, backgroundChoiceId, contrastId, stateId)
			local borderGray = settings.colorGray(settings.border, borderChoiceId, contrastId, stateId)
			local hasButtonOverride = backgroundGray ~= nil or borderChoiceId ~= settings.VANILLA_CHOICE_ID
			if hasButtonOverride then
				assert(meta.styleSheet == nil, "Dark UI button styling cannot merge an existing inline stylesheet")
			end
			if meta.styleSheet == nil then
				configured.meta.styleSheet = getInlineButtonStyle(backgroundGray, borderChoiceId, borderGray)
			end
			local iconGray = settings.colorGray(settings.icon, iconChoiceId, contrastId, stateId)
			configured.content = styleInlineIcon(params.content, iconGray)
			arguments[arguments.n] = configured
			local hasReference = false
			for index = 1, math.min(2, arguments.n - 1) do
				local argument = arguments[index]
				if type(argument) == "table" and argument.is_react_ref_info then
					local references = {}
					if type(argument.data) == "table" then
						for _, reference in ipairs(argument.data) do
							references[#references + 1] = reference
						end
					else
						references[1] = argument.data
					end
					references[#references + 1] = buttonRef
					arguments[index] = react.ref(references)
					hasReference = true
					break
				end
			end
			if not hasReference then
				table.insert(arguments, 1, react.ref({ buttonRef }))
				arguments.n = arguments.n + 1
			end
			return renderOriginal(unpackValues(arguments, 1, arguments.n))
		end
	end

	local function interceptButton(name)
		local recipe = assert(builtin[name], "Dark UI could not find builtin." .. name)
		recipeComposition.interceptActive(recipe, name, function(renderOriginal)
			local inlineStyle = makeInlineButtonStyle(name, renderOriginal)
			return function(...)
				local count = select("#", ...)
				local params = count > 0 and select(count, ...) or nil
				if type(params) ~= "table" then
					return renderOriginal(...)
				end
				local existingClass = params.meta and params.meta.class
				if existingClass == nil then
					for index = 1, math.min(2, count - 1) do
						local argument = select(index, ...)
						if type(argument) == "table" and argument.is_react_style_info then
							existingClass = argument.data.class
						end
					end
				end
				local parent = react.getCurrentRecipeName()
				local targeted = name == "ToolButton" and toolButtonRecipes[parent] == true
					or name == "ToggleButton" and (parent == "NodeEditorButton" or hasClass(existingClass, "extra"))
				if not targeted then
					return renderOriginal(...)
				end
				local included = true
				if params.meta and bulldozerIds[params.meta.id] then
					included = reactSettings.useValue(settings.SECTION_ID, settings.includeBulldozer.key):old()
					assert(type(included) == "boolean", "Dark UI bulldozer inclusion must be a boolean")
				end
				local arguments = table.pack(...)
				return inlineStyle(arguments, included)
			end
		end)
	end

	local function interceptInlineStrip()
		local stylesByChoice = { [settings.VANILLA_CHOICE_ID] = vanillaInlineStyle }
		for _, choice in ipairs(settings.strip.choices) do
			if choice.gray ~= nil then
				stylesByChoice[choice.id] = styleutil.makeStyle({ backgroundColor = guiUtil.grayColor(choice.gray) })
			end
		end

		recipeComposition.interceptActive(builtin.Component, "Component", function(renderOriginal)
			return function(...)
				local count = select("#", ...)
				local params = count > 0 and select(count, ...) or nil
				if
					react.getCurrentRecipeName() ~= "GameBarBackground"
					or type(params) ~= "table"
					or type(params.meta) ~= "table"
					or params.meta.id ~= "menu.gamebar.bottom"
				then
					return renderOriginal(...)
				end

				local choiceId = reactSettings.useValue(settings.SECTION_ID, settings.strip.key):old()
				if choiceId == settings.VANILLA_CHOICE_ID and params.meta.styleSheet ~= nil then
					return renderOriginal(...)
				end
				local style = assert(stylesByChoice[choiceId], "Dark UI received an invalid inline strip colour")
				assert(
					params.meta.styleSheet == nil,
					"Dark UI strip styling cannot merge an existing inline stylesheet"
				)
				local configured = shallowCopy(params)
				configured.meta = shallowCopy(params.meta)
				configured.meta.styleSheet = style
				local arguments = table.pack(...)
				arguments[count] = configured
				return renderOriginal(unpackValues(arguments, 1, count))
			end
		end)
	end

	local function registerThemedGameBar()
		return recipeComposition.wrapActive(gameBar.GameBar, "GameBar", "DarkUiThemedGameBar", function(recipeChain)
			return function(param)
				assert(type(param) == "table", "Dark UI GameBar parameters must be a table")
				local choiceId = reactSettings.useValue(settings.SECTION_ID, settings.text.key):old()
				react.setStyleClasses(unpackValues(settings.textStyleClasses(choiceId)))
				return recipeComposition.render(recipeChain, param)
			end
		end)
	end

	interceptButton("ToolButton")
	interceptButton("ToggleButton")
	interceptInlineStrip()
	replacementApi.ReplaceRecipe(gameBar.GameBar, registerThemedGameBar())
	installed = true
end

function data()
	return {
		install = install,
	}
end
