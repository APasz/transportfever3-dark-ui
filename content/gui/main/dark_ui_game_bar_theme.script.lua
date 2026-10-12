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
	local react = ug_require("::/gui/main/react.lua")
	local gameBar = ug_require("::/gui/game_bar/game_bar.tl")
	local unpackValues = assert(table.unpack or unpack, "Dark UI requires a Lua unpack function")

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

	replacementApi.ReplaceRecipe(gameBar.GameBar, registerThemedGameBar())
	installed = true
end

function data()
	return {
		install = install,
	}
end
