--!strict

export type Theme = {
	Name: string,
	Background: Color3,
	Surface: Color3,
	SurfaceAlt: Color3,
	SurfaceRaised: Color3,
	Border: Color3,
	Accent: Color3,
	AccentMuted: Color3,
	Text: Color3,
	MutedText: Color3,
	SubtleText: Color3,
	Success: Color3,
	Warning: Color3,
	Danger: Color3,
	Radius: number,
}

local Theme = {}

local dark: Theme = {
	Name = "Dark",
	Background = Color3.fromRGB(12, 14, 20),
	Surface = Color3.fromRGB(17, 20, 28),
	SurfaceAlt = Color3.fromRGB(24, 28, 39),
	SurfaceRaised = Color3.fromRGB(32, 38, 52),
	Border = Color3.fromRGB(46, 54, 70),
	Accent = Color3.fromRGB(121, 112, 255),
	AccentMuted = Color3.fromRGB(48, 45, 91),
	Text = Color3.fromRGB(243, 245, 250),
	MutedText = Color3.fromRGB(160, 168, 183),
	SubtleText = Color3.fromRGB(112, 123, 144),
	Success = Color3.fromRGB(77, 205, 147),
	Warning = Color3.fromRGB(247, 190, 83),
	Danger = Color3.fromRGB(240, 103, 116),
	Radius = 12,
}

local light: Theme = {
	Name = "Light",
	Background = Color3.fromRGB(242, 244, 249),
	Surface = Color3.fromRGB(255, 255, 255),
	SurfaceAlt = Color3.fromRGB(246, 247, 251),
	SurfaceRaised = Color3.fromRGB(235, 237, 244),
	Border = Color3.fromRGB(220, 223, 233),
	Accent = Color3.fromRGB(102, 77, 225),
	AccentMuted = Color3.fromRGB(227, 221, 255),
	Text = Color3.fromRGB(34, 37, 49),
	MutedText = Color3.fromRGB(97, 103, 121),
	SubtleText = Color3.fromRGB(137, 143, 158),
	Success = Color3.fromRGB(34, 155, 103),
	Warning = Color3.fromRGB(195, 129, 19),
	Danger = Color3.fromRGB(205, 66, 81),
	Radius = 10,
}

local midnight: Theme = {
	Name = "Midnight",
	Background = Color3.fromRGB(9, 16, 28),
	Surface = Color3.fromRGB(13, 24, 41),
	SurfaceAlt = Color3.fromRGB(19, 34, 56),
	SurfaceRaised = Color3.fromRGB(26, 45, 72),
	Border = Color3.fromRGB(39, 64, 93),
	Accent = Color3.fromRGB(58, 195, 219),
	AccentMuted = Color3.fromRGB(24, 79, 94),
	Text = Color3.fromRGB(235, 246, 251),
	MutedText = Color3.fromRGB(150, 177, 193),
	SubtleText = Color3.fromRGB(102, 133, 153),
	Success = Color3.fromRGB(83, 213, 161),
	Warning = Color3.fromRGB(248, 194, 94),
	Danger = Color3.fromRGB(244, 111, 127),
	Radius = 10,
}

Theme.Presets = table.freeze({
	Dark = table.freeze(dark),
	Light = table.freeze(light),
	Midnight = table.freeze(midnight),
})

local colorKeys = {
	Background = true,
	Surface = true,
	SurfaceAlt = true,
	SurfaceRaised = true,
	Border = true,
	Accent = true,
	AccentMuted = true,
	Text = true,
	MutedText = true,
	SubtleText = true,
	Success = true,
	Warning = true,
	Danger = true,
}

local function copyTheme(source: any): Theme
	local result = table.clone(dark) :: any
	for key, value in source do
		if colorKeys[key] then
			assert(typeof(value) == "Color3", ("Theme.%s must be a Color3"):format(key))
			result[key] = value
		elseif key == "Radius" then
			assert(type(value) == "number" and value == value and value >= 0 and value < math.huge, "Theme.Radius must be a finite non-negative number")
			result.Radius = math.min(value, 32)
		elseif key == "Name" then
			assert(type(value) == "string", "Theme.Name must be a string")
			result.Name = value
		end
	end
	return result :: Theme
end

function Theme.resolve(input: any?): Theme
	if input == nil then
		return copyTheme(dark)
	end

	if type(input) == "string" then
		local preset = Theme.Presets[input]
		assert(preset ~= nil, ("Unknown theme '%s'. Use Dark, Light, Midnight, or a theme table."):format(input))
		return copyTheme(preset)
	end

	assert(type(input) == "table", "Theme must be a preset name or a theme table")
	return copyTheme(input)
end

return Theme
