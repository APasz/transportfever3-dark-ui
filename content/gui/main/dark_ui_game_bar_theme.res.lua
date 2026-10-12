local COMPOSE_AFTER_STANDARD_REPLACEMENTS = 1000000

function data()
	return {
		type = "react-replacement-config",
		data = {
			filePath = "apasz_dark_ui_1::/gui/main/dark_ui_game_bar_theme.script",
			doReplaceFn = "install",
			order = COMPOSE_AFTER_STANDARD_REPLACEMENTS,
		},
	}
end
