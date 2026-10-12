local uiTweaks = require("apasz_dark_ui_1::/gui/main/dark_ui_ui_tweaks.lua")
local installed = false

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

	local function interceptButton(name)
		local recipe = assert(builtin[name], "Dark UI could not find builtin." .. name)
		recipeComposition.interceptActive(recipe, name, function(renderOriginal)
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
				if params.meta and bulldozerIds[params.meta.id] then
					local included = reactSettings.useValue(settings.SECTION_ID, settings.includeBulldozer.key):old()
					assert(type(included) == "boolean", "Dark UI bulldozer inclusion must be a boolean")
					if not included then
						return renderOriginal(...)
					end
				end
				if hasClass(existingClass, settings.BUTTON_STYLE_CLASS) then
					return renderOriginal(...)
				end
				local configured = shallowCopy(params)
				configured.meta = shallowCopy(params.meta)
				configured.meta.class = existingClass
						and existingClass ~= ""
						and existingClass .. "," .. settings.BUTTON_STYLE_CLASS
					or settings.BUTTON_STYLE_CLASS
				local arguments = table.pack(...)
				arguments[count] = configured
				return renderOriginal(unpackValues(arguments, 1, count))
			end
		end)
	end

	local function useStyleClasses(scopeClass)
		local selected = {}
		for _, option in ipairs(settings.options) do
			selected[option.stateKey] = reactSettings.useValue(settings.SECTION_ID, option.key):old()
		end
		return settings.styleClasses(selected, scopeClass)
	end

	local function registerThemedGameBar()
		return recipeComposition.wrapActive(gameBar.GameBar, "GameBar", "DarkUiThemedGameBar", function(recipeChain)
			return function(param)
				assert(type(param) == "table", "Dark UI GameBar parameters must be a table")
				react.setStyleClasses(unpackValues(useStyleClasses(settings.GAME_BAR_STYLE_CLASS)))
				return recipeComposition.render(recipeChain, param)
			end
		end)
	end

	interceptButton("ToolButton")
	interceptButton("ToggleButton")
	replacementApi.ReplaceRecipe(gameBar.GameBar, registerThemedGameBar())
	installed = true
end

function data()
	return {
		install = install,
	}
end
