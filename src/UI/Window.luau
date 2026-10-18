--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Maid = require(script.Parent.Parent.Core.Maid)
local Theme = require(script.Parent.Parent.Core.Theme)
local Util = require(script.Parent.Parent.Core.Util)
local Tab = require(script.Parent.Tab)

local Window = {}
Window.__index = Window

local function resolveKeyCode(value: any): EnumItem
	if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
		return value
	end
	if type(value) == "string" then
		local keyCode = (Enum.KeyCode :: any)[value]
		if keyCode then
			return keyCode
		end
	end
	return Enum.KeyCode.RightShift
end

local function textLabel(parent: Instance, window: any, name: string, text: string, properties: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		Text = text,
		TextColor3 = window._theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}
	for key, value in properties do
		defaults[key] = value
	end
	local label = Util.new("TextLabel", defaults, parent) :: TextLabel
	Util.bindTheme(window, label, "TextColor3", "Text")
	return label
end

local function serializeValue(value: any, depth: number?, seen: { [any]: boolean }?): (any, boolean)
	local valueType = typeof(value)
	if valueType == "Color3" then
		return {
			__type = "Color3",
			r = value.R,
			g = value.G,
			b = value.B,
		}, true
	elseif valueType == "EnumItem" then
		local enumName = string.match(tostring(value.EnumType), "^Enum%.(.+)$")
		if enumName == nil then
			return nil, false
		end
		return {
			__type = "EnumItem",
			enum = enumName,
			name = value.Name,
		}, true
	elseif type(value) == "string" or type(value) == "boolean" then
		return value, true
	elseif type(value) == "number" then
		return if Util.isFiniteNumber(value) then value else nil, Util.isFiniteNumber(value)
	elseif type(value) == "table" then
		local currentDepth = depth or 0
		if currentDepth >= 8 then
			return nil, false
		end
		local visited: { [any]: boolean } = seen or {}
		if visited[value] then
			return nil, false
		end
		visited[value] = true
		local result = {}
		for key, item in value do
			if type(key) ~= "string" and type(key) ~= "number" then
				visited[value] = nil
				return nil, false
			end
			local encoded, ok = serializeValue(item, currentDepth + 1, visited)
			if not ok then
				visited[value] = nil
				return nil, false
			end
			result[key] = encoded
		end
		visited[value] = nil
		return result, true
	end
	return nil, false
end

local function deserializeValue(value: any, depth: number?): (any, boolean)
	local currentDepth = depth or 0
	if currentDepth >= 8 then
		return nil, false
	end
	if type(value) ~= "table" then
		if type(value) == "number" and not Util.isFiniteNumber(value) then
			return nil, false
		end
		return value, true
	end

	if value.__type == "Color3" then
		if not Util.isFiniteNumber(value.r) or not Util.isFiniteNumber(value.g) or not Util.isFiniteNumber(value.b) then
			return nil, false
		end
		return Color3.new(math.clamp(value.r, 0, 1), math.clamp(value.g, 0, 1), math.clamp(value.b, 0, 1)), true
	elseif value.__type == "EnumItem" then
		if type(value.enum) ~= "string" or type(value.name) ~= "string" then
			return nil, false
		end
		local enumOk, enumType = pcall(function()
			return (Enum :: any)[value.enum]
		end)
		if not enumOk or enumType == nil then
			return nil, false
		end
		local itemOk, enumItem = pcall(function()
			return (enumType :: any)[value.name]
		end)
		if not itemOk or enumItem == nil then
			return nil, false
		end
		return enumItem, true
	end

	local result = {}
	for key, item in value do
		if type(key) ~= "string" and type(key) ~= "number" then
			return nil, false
		end
		local decoded, ok = deserializeValue(item, currentDepth + 1)
		if not ok then
			return nil, false
		end
		result[key] = decoded
	end
	return result, true
end

