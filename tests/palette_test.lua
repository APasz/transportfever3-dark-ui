local gameSource = dofile("tests/game_source.lua").new(assert(arg[1], "Pass the TpF3 install path"))
local sourceFile = assert(io.open("content/gui/main/recolor.script.tl", "r"))
local source = sourceFile:read("*a")
sourceFile:close()
local paletteScript = gameSource.compile(source, "recolor.script.tl")

local semanticColor = { 0.8, 0.1, 0.2, 1 }
local extensionColor = { 0.2, 0.7, 0.9, 0.5 }
local colors = {
	Positive = semanticColor,
	Negative = semanticColor,
	NeutralMedium = semanticColor,
	CustomModColor = extensionColor,
}
local writes = 0
local resource
resource = {
	data = colors,
	setData = function(self, updatedColors)
		assert(self == resource)
		assert(updatedColors == colors)
		writes = writes + 1
	end,
}
local resourceId = 10
local messages = {}
local environment = setmetatable({
	api = {
		gui = {
			genericRep = {
				find = function(path)
					assert(path == "::/gui/main/default_colors.gres")
					return resourceId
				end,
				get = function(id)
					assert(id == 10)
					return resource
				end,
			},
		},
	},
	ug_require = function(path)
		if path == "apasz_dark_ui_1::/gui/main/logging_config.tl" then
			return false
		end
		assert(path == "apasz_dark_ui_1::/gui/main/logging.lua")
		return {
			new = function(name, enabled)
				assert(name == "Dark UI" and enabled == false)
				return {
					debug = function(message)
						messages[#messages + 1] = message
					end,
				}
			end,
		}
	end,
}, { __index = _G })
local palette = assert(load(paletteScript, "recolor.script.tl", "t", environment))()

local expectedBrightness = {
	BaseVeryDark = 0.03,
	BaseDark = 0.06,
	BaseDarkMedium = 0.09,
	BaseMedium = 0.12,
	BaseLightMedium = 0.15,
	BaseLight = 0.18,
	BaseVeryLight = 0.26,
	AccentVeryDark = 0.15,
	AccentDark = 0.25,
	AccentMedium = 0.45,
	AccentLight = 0.65,
	AccentVeryLight = 0.75,
}
local function assertPalette()
	local count = 0
	for key, color in pairs(colors) do
		count = count + 1
		local brightness = expectedBrightness[key]
		if brightness ~= nil then
			for channel = 1, 3 do
				assert(math.abs(color[channel] - brightness) < 1e-12, "Unexpected palette brightness for " .. key)
			end
			assert(color[4] == 1)
		end
	end
	assert(count == 16, "Dark UI unexpectedly added or removed palette entries")
	assert(colors.Positive == semanticColor and colors.Negative == semanticColor)
	assert(colors.NeutralMedium == semanticColor and colors.CustomModColor == extensionColor)
	assert(semanticColor[1] == 0.8 and semanticColor[2] == 0.1 and semanticColor[3] == 0.2 and semanticColor[4] == 1)
	assert(
		extensionColor[1] == 0.2 and extensionColor[2] == 0.7 and extensionColor[3] == 0.9 and extensionColor[4] == 0.5
	)
end

palette.overwrite({})
assert(writes == 1 and #messages == 1)
assertPalette()
palette.overwrite({})
assert(writes == 2)
assertPalette()

resourceId = -1
assert(not pcall(palette.overwrite, {}), "Dark UI accepted a missing default palette")
resourceId = 10
resource.data = nil
assert(not pcall(palette.overwrite, {}), "Dark UI accepted an invalid default palette")
assert(writes == 2, "Dark UI wrote a palette after validation failed")

print("Dark UI palette test passed")
