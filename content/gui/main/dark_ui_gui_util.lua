local guiUtil = {}

-- Documented api.gui.StyleSheet fields; native userdata cannot be iterated with pairs().
local styleSheetFields = {
	"backgroundColor",
	"backgroundColor1",
	"backgroundColor2",
	"backgroundImage1",
	"backgroundImage2",
	"borderWidth",
	"borderColor",
	"color",
	"size",
	"padding",
	"fontSize",
	"borderImage",
	"anchorPoint",
}

function guiUtil.mergeStyleSheet(base, overlay)
	if base == nil then
		return overlay.styleSheet
	end
	if #overlay.propertyNames == 0 then
		return base
	end
	-- Re-read the base: other mods can mutate a native sheet without changing its identity.
	local merged = api.gui.StyleSheet.new()
	for _, name in ipairs(styleSheetFields) do
		local value = base[name]
		if value ~= nil then
			merged[name] = value
		end
	end
	for _, name in ipairs(overlay.propertyNames) do
		merged[name] = overlay.styleSheet[name]
	end
	return merged
end

function guiUtil.grayColor(gray)
	assert(type(gray) == "number" and gray >= 0 and gray <= 255, "Dark UI grey must be between 0 and 255")
	local channel = gray / 255
	return { channel, channel, channel, 1 }
end

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
