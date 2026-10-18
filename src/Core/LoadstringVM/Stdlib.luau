--!strict
-- Standard library used by the LumaUI loadstring virtual machine.
-- It exposes a curated set of Luau and Roblox globals so interpreted code
-- never depends on the host environment leaking arbitrary values.

export type Globals = { [string]: any }

local Stdlib = {}

-- Base Luau functions and libraries. They are always available to interpreted
-- code, even when a custom environment is provided.
local libraries: Globals = {
	assert = assert,
	error = error,
	ipairs = ipairs,
	next = next,
	pairs = pairs,
	pcall = pcall,
	xpcall = xpcall,
	print = print,
	rawequal = rawequal,
	rawget = rawget,
	rawlen = rawlen,
	rawset = rawset,
	select = select,
	setmetatable = setmetatable,
	getmetatable = getmetatable,
	tonumber = tonumber,
	tostring = tostring,
	type = type,
	unpack = table.unpack,

	table = table,
	string = string,
	math = math,
	os = os,
	coroutine = coroutine,
	bit32 = bit32,
	buffer = buffer,
	utf8 = utf8,
	task = task,
	vector = vector,
}

-- Roblox specific globals. They are only reachable through the curated
-- environment (sandbox) and never through a bare custom environment.
local roblox: Globals = {
	Enum = Enum,
	Instance = Instance,
	game = game,
	workspace = workspace,
	script = script,
	settings = settings,

	Axes = Axes,
	BrickColor = BrickColor,
	CFrame = CFrame,
	Color3 = Color3,
	ColorSequence = ColorSequence,
	DateTime = DateTime,
	Faces = Faces,
	Font = Font,
	NumberRange = NumberRange,
	NumberSequence = NumberSequence,
	NumberSequenceKeypoint = NumberSequenceKeypoint,
	OverlapParams = OverlapParams,
	PathWaypoint = PathWaypoint,
	PhysicalProperties = PhysicalProperties,
	Random = Random,
	Ray = Ray,
	RaycastParams = RaycastParams,
	Rect = Rect,
	Region3 = Region3,
	Rotation = Rotation,
	TweenInfo = TweenInfo,
	UDim = UDim,
	UDim2 = UDim2,
	Vector2 = Vector2,
	Vector3 = Vector3,
	wait = wait,
	tick = tick,
	delay = delay,
	spawn = spawn,
	elapsedTime = elapsedTime,
}

local curated: Globals = {}

for key, value in libraries do
	curated[key] = value
end
for key, value in roblox do
	curated[key] = value
end

function Stdlib.libraries(): Globals
	return libraries
end

function Stdlib.curated(): Globals
	return curated
end

-- Returns a global from the host environment, when the host exposes one.
function Stdlib.hostGlobal(name: string): any
	local ok, globals = pcall(function()
		return (_G :: any)
	end)
	if ok and type(globals) == "table" then
		return (globals :: any)[name]
	end
	return nil
end

-- Returns the global table of the host when it is reachable.
function Stdlib.hostGlobals(): Globals?
	local ok, globals = pcall(function()
		return (_G :: any)
	end)
	if ok and type(globals) == "table" then
		return (globals :: any) :: Globals
	end
	return nil
end

return Stdlib
