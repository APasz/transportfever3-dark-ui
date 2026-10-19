local MODULE_PREFIX = "apasz_ui_tweaks::"

return {
	loadfile = function(path)
		assert(path:sub(1, #MODULE_PREFIX) == MODULE_PREFIX, "Unexpected mod module: " .. path)
		return loadfile("../ui_tweaks/content" .. path:sub(#MODULE_PREFIX + 1))
	end,
}
