local guiUtil = {}

function guiUtil.validateAlpha(alpha, name)
	assert(
		type(alpha) == "number" and alpha >= 0 and alpha <= 1,
		"Dark UI alpha " .. name .. " must be between 0 and 1"
	)
	return alpha
end

function guiUtil.validateColor(color, name)
	assert(type(color) == "table", "Dark UI color " .. name .. " must be a table")
	for channel = 1, 3 do
		local value = color[channel]
		assert(
			type(value) == "number" and value >= 0 and value <= 1,
			"Dark UI color " .. name .. " has an invalid RGB channel"
		)
	end
	if color[4] ~= nil then
		guiUtil.validateAlpha(color[4], name)
	end
	return color
end

function guiUtil.findResource(path)
	assert(type(path) == "string" and path ~= "", "Dark UI GUI resource path is required")
	local resourceId = api.gui.genericRep.find(path)
	assert(
		type(resourceId) == "number" and resourceId % 1 == 0,
		"Dark UI received an invalid GUI resource id for " .. path
	)
	if resourceId < 0 then
		return nil
	end
	local resource = api.gui.genericRep.get(resourceId)
	assert(resource ~= nil and type(resource.data) == "table", "Dark UI received an invalid GUI resource " .. path)
	return resource.data
end

function guiUtil.getResource(path)
	return assert(guiUtil.findResource(path), "Dark UI could not find GUI resource " .. path)
end

return guiUtil
