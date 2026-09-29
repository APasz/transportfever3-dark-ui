local color_util = require "::/gui/main/color_util.tl"
local ssu = require "::/gui/main/stylesheetutil.lua"

-- These selectors are inert when the optional Minimap mod is not installed.
local function windowSurface()
	return {
		fileName = "::/gui/builtin/window/design/surface.tga",
		horizontal = { 0, 40, 42, 92 },
		vertical = { 0, 50, 52, 92 },
	}
end

local function windowContour()
	return {
		fileName = "::/gui/builtin/window/design/contour.tga",
		horizontal = { 0, 40, 42, 92 },
		vertical = { 0, 50, 52, 92 },
	}
end

local function windowShadow()
	return {
		fileName = "::/gui/builtin/window/design/shadow.tga",
		horizontal = { 0, 60, 65, 156 },
		vertical = { 0, 89, 96, 156 },
	}
end

local function buttonSurface()
	return {
		fileName = "::/gui/builtin/button/default_surface.tga",
		horizontal = { 0, 9, 21, 30 },
		vertical = { 0, 9, 21, 30 },
	}
end

local function buttonContour()
	return {
		fileName = "::/gui/builtin/button/default_contour.tga",
		horizontal = { 0, 9, 21, 30 },
		vertical = { 0, 9, 21, 30 },
	}
end

local function makeWindowStyle(colors, transparency)
	return {
		backgroundImage1 = windowSurface(),
		backgroundColor1 = color_util.withTransparencyRaw(
			colors.BaseDarkMedium,
			transparency.VeryLow
		),
		borderImage = windowContour(),
		borderColor = color_util.withTransparencyRaw(
			colors.NeutralMedium,
			transparency.Medium
		),
		shadowNinePatch = windowShadow(),
		shadowColor = color_util.withTransparencyRaw(
			colors.NeutralVeryDark,
			transparency.Medium
		),
		shadowWidth = { 32, 32, 32, 32 },
	}
end

local function makeButtonStyle(backgroundColor, borderColor, textColor)
	return {
		backgroundImage1 = buttonSurface(),
		backgroundColor1 = backgroundColor,
		borderImage = buttonContour(),
		borderColor = borderColor,
		color = textColor,
	}
end

function data()
	local result = {}
	local add = ssu.makeAdder(result)
	local colors = api.gui.genericRep.get(
		api.gui.genericRep.find("::/gui/main/default_colors.gres")
	).data
	local transparency = api.gui.genericRep.get(
		api.gui.genericRep.find("::/gui/main/transparency.gres")
	).data

	add([[Window#schbrongx-minimap.window,
		#schbrongx-minimap.controller-panel]], makeWindowStyle(colors, transparency))

	add([[Window#schbrongx-minimap.window Window::Title,
		!schbrongx-minimap-controller-title]], {
		color = colors.NeutralLightest,
	})

	add([[Window#schbrongx-minimap.window ToggleButtonInternal!pin,
		Window#schbrongx-minimap.window Window::TitleLayout Button!close,
		Button!schbrongx-minimap-control,
		Button!schbrongx-minimap-controller-button]], makeButtonStyle(
		colors.BaseDark,
		colors.BaseLightMedium,
		colors.NeutralLightest
	))

	add([[Button!schbrongx-minimap-controller-button:hover,
		Button!schbrongx-minimap-control:hover,
		Window#schbrongx-minimap.window ToggleButtonInternal!pin:hover,
		Window#schbrongx-minimap.window Window::TitleLayout Button!close:hover]], makeButtonStyle(
		colors.BaseLightMedium,
		colors.NeutralVeryLight
	))

	add([[Button!schbrongx-minimap-controller-button:active,
		Button!schbrongx-minimap-control:active,
		Window#schbrongx-minimap.window ToggleButtonInternal!pin!checked,
		Button!schbrongx-minimap-controller-button!pinned]], makeButtonStyle(
		colors.AccentDark,
		colors.AccentVeryLight
	))

	add("Button!schbrongx-minimap-controller-button:disabled", makeButtonStyle(
		colors.BaseVeryDark,
		colors.BaseDarkMedium,
		colors.NeutralMedium
	))

	add("!schbrongx-minimap-controls", makeButtonStyle(
		colors.BaseVeryDark,
		colors.BaseLightMedium
	))

	add("SchbrongxMinimapMap, #schbrongx_minimap.map", {
		backgroundColor = colors.BaseVeryDark,
	})

	add("SchbrongxMinimapScale", {
		backgroundColor = color_util.withTransparencyRaw(
			colors.BaseVeryDark,
			transparency.VeryLow
		),
	})

	add("SchbrongxMinimapScale TextView", {
		color = colors.NeutralLightest,
	})

	return result
end
