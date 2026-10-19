dofile("../tools/localization_fixture.lua")

local SETTINGS_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/settings.lua"
local COMPOSITION_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/recipe_composition.lua"
local REACT_SETTINGS_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/react_settings.lua"
local STORAGE_MODULE = "apasz_ui_tweaks::/gui/ui_tweaks/settings_storage.lua"
local INTEGRATION_MODULE = "apasz_dark_ui_1::/gui/main/dark_ui_ui_tweaks.lua"

local function unused()
	error("Incompatible UIT integration changed the UI or settings")
end

local function newFixture()
	local fixture = {
		available = true,
		warnings = {},
		required = {},
		modules = {
			[SETTINGS_MODULE] = { API_VERSION = 1, RESOURCE_TYPE = "ui-tweaks-settings" },
			[COMPOSITION_MODULE] = { interceptActive = unused, wrapActive = unused, render = unused },
			[REACT_SETTINGS_MODULE] = { useValue = unused },
			[STORAGE_MODULE] = { read = unused, saveSections = unused },
		},
	}
	local loader = dofile("tests/ui_tweaks_loader.lua")
	local environment = setmetatable({
		api = {
			res = {
				genericRep = {
					find = function()
						return fixture.available and 201 or -1
					end,
				},
			},
		},
		log = {
			warning = function(message)
				fixture.warnings[#fixture.warnings + 1] = message
			end,
		},
		resolveutil = {
			loadfile = function(path)
				if path == fixture.missingPath then
					return nil, "Could not find file " .. path
				end
				if path == fixture.invalidPath then
					return nil, "invalid Lua syntax"
				end
				return loader.loadfile(path)
			end,
		},
		ug_require = unused,
	}, { __index = _G })
	environment.require = function(path)
		if path == INTEGRATION_MODULE then
			return fixture.integration
		end
		assert(path ~= fixture.missingPath, "Attempted require of missing module: " .. path)
		fixture.required[path] = true
		if path == fixture.brokenPath then
			error("dependency runtime error", 0)
		end
		return assert(fixture.modules[path], "Unexpected dependency: " .. path)
	end
	fixture.integration = assert(loadfile("content/gui/main/dark_ui_ui_tweaks.lua", "t", environment))()
	assert(loadfile("content/gui/main/dark_ui_game_bar_theme.script.lua", "t", environment))()
	fixture.theme = environment.data()
	return fixture
end

local function assertSkipped(fixture, expectedWarning)
	fixture.theme.install({ ReplaceRecipe = unused })
	fixture.theme.install({ ReplaceRecipe = unused })
	assert(#fixture.warnings == 1, "Compatibility warning must be logged once")
	assert(fixture.warnings[1]:find(expectedWarning, 1, true))
	assert(fixture.warnings[1]:find("Update or reinstall UI Tweaks and Dark UI together.", 1, true))
end

local absent = newFixture()
absent.available = false
absent.theme.install({ ReplaceRecipe = unused })
assert(next(absent.required) == nil and #absent.warnings == 0)

for _, path in ipairs({ COMPOSITION_MODULE, REACT_SETTINGS_MODULE, STORAGE_MODULE }) do
	local missing = newFixture()
	missing.missingPath = path
	assertSkipped(missing, "UI Tweaks is missing " .. path)
	assert(not missing.required[path], "Missing module entered the game loader")
end

local requiredFunctions = {
	[COMPOSITION_MODULE] = { "interceptActive", "wrapActive", "render" },
	[REACT_SETTINGS_MODULE] = { "useValue" },
	[STORAGE_MODULE] = { "read", "saveSections" },
}
for path, functions in pairs(requiredFunctions) do
	for _, name in ipairs(functions) do
		local old = newFixture()
		old.modules[path][name] = nil
		assertSkipped(old, "UI Tweaks does not provide " .. path .. ": " .. name)
	end
end

local function assertError(fixture, expected)
	local ok, message = pcall(fixture.theme.install, { ReplaceRecipe = unused })
	assert(not ok and message:find(expected, 1, true), tostring(message))
	assert(#fixture.warnings == 0, "An invalid module was treated as an older UIT version")
end

local invalidSyntax = newFixture()
invalidSyntax.invalidPath = COMPOSITION_MODULE
assertError(invalidSyntax, "invalid Lua syntax")
assert(not invalidSyntax.required[COMPOSITION_MODULE])

local broken = newFixture()
broken.brokenPath = COMPOSITION_MODULE
assertError(broken, "dependency runtime error")

local invalidModule = newFixture()
invalidModule.modules[COMPOSITION_MODULE] = true
assertError(invalidModule, "Dark UI received an invalid UI Tweaks module")

local invalidFunction = newFixture()
invalidFunction.modules[COMPOSITION_MODULE].interceptActive = true
assertError(invalidFunction, "Dark UI received an invalid UI Tweaks function")

local incompatibleApi = newFixture()
incompatibleApi.modules[SETTINGS_MODULE].API_VERSION = 2
assertError(incompatibleApi, "Dark UI requires UI Tweaks settings API version 1")

local current = newFixture()
local modules = assert(current.integration.requireGameBarModules())
assert(modules.recipeComposition == current.modules[COMPOSITION_MODULE])
assert(modules.reactSettings == current.modules[REACT_SETTINGS_MODULE])
assert(modules.storage == current.modules[STORAGE_MODULE])
assert(#current.warnings == 0)

print("Dark UI UIT compatibility test passed (missing files, older helpers, invalid modules, current UIT)")
