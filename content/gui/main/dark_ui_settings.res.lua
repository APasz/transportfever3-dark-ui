local settings = require("apasz_dark_ui_1::/gui/main/dark_ui_settings.lua")

function data()
	return {
		type = settings.RESOURCE_TYPE,
		data = settings.section,
	}
end