function Window.new(options: any?): any
	local data = options or {}
	local player = data.Player or Players.LocalPlayer
	assert(player ~= nil, "LumaUI must be created from a LocalScript or supplied a Player")
	local playerGui = data.Parent or player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
	assert(playerGui:IsA("PlayerGui"), "Window Parent must be a PlayerGui")

	local theme = Theme.resolve(data.Theme)
	local animations = data.Animations ~= false
	local self: any = setmetatable({
		_theme = theme,
		_animationDuration = if animations and Util.isFiniteNumber(data.AnimationDuration) then math.max(data.AnimationDuration, 0) else if animations then 0.16 else 0,
		_maid = Maid.new(),
		_tabs = {},
		_controls = {},
		_themeBindings = {},
		_nextControlId = 0,
		_nextNotificationId = 0,
		_activeTab = nil,
		_activeKeybind = nil,
		_destroyed = false,
		_minimized = false,
		_toggleKey = resolveKeyCode(data.ToggleKey or Enum.KeyCode.RightShift),
		_searchQuery = "",
	}, Window)

	local gui = Util.new("ScreenGui", {
		Name = tostring(data.Name or "LumaUI"),
		ResetOnSpawn = false,
		IgnoreGuiInset = data.IgnoreGuiInset == true,
		DisplayOrder = if type(data.DisplayOrder) == "number" then data.DisplayOrder else 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = true,
	}, playerGui) :: ScreenGui
	self._gui = gui

	local rootSize = if typeof(data.Size) == "UDim2" then data.Size else UDim2.new(0.82, 0, 0.78, 0)
	local root = Util.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = if typeof(data.Position) == "UDim2" then data.Position else UDim2.fromScale(0.5, 0.5),
		Size = rootSize,
		BackgroundColor3 = theme.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
	}, gui) :: Frame
	self._root = root
	self._expandedSize = rootSize
	local rootCorner = Util.corner(root, theme.Radius)
	Util.bindTheme(self, rootCorner, "CornerRadius", "Radius", function(radius: number)
		return UDim.new(0, radius)
	end)
	local rootStroke = Util.stroke(root, theme.Border, 1, 0.45)
	Util.bindTheme(self, root, "BackgroundColor3", "Background")
	Util.bindTheme(self, rootStroke, "Color", "Border")
	local accentEdge = Util.new("Frame", {
		Name = "AccentEdge",
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = theme.Accent,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}, root) :: Frame
	Util.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.15),
			NumberSequenceKeypoint.new(0.8, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 0,
	}, accentEdge)
	Util.bindTheme(self, accentEdge, "BackgroundColor3", "Accent")
	Util.new("UISizeConstraint", {
		MinSize = Vector2.new(300, 0),
		MaxSize = Vector2.new(1080, 820),
	}, root)

	local header = Util.new("Frame", {
		Name = "TopBar",
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 58),
		Active = true,
	}, root) :: Frame
	self._header = header
	Util.bindTheme(self, header, "BackgroundColor3", "Surface")

	local logo = Util.new("Frame", {
		Name = "Logo",
		Position = UDim2.new(0, 16, 0, 14),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
	}, header) :: Frame
	Util.corner(logo, 9)
	Util.bindTheme(self, logo, "BackgroundColor3", "Accent")
	Util.new("TextLabel", {
	Name = "Mark",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Font = Enum.Font.GothamBold,
	Text = "L",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Center,
}, logo)

	textLabel(header, self, "Title", tostring(data.Title or "Luma UI"), {
		Position = UDim2.new(0, 56, 0, 7),
		Size = UDim2.new(1, -150, 0, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
	})
	local subtitle = textLabel(header, self, "Subtitle", tostring(data.Subtitle or "A polished toolkit for Roblox"), {
		Position = UDim2.new(0, 57, 0, 30),
		Size = UDim2.new(1, -150, 0, 17),
		Font = Enum.Font.Gotham,
		TextColor3 = theme.MutedText,
		TextSize = 11,
	})
	Util.bindTheme(self, subtitle, "TextColor3", "MutedText")

	local minimizeButton = Util.new("TextButton", {
		Name = "Minimize",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -52, 0, 14),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = theme.SurfaceAlt,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "−",
		TextColor3 = theme.MutedText,
		TextSize = 17,
	}, header) :: TextButton
	Util.corner(minimizeButton, 8)
	Util.bindTheme(self, minimizeButton, "BackgroundColor3", "SurfaceAlt")
	Util.bindTheme(self, minimizeButton, "TextColor3", "MutedText")

	local closeButton = Util.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = theme.SurfaceAlt,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "×",
		TextColor3 = theme.MutedText,
		TextSize = 17,
	}, header) :: TextButton
	Util.corner(closeButton, 8)
	Util.bindTheme(self, closeButton, "BackgroundColor3", "SurfaceAlt")
	Util.bindTheme(self, closeButton, "TextColor3", "MutedText")
	self._minimizeButton = minimizeButton

	local separator = Util.new("Frame", {
		Name = "HeaderSeparator",
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = theme.Border,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
	}, header)
	Util.bindTheme(self, separator, "BackgroundColor3", "Border")

	local body = Util.new("Frame", {
		Name = "Body",
		Position = UDim2.new(0, 0, 0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, root) :: Frame
	self._body = body

	local sidebar = Util.new("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 176, 1, 0),
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, body) :: Frame
	self._sidebar = sidebar
	Util.bindTheme(self, sidebar, "BackgroundColor3", "Surface")
	local sidebarDivider = Util.new("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = theme.Border,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
	}, sidebar)
	Util.bindTheme(self, sidebarDivider, "BackgroundColor3", "Border")
	local navLabel = textLabel(sidebar, self, "NavigationLabel", "PÁGINAS", {
		Position = UDim2.new(0, 14, 0, 13),
		Size = UDim2.new(1, -24, 0, 17),
		Font = Enum.Font.GothamBold,
		TextColor3 = theme.SubtleText,
		TextSize = 9,
	})
	Util.bindTheme(self, navLabel, "TextColor3", "SubtleText")

	local searchFrame = Util.new("Frame", {
		Name = "SearchFrame",
		Position = UDim2.new(0, 10, 0, 38),
		Size = UDim2.new(1, -20, 0, 34),
		BackgroundColor3 = theme.SurfaceAlt,
		BorderSizePixel = 0,
	}, sidebar) :: Frame
	Util.corner(searchFrame, 8)
	local searchStroke = Util.stroke(searchFrame, theme.Border, 1, 0.65)
	Util.bindTheme(self, searchFrame, "BackgroundColor3", "SurfaceAlt")
	Util.bindTheme(self, searchStroke, "Color", "Border")
	local searchIcon = Util.new("TextLabel", {
		Name = "SearchIcon",
		Position = UDim2.new(0, 9, 0, 0),
		Size = UDim2.new(0, 18, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "⌕",
		TextColor3 = theme.SubtleText,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, searchFrame) :: TextLabel
	Util.bindTheme(self, searchIcon, "TextColor3", "SubtleText")
	local searchInput = Util.new("TextBox", {
		Name = "SearchInput",
		Position = UDim2.new(0, 32, 0, 0),
		Size = UDim2.new(1, -40, 1, 0),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		PlaceholderText = "Buscar controles...",
		PlaceholderColor3 = theme.SubtleText,
		Text = "",
		TextColor3 = theme.Text,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, searchFrame) :: TextBox
	self._searchInput = searchInput
	Util.bindTheme(self, searchInput, "TextColor3", "Text")
	Util.bindTheme(self, searchInput, "PlaceholderColor3", "SubtleText")

	local tabList = Util.new("ScrollingFrame", {
		Name = "Tabs",
		Active = true,
		Position = UDim2.new(0, 10, 0, 82),
		Size = UDim2.new(1, -20, 1, -122),

		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = theme.Accent,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, sidebar) :: ScrollingFrame
	self._tabList = tabList
	Util.padding(tabList, 2, 2, 6, 2)
	Util.layout(tabList, Enum.FillDirection.Vertical, 5)
	Util.bindTheme(self, tabList, "ScrollBarImageColor3", "Accent")
	local sidebarFooter = Util.new("TextLabel", {
		Name = "SidebarFooter",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -12),
		Size = UDim2.new(1, -24, 0, 12),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "LUMAUI  •  CLIENT",
		TextColor3 = theme.SubtleText,
		TextSize = 8,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, sidebar) :: TextLabel
	Util.bindTheme(self, sidebarFooter, "TextColor3", "SubtleText")

	local pages = Util.new("Frame", {
		Name = "Pages",
		Position = UDim2.new(0, 176, 0, 0),
		Size = UDim2.new(1, -176, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, body) :: Frame
	self._pages = pages

	self._maid:GiveTask(searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		if not self._destroyed then
			self:Search(searchInput.Text)
		end
	end))
	self._maid:GiveTask(searchInput.Focused:Connect(function()
		searchStroke.Color = self._theme.Accent
		searchStroke.Transparency = 0.2
	end))
	self._maid:GiveTask(searchInput.FocusLost:Connect(function()
		searchStroke.Color = self._theme.Border
		searchStroke.Transparency = 0.65
	end))
	self._maid:GiveTask(closeButton.Activated:Connect(function()
		self:Destroy()
	end))
	self._maid:GiveTask(minimizeButton.Activated:Connect(function()
		self:Minimize()
	end))
	self._maid:GiveTask(minimizeButton.MouseEnter:Connect(function()
		Util.tween(minimizeButton, self._animationDuration, { BackgroundColor3 = self._theme.SurfaceRaised })
	end))
	self._maid:GiveTask(minimizeButton.MouseLeave:Connect(function()
		Util.tween(minimizeButton, self._animationDuration, { BackgroundColor3 = self._theme.SurfaceAlt })
	end))
	self._maid:GiveTask(closeButton.MouseEnter:Connect(function()
		Util.tween(closeButton, self._animationDuration, {
			BackgroundColor3 = self._theme.Danger,
			TextColor3 = Color3.new(1, 1, 1),
		})
	end))
	self._maid:GiveTask(closeButton.MouseLeave:Connect(function()
		Util.tween(closeButton, self._animationDuration, {
			BackgroundColor3 = self._theme.SurfaceAlt,
			TextColor3 = self._theme.MutedText,
		})
	end))

	local dragging = false
	local activeInput: InputObject? = nil
	local dragStart = Vector2.zero
	local startPosition = root.Position
	self._maid:GiveTask(header.InputBegan:Connect(function(input: InputObject)
		local pointerInput = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		local beforeButtons = input.Position.X < root.AbsolutePosition.X + root.AbsoluteSize.X - 96
		if pointerInput and beforeButtons then
			dragging = true
			activeInput = input
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startPosition = root.Position
		end
	end))
	self._maid:GiveTask(UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == activeInput) then
			local position = Vector2.new(input.Position.X, input.Position.Y)
			local delta = position - dragStart
			root.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)
		end
	end))
	self._maid:GiveTask(UserInputService.InputEnded:Connect(function(input: InputObject)
		if input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
			activeInput = nil
		end
	end))
	self._maid:GiveTask(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if self._destroyed or self._activeKeybind ~= nil then
			return
		end
			if gameProcessed or UserInputService:GetFocusedTextBox() then
				return
			end
			local controlHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
			if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.K and controlHeld then
				searchInput:CaptureFocus()
				return
			end
			if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == self._toggleKey then
			self:Toggle()
		end
	end))

	return self
end

function Window._registerControl(self: any, control: any, preferredId: any?): string
	local id: string
	if preferredId ~= nil then
		id = tostring(preferredId)
		assert(id ~= "", "Control Id cannot be empty")
		assert(self._controls[id] == nil, ("Duplicate control Id '%s'"):format(id))
	else
		self._nextControlId += 1
		id = "control_" .. tostring(self._nextControlId)
		while self._controls[id] ~= nil do
			self._nextControlId += 1
			id = "control_" .. tostring(self._nextControlId)
		end
	end
	self._controls[id] = control
	return id
end

function Window._unregisterControl(self: any, control: any)
	if control.Id and self._controls[control.Id] == control then
		self._controls[control.Id] = nil
	end
end

function Window.Tab(self: any, options: any): any
	assert(not self._destroyed, "Cannot add a tab to a destroyed window")
	return Tab.new(self, options)
end

function Window.SelectTab(self: any, tab: any)
	if self._destroyed or tab == nil or tab._destroyed then
		return
	end
	if self._activeKeybind and self._activeKeybind._section._tab ~= tab then
		self:_endKeybindCapture(self._activeKeybind)
	end
	local found = false
	for _, candidate in self._tabs do
		if candidate == tab then
			found = true
			break
		end
	end
	if not found then
		return
	end
	self._activeTab = tab
	for _, candidate in self._tabs do
		candidate:_refreshStyle()
	end
end

function Window.SetVisible(self: any, visible: boolean)
	if self._destroyed then
		return
	end
	self._gui.Enabled = visible == true
end

function Window.Toggle(self: any)
	self:SetVisible(not self._gui.Enabled)
end

function Window.Minimize(self: any, minimized: boolean?)
	if self._destroyed then
		return
	end
	local nextState = if minimized == nil then not self._minimized else minimized == true
	if nextState == self._minimized then
		return
	end
	self._minimized = nextState
	self._body.Visible = not nextState
	self._minimizeButton.Text = if nextState then "+" else "−"
	local targetSize = if nextState then UDim2.new(self._expandedSize.X.Scale, self._expandedSize.X.Offset, 0, 58) else self._expandedSize
	if self._animationDuration > 0 then
		Util.tween(self._root, self._animationDuration, { Size = targetSize })
	else
		self._root.Size = targetSize
	end
end

function Window.SetTheme(self: any, newTheme: any)
	if self._destroyed then
		return
	end
	self._theme = Theme.resolve(newTheme)

	local validBindings = {}
	for _, binding in self._themeBindings do
		local instance = binding.Instance
		if instance and instance.Parent ~= nil then
			local value = self._theme[binding.Key]
			if binding.Transform then
				value = binding.Transform(value)
			end
			if value ~= nil then
				local ok = pcall(function()
					(instance :: any)[binding.Property] = value
				end)
				if ok then
					table.insert(validBindings, binding)
				end
			end
		end
	end
	self._themeBindings = validBindings

	for _, control in self._controls do
		if control._render then
			local ok, message = pcall(control._render, control.Value)
			if not ok then
				warn(("[LumaUI] Could not refresh control '%s' after theme change: %s"):format(control.Id, tostring(message)))
			end
		end
	end
	for _, tab in self._tabs do
		tab:_refreshStyle()
	end
end

function Window.Search(self: any, query: string?)
	if self._destroyed then
		return
	end
	local displayQuery = tostring(query or "")
	local normalized = string.lower(displayQuery)
	self._searchQuery = normalized
	if self._searchInput and self._searchInput.Text ~= displayQuery then
		self._searchInput.Text = displayQuery
	end
	local firstMatch: any = nil
	for _, tab in self._tabs do
		for _, section in tab._sections do
			section:_refreshSearch(normalized)
			if normalized ~= "" and section._frame.Visible and firstMatch == nil then
				firstMatch = tab
			end
		end
	end
	if firstMatch then
		self:SelectTab(firstMatch)
	end
end

function Window._beginKeybindCapture(self: any, control: any)
	if self._destroyed then
		return
	end
	if self._activeKeybind and self._activeKeybind ~= control then
		self._activeKeybind:_setCapturing(false)
	end
	self._activeKeybind = control
	control:_setCapturing(true)
end

function Window._endKeybindCapture(self: any, control: any)
	if self._activeKeybind == control then
		self._activeKeybind = nil
	end
	if control and control._setCapturing then
		local setCapturing = control._setCapturing :: any
		setCapturing(control, false)
	end
end

function Window.Notify(self: any, rawOptions: any): Frame?
	if self._destroyed then
		return nil
	end
	local options = rawOptions or {}
	if type(options) == "string" then
		options = { Description = options }
	end
	self._nextNotificationId += 1

	local notifications = self._notificationContainer
	if not notifications then
		notifications = Util.new("Frame", {
			Name = "Notifications",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -18, 0, 18),
			Size = UDim2.new(0, 330, 1, -36),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 20,
		}, self._gui) :: Frame
		self._notificationContainer = notifications
		local layout = Util.layout(notifications, Enum.FillDirection.Vertical, 10)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
	end

	local kind = string.lower(tostring(options.Type or "info"))
	local accentKey = if kind == "success" then "Success" else if kind == "warning" then "Warning" else if kind == "error" or kind == "danger" then "Danger" else "Accent"
	local card = Util.new("Frame", {
		Name = "Notification_" .. tostring(self._nextNotificationId),
		BackgroundColor3 = self._theme.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, if options.Description == nil then 58 else 76),
		BackgroundTransparency = if self._animationDuration > 0 then 1 else 0,
		LayoutOrder = self._nextNotificationId,
		ZIndex = 20,
	}, notifications) :: Frame
	Util.corner(card, 10)
	local cardStroke = Util.stroke(card, self._theme.Border, 1, if self._animationDuration > 0 then 1 else 0.45)
	Util.bindTheme(self, card, "BackgroundColor3", "Surface")
	Util.bindTheme(self, cardStroke, "Color", "Border")
	local stripe = Util.new("Frame", {
		Name = "Accent",
		Position = UDim2.new(0, 0, 0, 10),
		Size = UDim2.new(0, 3, 1, -20),
		BackgroundColor3 = self._theme[accentKey],
		BorderSizePixel = 0,
		BackgroundTransparency = if self._animationDuration > 0 then 1 else 0,
		ZIndex = 21,
	}, card) :: Frame
	Util.corner(stripe, 2)
	Util.bindTheme(self, stripe, "BackgroundColor3", accentKey)

	local title = Util.new("TextLabel", {
		Name = "Title",
		Position = UDim2.new(0, 14, 0, 10),
		Size = UDim2.new(1, -52, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = tostring(options.Title or "Notification"),
		TextColor3 = self._theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
	}, card) :: TextLabel
	Util.bindTheme(self, title, "TextColor3", "Text")

	local close = Util.new("TextButton", {
		Name = "Dismiss",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -9, 0, 8),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "×",
		TextColor3 = self._theme.MutedText,
		TextSize = 15,
		ZIndex = 22,
	}, card) :: TextButton
	Util.bindTheme(self, close, "TextColor3", "MutedText")

	if options.Description ~= nil then
		local description = Util.new("TextLabel", {
			Name = "Description",
			Position = UDim2.new(0, 14, 0, 31),
			Size = UDim2.new(1, -26, 0, 32),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = tostring(options.Description),
			TextColor3 = self._theme.MutedText,
			TextSize = 11,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 21,
		}, card) :: TextLabel
		Util.bindTheme(self, description, "TextColor3", "MutedText")
	end

	local progress = Util.new("Frame", {
		Name = "Duration",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = self._theme[accentKey],
		BorderSizePixel = 0,
		ZIndex = 22,
	}, card) :: Frame
	Util.bindTheme(self, progress, "BackgroundColor3", accentKey)

	local duration = if Util.isFiniteNumber(options.Duration) then math.max(options.Duration, 0) else 4
	local closed = false
	local function dismiss()
		if closed then
			return
		end
		closed = true
		if card.Parent == nil then
			return
		end
		Util.unbindTheme(self, card)
		if self._animationDuration > 0 then
			Util.tween(card, self._animationDuration, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) })
			task.delay(self._animationDuration, function()
				if card.Parent then
					card:Destroy()
				end
			end)
		else
			card:Destroy()
		end
	end
	close.Activated:Connect(dismiss)

	if self._animationDuration > 0 then
		Util.tween(card, self._animationDuration, { BackgroundTransparency = 0 })
		Util.tween(cardStroke, self._animationDuration, { Transparency = 0.45 })
		Util.tween(stripe, self._animationDuration, { BackgroundTransparency = 0 })
	end
	if duration > 0 then
		Util.tween(progress, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
		task.delay(duration, dismiss)
	end

	return card
end

function Window.ExportConfig(self: any): (string?, string?)
	if self._destroyed then
		return nil, "Window has been destroyed"
	end
	local values = {}
	for id, control in self._controls do
		if control._persistable and not control._destroyed then
			local encoded, ok = serializeValue(control.Value)
			if not ok then
				return nil, ("Control '%s' contains a value that cannot be serialized"):format(id)
			end
			values[id] = encoded
		end
	end

	local ok, result = pcall(function()
		return HttpService:JSONEncode({
			schema = "LumaUI.Config",
			version = 1,
			values = values,
		})
	end)
	if not ok then
		return nil, tostring(result)
	end
	return result, nil
end

function Window.ImportConfig(self: any, serialized: string, fireCallbacks: boolean?): (boolean, string?)
	if self._destroyed then
		return false, "Window has been destroyed"
	end
	if type(serialized) ~= "string" then
		return false, "Config must be a JSON string"
	end
	local decodeOk, config = pcall(function()
		return HttpService:JSONDecode(serialized)
	end)
	if not decodeOk or type(config) ~= "table" then
		return false, "Invalid JSON config"
	end
	if config.schema ~= "LumaUI.Config" or config.version ~= 1 or type(config.values) ~= "table" then
		return false, "Unsupported config schema or version, or missing values"
	end

	local pending = {}
	for id, encoded in config.values do
		local control = self._controls[tostring(id)]
		if control and control._persistable then
			local value, decoded = deserializeValue(encoded)
			if not decoded then
				return false, ("Invalid value for control '%s'"):format(tostring(id))
			end
			local normalized = value
			if control._normalize then
				local valid: boolean
				normalized, valid = control._normalize(value)
				if not valid then
					return false, ("Value does not match control '%s'"):format(tostring(id))
				end
			end
			table.insert(pending, { Control = control, Value = normalized })
		end
	end

	for _, entry in pending do
		entry.Control:Set(entry.Value, fireCallbacks == true)
	end
	return true, nil
end

function Window.Destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	if self._activeKeybind then
		self:_endKeybindCapture(self._activeKeybind)
	end
	self._maid:Destroy()
	local tabs = table.clone(self._tabs) :: { any }
	for _, tab in tabs do
		tab:Destroy()
	end
	table.clear(self._tabs)
	table.clear(self._controls)
	table.clear(self._themeBindings)
	self._gui:Destroy()
end

return Window
