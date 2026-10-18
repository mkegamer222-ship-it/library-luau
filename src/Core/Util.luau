--!strict

local TweenService = game:GetService("TweenService")

local Util = {}

function Util.new(className: string, properties: { [string]: any }?, parent: Instance?): any
	local instance = Instance.new(className)
	if properties then
		for key, value in properties do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Util.corner(parent: Instance, radius: number?): UICorner
	return Util.new("UICorner", {
		CornerRadius = UDim.new(0, radius or 10),
	}, parent) :: UICorner
end

function Util.stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
	return Util.new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent) :: UIStroke
end

function Util.padding(parent: Instance, top: number?, right: number?, bottom: number?, left: number?): UIPadding
	return Util.new("UIPadding", {
		PaddingTop = UDim.new(0, top or 0),
		PaddingRight = UDim.new(0, right or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
		PaddingLeft = UDim.new(0, left or 0),
	}, parent) :: UIPadding
end

function Util.layout(parent: Instance, direction: Enum.FillDirection?, padding: number?): UIListLayout
	return Util.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding or 0),
	}, parent) :: UIListLayout
end

function Util.tween(instance: Instance, duration: number, properties: { [string]: any }, style: Enum.EasingStyle?): Tween
	local tweenInfo = TweenInfo.new(
		math.max(duration, 0),
		style or Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	local animation = TweenService:Create(instance, tweenInfo, properties)
	animation:Play()
	return animation
end

function Util.bindTheme(window: any, instance: Instance, property: string, themeKey: string, transform: ((any) -> any)?)
	local theme = window._theme
	local value = theme[themeKey]
	if transform then
		value = transform(value)
	end
	if value ~= nil then
		(instance :: any)[property] = value
	end
	table.insert(window._themeBindings, {
		Instance = instance,
		Property = property,
		Key = themeKey,
		Transform = transform,
	})
end

function Util.unbindTheme(window: any, root: Instance)
	for index = #window._themeBindings, 1, -1 do
		local instance = window._themeBindings[index].Instance
		if instance == root or instance.Parent == nil or instance:IsDescendantOf(root) then
			table.remove(window._themeBindings, index)
		end
	end
end

function Util.safeCall(callback: any, ...: any)
	if type(callback) ~= "function" then
		return
	end

	local arguments = table.pack(...)
	task.spawn(function()
		local ok, message = pcall(callback, table.unpack(arguments, 1, arguments.n))
		if not ok then
			warn(("[LumaUI] Callback failed:\n%s"):format(tostring(message)))
		end
	end)
end

function Util.formatNumber(value: number, decimals: number?): string
	local digits = math.clamp(math.floor(decimals or 0), 0, 6)
	return string.format("%." .. tostring(digits) .. "f", value)
end

function Util.colorToHex(color: Color3): string
	local red = math.floor(color.R * 255 + 0.5)
	local green = math.floor(color.G * 255 + 0.5)
	local blue = math.floor(color.B * 255 + 0.5)
	return ("#%02X%02X%02X"):format(red, green, blue)
end

function Util.hexToColor(text: string): Color3?
	local value = string.gsub(text, "^%s*(.-)%s*$", "%1")
	value = string.gsub(value, "^#", "")
	if #value == 3 then
		local red = string.sub(value, 1, 1)
		local green = string.sub(value, 2, 2)
		local blue = string.sub(value, 3, 3)
		value = red .. red .. green .. green .. blue .. blue
	end
	if #value ~= 6 or not string.match(value, "^%x%x%x%x%x%x$") then
		return nil
	end

	local red = tonumber(string.sub(value, 1, 2), 16)
	local green = tonumber(string.sub(value, 3, 4), 16)
	local blue = tonumber(string.sub(value, 5, 6), 16)
	if red == nil or green == nil or blue == nil then
		return nil
	end
	return Color3.fromRGB(red, green, blue)
end

function Util.isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Util.contains(list: { any }, value: any): boolean
	for _, item in list do
		if item == value then
			return true
		end
	end
	return false
end

return Util
