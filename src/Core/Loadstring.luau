--!strict
-- LumaUI loadstring: compiles and runs Luau source at runtime.
--
-- Roblox removed the string compiler from the client, so the classic
-- `loadstring` global is not usable inside a LocalScript. This module ships a
-- small virtual machine (lexer, parser and interpreter) that executes the same
-- code without leaving the game. When the host does expose a working compiler
-- (server scripts with `LoadStringEnabled`, Lune, Luau CLI, ...) the module
-- transparently uses it instead.

local Interpreter = require(script.Parent.LoadstringVM.Interpreter)
local Parser = require(script.Parent.LoadstringVM.Parser)
local Stdlib = require(script.Parent.LoadstringVM.Stdlib)

export type LoadstringOptions = {
	ChunkName: string?,
	Environment: { [string]: any }?,
	Args: { any }?,
	MaxInstructions: number?,
	MaxDepth: number?,
	UseHostCompiler: boolean?,
}

export type SandboxOptions = {
	Strict: boolean?,
}

export type LoadstringResult = {
	Success: boolean,
	Values: { any },
	Error: string?,
}

local Loadstring = {}

type HostCompiler = (source: string, chunkName: string, environment: { [string]: any }?) -> (any?, string?)

local hostCompiler: HostCompiler? = nil
local hostCompilerResolved = false

-- Detects a working `load`/`loadstring` implementation exposed by the host.
local function detectHostCompiler(): HostCompiler?
	if hostCompilerResolved then
		return hostCompiler
	end
	hostCompilerResolved = true

	local globals = Stdlib.hostGlobals()
	if globals == nil then
		return nil
	end

	local loader = globals.load
	if type(loader) == "function" then
		local ok, chunk = pcall(loader, "return 1", "=luma", "t")
		if ok and type(chunk) == "function" then
			hostCompiler = function(source, chunkName, environment)
				local compiled, result = pcall(loader, source, chunkName, "t", environment)
				if compiled and type(result) == "function" then
					return result, nil
				end
				return nil, tostring(result)
			end
			return hostCompiler
		end
	end

	local legacy = globals.loadstring
	if type(legacy) == "function" then
		local ok, chunk = pcall(legacy, "return 1", "=luma")
		if ok and type(chunk) == "function" then
			hostCompiler = function(source, chunkName, environment)
				local compiled, result = pcall(legacy, source, chunkName)
				if compiled and type(result) == "function" then
					return result, nil
				end
				return nil, tostring(result)
			end
			return hostCompiler
		end
	end

	return nil
end

-- Returns true when the host is able to compile strings natively.
function Loadstring.hasHostCompiler(): boolean
	return detectHostCompiler() ~= nil
end

-- Builds a controlled environment with the curated Luau and Roblox globals.
-- Extra values can be injected through the `overrides` table.
-- With `Strict = true` only the curated globals are visible, without the
-- fallback to the globals of the host.
function Loadstring.sandbox(overrides: { [string]: any }?, options: SandboxOptions?): { [string]: any }
	local data = options or {}
	local environment: { [string]: any } = {}
	for key, value in overrides or {} do
		environment[key] = value
	end
	setmetatable(environment, {
		__index = function(_: any, key: any): any
			local curated = Stdlib.curated()
			local value = curated[key]
			if value ~= nil then
				return value
			end
			if data.Strict == true then
				return nil
			end
			return Stdlib.hostGlobal(tostring(key))
		end,
	})
	return environment
end

-- Default environment used when no custom environment is provided.
function Loadstring.environment(): { [string]: any }
	return Loadstring.sandbox()
end

-- Compiles the source into a callable chunk.
-- Returns the chunk and nil on success, or nil and an error message on failure.
function Loadstring.compile(source: string, options: LoadstringOptions?): (any?, string?)
	if type(source) ~= "string" then
		return nil, "loadstring expects a string with the source code"
	end

	local data = options or {}
	local chunkName = tostring(data.ChunkName or "loadstring")
	local environment = data.Environment

	if data.UseHostCompiler ~= false then
		local compiler = detectHostCompiler()
		if compiler ~= nil then
			return compiler(source, chunkName, environment)
		end
	end

	local parsed = Parser.parse(source)
	if parsed.Ast == nil then
		return nil, ("%s: %s"):format(chunkName, parsed.Error or "invalid syntax")
	end

	local ast = parsed.Ast
	local globals = environment or Loadstring.environment()
	local fallback = Stdlib.libraries()

	local chunk: any
	chunk = function(...: any): ...any
		local args = table.pack(...)
		local result = Interpreter.run(ast, {
			Globals = globals,
			Fallback = fallback,
			Args = args,
			ChunkName = chunkName,
			MaxInstructions = data.MaxInstructions,
			MaxDepth = data.MaxDepth,
		})
		if result.error ~= nil then
			error(result.error, 0)
		end
		return table.unpack(result.values, 1, #result.values)
	end

	return chunk, nil
end

-- Runs the source and returns every value produced by the chunk.
function Loadstring.runValues(source: string, options: LoadstringOptions?): (boolean, { any }, string?)
	local chunk, compileError = Loadstring.compile(source, options)
	if chunk == nil then
		return false, {}, compileError
	end

	local data = options or {}
	local args = data.Args or {}
	local packed = table.pack(pcall(chunk, table.unpack(args, 1, #args)))
	if not packed[1] then
		return false, {}, tostring(packed[2])
	end

	local values: { any } = {}
	for index = 2, packed.n do
		values[index - 1] = packed[index]
	end
	return true, values, nil
end

-- Runs the source and returns the first value produced by the chunk.
-- On failure it returns false, nil and the error message.
function Loadstring.run(source: string, options: LoadstringOptions?): (boolean, any, string?)
	local success, values, errorMessage = Loadstring.runValues(source, options)
	if not success then
		return false, nil, errorMessage
	end
	return true, values[1], nil
end

-- Checks the source without running it. Returns true when the code compiles.
function Loadstring.validate(source: string, options: LoadstringOptions?): (boolean, string?)
	local chunk, compileError = Loadstring.compile(source, options)
	if chunk == nil then
		return false, compileError
	end
	return true, nil
end

return Loadstring
