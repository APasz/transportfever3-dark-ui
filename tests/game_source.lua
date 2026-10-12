local gameSource = {}

local ARCHIVES = {
	base = "base.zip",
	gui = "gui.zip",
	scripts = "scripts.zip",
}

local function shellQuote(value)
	return "'" .. value:gsub("'", "'\\''") .. "'"
end

function gameSource.new(installPath)
	assert(type(installPath) == "string" and installPath ~= "", "A TpF3 install path is required")
	local sources = {}
	local compiler
	local loader = {}

	function loader.read(archive, entryPath)
		local archiveName = assert(ARCHIVES[archive], "Unknown TpF3 source archive " .. tostring(archive))
		local cacheKey = archive .. "/" .. entryPath
		if sources[cacheKey] == nil then
			local archivePath = installPath .. "/base/content/" .. archiveName
			local pipe = assert(io.popen("unzip -p " .. shellQuote(archivePath) .. " " .. shellQuote(entryPath), "r"))
			local source = pipe:read("*a")
			assert(pipe:close(), "Could not read TpF3 source " .. entryPath .. " from " .. archivePath)
			sources[cacheKey] = source
		end
		return sources[cacheKey]
	end

	function loader.compile(source, name)
		if compiler == nil then
			compiler = assert(load(loader.read("base", "base/tl.lua"), "TpF3 Teal compiler", "t"))()
		end
		local ast, errors = compiler.parse(source, name)
		assert(#errors == 0, "Teal syntax error in " .. name .. ": " .. (#errors > 0 and errors[1].msg or ""))
		return assert(compiler.generate(ast, "5.3"))
	end

	function loader.load(archive, entryPath, environment)
		local source = loader.read(archive, entryPath)
		if entryPath:sub(-3) == ".tl" then
			source = loader.compile(source, entryPath)
		end
		return assert(load(source, "@" .. entryPath, "t", environment or _G))()
	end

	return loader
end

return gameSource
