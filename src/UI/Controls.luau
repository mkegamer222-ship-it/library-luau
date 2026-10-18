--!strict

local UserInputService = game:GetService("UserInputService")

local Maid = require(script.Parent.Parent.Core.Maid)
local Util = require(script.Parent.Parent.Core.Util)

local Controls = {}
local Control = {}
Control.__index = Control

local function asOptions(options: any): any
	if type(options) == "string" then
		return { Title = options }
	end
	return options or {}
end

local function titleOf(options: any, fallback: string?): string
	return tostring(options.Title or options.Name or fallback or "Control")
end

local function makeRoot(section: any, name: string, height: number?): Frame
	return Util.new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height or 42),
		LayoutOrder = #section._controls + 1,
	}, section._body) :: Frame
end

local function makeText(parent: Instance, window: any, name: string, text: string, properties: { [string]: any }?): TextLabel
	local defaults = {
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
	if properties then
		for key, value in properties do
			defaults[key] = value
		end
	end
	local label = Util.new("TextLabel", defaults, parent) :: TextLabel
	Util.bindTheme(window, label, "TextColor3", "Text")
	return label
end

local function makeSurface(parent: Instance, window: any, name: string, height: number): Frame
	local surface = Util.new("Frame", {
		Name = name,
		BackgroundColor3 = window._theme.SurfaceAlt,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		ClipsDescendants = false,
	}, parent) :: Frame
	Util.corner(surface, 8)
	local outline = Util.stroke(surface, window._theme.Border, 1, 0.5)
	outline.Name = "Outline"
	Util.bindTheme(window, surface, "BackgroundColor3", "SurfaceAlt")
	Util.bindTheme(window, outline, "Color", "Border")
	return surface
end

local function connectHover(control: any, button: GuiButton)
	local window = control._window
	local surface = control._surface or button
	local outline = surface:FindFirstChildOfClass("UIStroke")
	control._maid:GiveTask(button.MouseEnter:Connect(function()
		if control._destroyed then
			return
		end
		Util.tween(surface, window._animationDuration, {
			BackgroundColor3 = window._theme.SurfaceRaised,
		})
		if outline then
			Util.tween(outline, window._animationDuration, {
				Color = window._theme.Accent,
				Transparency = 0.3,
			})
		end
	end))
	control._maid:GiveTask(button.MouseLeave:Connect(function()
		if control._destroyed then
			return
		end
		Util.tween(surface, window._animationDuration, {
			BackgroundColor3 = window._theme.SurfaceAlt,
		})
		if outline then
			Util.tween(outline, window._animationDuration, {
				Color = window._theme.Border,
				Transparency = 0.5,
			})
		end
	end))
end

local function createControl(
	section: any,
	options: any,
	root: GuiObject,
	kind: string,
	initialValue: any,
	normalize: ((any) -> (any, boolean))?,
	callback: any,
	persistable: boolean?
): any
	local window = section._window
	local control: any = setmetatable({
		Kind = kind,
		Root = root,
		_root = root,
		Value = initialValue,
		_callback = callback,
		_normalize = normalize,
		_render = nil,
		_section = section,
		_window = window,
		_maid = Maid.new(),
		_destroyed = false,
		_persistable = persistable == true,
		_searchText = string.lower(titleOf(options) .. " " .. tostring(options.Description or options.Content or "")),
	}, Control)

	control.Id = window:_registerControl(control, options.Id)
	table.insert(section._controls, control)
	if window._searchQuery ~= "" then
		section:_refreshSearch(window._searchQuery)
	end
	return control
end

function Control.Get(self: any): any
	return self.Value
end

function Control.Set(self: any, value: any, fireCallback: boolean?): boolean
	if self._destroyed then
		return false
	end

	local normalized = value
	if self._normalize then
		local valid: boolean
		local normalize = self._normalize :: any
		normalized, valid = normalize(value)
		if not valid then
			return false
		end
	end

	self.Value = normalized
	if self._render then
		local render = self._render :: any
		render(normalized)
	end
	if self._window._searchQuery ~= "" then
		self._section:_refreshSearch(self._window._searchQuery)
	end
	if fireCallback ~= false and self._callback then
		Util.safeCall(self._callback, normalized)
	end
	return true
end

function Control.Destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true

	if self._kind == "Keybind" and self._capturing then
		self._window:_endKeybindCapture(self)
	end
	self._maid:Destroy()
	self._window:_unregisterControl(self)
	Util.unbindTheme(self._window, self.Root)
	self.Root:Destroy()

	for index, control in self._section._controls do
		if control == self then
			table.remove(self._section._controls, index)
			break
		end
	end
	if self._window._searchQuery ~= "" then
		self._section:_refreshSearch(self._window._searchQuery)
	end
end

local function setDefault(control: any, value: any)
	control.Value = value
	if control._render then
		local render = control._render :: any
		render(value)
	end
	if control._window._searchQuery ~= "" then
		control._section:_refreshSearch(control._window._searchQuery)
	end
end

function Controls.Button(section: any, rawOptions: any): any
	local options = asOptions(rawOptions)
	local title = titleOf(options, "Button")
	local description = tostring(options.Description or "")
	local height = if description == "" then 44 else 57
	local window = section._window
	local surface = makeSurface(section._body, window, "ButtonControl", height)
	local button = Util.new("TextButton", {
		Name = "Activate",
		BackgroundTransparency = 1,
		BackgroundColor3 = window._theme.SurfaceAlt,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		Text = "",
	}, surface) :: TextButton
	local titleLabel = makeText(button, window, "Title", title, {
		Position = UDim2.new(0, 12, 0, if description == "" then 0 else 5),
		Size = UDim2.new(1, -24, 0, if description == "" then height else 21),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
	})
	titleLabel.Active = false
	if description ~= "" then
		local details = makeText(button, window, "Description", description, {
			Position = UDim2.new(0, 12, 0, 29),
			Size = UDim2.new(1, -24, 0, 17),
			TextColor3 = window._theme.MutedText,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		Util.bindTheme(window, details, "TextColor3", "MutedText")
	end

	local control = createControl(section, options, surface, "Button", nil, nil, nil, false)
	control._kind = "Button"
	control._surface = surface
	control._button = button
	control._action = options.Callback
	function control:Press()
		if not self._destroyed then
			Util.safeCall(self._action)
		end
	end
	control._maid:GiveTask(button.Activated:Connect(function()
		control:Press()
	end))
	connectHover(control, button)
	return control
end

function Controls.Toggle(section: any, rawOptions: any): any
	local options = asOptions(rawOptions)
	local title = titleOf(options, "Toggle")
	local description = tostring(options.Description or "")
	local height = if description == "" then 44 else 56
	local window = section._window
	local surface = makeSurface(section._body, window, "ToggleControl", height)
	local button = Util.new("TextButton", {
		Name = "ToggleButton",
		BackgroundTransparency = 1,
		BackgroundColor3 = window._theme.SurfaceAlt,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		Text = "",
	}, surface) :: TextButton

	local titleLabel = makeText(button, window, "Title", title, {
		Position = UDim2.new(0, 12, 0, if description == "" then 0 else 5),
		Size = UDim2.new(1, -78, 0, if description == "" then height else 21),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
	})
	titleLabel.Active = false
	if description ~= "" then
		local detail = makeText(button, window, "Description", description, {
			Position = UDim2.new(0, 12, 0, 29),
			Size = UDim2.new(1, -78, 0, 16),
			TextColor3 = window._theme.MutedText,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		Util.bindTheme(window, detail, "TextColor3", "MutedText")
	end

	local track = Util.new("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(38, 22),
		BackgroundColor3 = window._theme.Border,
		BorderSizePixel = 0,
	}, button) :: Frame
	Util.corner(track, 11)
	local knob = Util.new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
	}, track) :: Frame
	Util.corner(knob, 8)

	local function normalize(value: any): (any, boolean)
		if type(value) ~= "boolean" then
			return nil, false
		end
		return value, true
	end
	local control = createControl(section, options, surface, "Toggle", false, normalize, options.Callback, true)
	control._kind = "Toggle"
	control._surface = surface
	control._render = function(value: boolean)
		local theme = window._theme
		Util.tween(track, window._animationDuration, {
			BackgroundColor3 = if value then theme.Accent else theme.Border,
		})
		Util.tween(knob, window._animationDuration, {
			Position = if value then UDim2.new(1, -19, 0.5, 0) else UDim2.new(0, 3, 0.5, 0),
		})
	end
	setDefault(control, options.Default == true)
	control._maid:GiveTask(button.Activated:Connect(function()
		control:Set(not control.Value)
	end))
	connectHover(control, button)
	return control
end

function Controls.Slider(section: any, rawOptions: any): any
	local options = asOptions(rawOptions)
	local title = titleOf(options, "Slider")
	local window = section._window
	local minimum = if Util.isFiniteNumber(options.Min) then options.Min else 0
	local maximum = if Util.isFiniteNumber(options.Max) then options.Max else 100
	assert(minimum <= maximum, "Slider Min must be less than or equal to Max")
	local step = if Util.isFiniteNumber(options.Step) then options.Step else 1
	assert(step > 0, "Slider Step must be greater than zero")
	local prefix = tostring(options.Prefix or "")
	local suffix = tostring(options.Suffix or "")
	local stepString = string.gsub(string.format("%.6f", step), "0+$", "")
	local decimalIndex = string.find(stepString, ".", 1, true)
	local inferredDecimals = if decimalIndex then #stepString - decimalIndex else 0
	local decimals = if Util.isFiniteNumber(options.Decimals) then math.clamp(math.floor(options.Decimals), 0, 6) else inferredDecimals

	local root = makeRoot(section, "SliderControl", 56)
	makeText(root, window, "Title", title, {
		Position = UDim2.new(0, 2, 0, 1),
		Size = UDim2.new(0.65, 0, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
	})
	local valueChip = Util.new("Frame", {
		Name = "ValueChip",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 0),
		Size = UDim2.fromOffset(54, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = window._theme.AccentMuted,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, root) :: Frame
	Util.corner(valueChip, 6)
	Util.padding(valueChip, 0, 7, 0, 7)
	Util.bindTheme(window, valueChip, "BackgroundColor3", "AccentMuted")
	local valueLabel = makeText(valueChip, window, "Value", "", {
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextColor3 = window._theme.Accent,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Util.bindTheme(window, valueLabel, "TextColor3", "Accent")
	local track = Util.new("Frame", {
		Name = "Track",
		Position = UDim2.new(0, 3, 0, 34),
		Size = UDim2.new(1, -6, 0, 6),
		BackgroundColor3 = window._theme.SurfaceRaised,
		BorderSizePixel = 0,
		Active = true,
	}, root) :: Frame
	Util.corner(track, 4)
	Util.bindTheme(window, track, "BackgroundColor3", "SurfaceRaised")
	local fill = Util.new("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = window._theme.Accent,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, track) :: Frame
	Util.corner(fill, 4)
	Util.bindTheme(window, fill, "BackgroundColor3", "Accent")
	Util.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, window._theme.Accent),
			ColorSequenceKeypoint.new(1, window._theme.AccentMuted),
		}),
		Rotation = 0,
	}, fill)
	local knob = Util.new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = window._theme.Text,
		BorderSizePixel = 0,
	}, track) :: Frame
	Util.corner(knob, 7)
	local knobStroke = Util.stroke(knob, window._theme.Accent, 2, 0)
	Util.bindTheme(window, knob, "BackgroundColor3", "Text")
	Util.bindTheme(window, knobStroke, "Color", "Accent")

	local function normalize(value: any): (any, boolean)
		if not Util.isFiniteNumber(value) then
			return nil, false
		end
		local clamped = math.clamp(value, minimum, maximum)
		local snapped = minimum + math.floor(((clamped - minimum) / step) + 0.5) * step
		return math.clamp(snapped, minimum, maximum), true
	end
	local control = createControl(section, options, root, "Slider", minimum, normalize, options.Callback, true)
	control._kind = "Slider"
	control._render = function(value: number)
		local range = maximum - minimum
		local fraction = if range == 0 then 0 else math.clamp((value - minimum) / range, 0, 1)
		fill.Size = UDim2.new(fraction, 0, 1, 0)
		knob.Position = UDim2.new(fraction, 0, 0.5, 0)
		local text: string
		if type(options.Format) == "function" then
			local ok, result = pcall(options.Format, value)
			text = if ok then tostring(result) else Util.formatNumber(value, decimals)
		else
			text = Util.formatNumber(value, decimals)
		end
		valueLabel.Text = prefix .. text .. suffix
	end

	local dragging = false
	local activeInput: InputObject? = nil
	local function updateAt(positionX: number)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local fraction = math.clamp((positionX - track.AbsolutePosition.X) / width, 0, 1)
		control:Set(minimum + (maximum - minimum) * fraction)
	end
	control._maid:GiveTask(track.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			activeInput = input
			updateAt(input.Position.X)
		end
	end))
	control._maid:GiveTask(UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == activeInput) then
			updateAt(input.Position.X)
		end
	end))
	control._maid:GiveTask(UserInputService.InputEnded:Connect(function(input: InputObject)
		if input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
			activeInput = nil
		end
	end))

	setDefault(control, if Util.isFiniteNumber(options.Default) then options.Default else minimum)
	return control
end

local function parseDropdownOptions(raw: any): { any }
	local entries = {}
	if type(raw) ~= "table" then
		return entries
	end

	for _, option in raw do
		local value = option
		local label: string
		if type(option) == "table" then
			value = option.Value
			if value == nil then
				value = option.Name or option.Title
			end
			local labelValue = option.Title or option.Name
			if labelValue == nil then
				labelValue = if value == nil then "Option" else value
			end
			label = tostring(labelValue)
		else
			label = tostring(option)
		end
		if value ~= nil then
			table.insert(entries, { Value = value, Label = label })
		end
	end
	return entries
end

function Controls.Dropdown(section: any, rawOptions: any): any
	local options = asOptions(rawOptions)
	local title = titleOf(options, "Dropdown")
	local window = section._window
	local multi = options.Multi == true
	local entries = parseDropdownOptions(options.Options)
	local root = Util.new("Frame", {
		Name = "DropdownControl",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = #section._controls + 1,
	}, section._body) :: Frame
	Util.layout(root, Enum.FillDirection.Vertical, 6)

	local header = makeSurface(root, window, "Header", 42)
	header.LayoutOrder = 1
	local headerButton = Util.new("TextButton", {
		Name = "ToggleMenu",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		Text = "",
	}, header) :: TextButton
	local titleLabel = makeText(headerButton, window, "Title", title, {
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(0.48, -8, 1, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
	})
	titleLabel.Active = false
	local selectionLabel = makeText(headerButton, window, "Selection", "", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -29, 0, 0),
		Size = UDim2.new(0.52, -4, 1, 0),
		Font = Enum.Font.Gotham,
		TextColor3 = window._theme.MutedText,
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	Util.bindTheme(window, selectionLabel, "TextColor3", "MutedText")
	local arrow = makeText(headerButton, window, "Arrow", "v", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -11, 0, 0),
		Size = UDim2.fromOffset(12, 42),
		Font = Enum.Font.GothamBold,
		TextColor3 = window._theme.MutedText,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Util.bindTheme(window, arrow, "TextColor3", "MutedText")

	local menu = Util.new("ScrollingFrame", {
		Name = "Options",
		BackgroundColor3 = window._theme.SurfaceAlt,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = window._theme.Accent,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		LayoutOrder = 2,
	}, root) :: ScrollingFrame
	Util.corner(menu, 8)
	local menuStroke = Util.stroke(menu, window._theme.Border, 1, 0.5)
	Util.padding(menu, 4, 4, 4, 4)
	local menuLayout = Util.layout(menu, Enum.FillDirection.Vertical, 3)
	Util.bindTheme(window, menu, "BackgroundColor3", "SurfaceAlt")
	Util.bindTheme(window, menu, "ScrollBarImageColor3", "Accent")
	Util.bindTheme(window, menuStroke, "Color", "Border")

	local normalize: (any) -> (any, boolean)
	if multi then
		normalize = function(value: any): (any, boolean)
			if type(value) ~= "table" then
				return nil, false
			end
			local result = {}
			for _, candidate in value do
				for _, entry in entries do
					if entry.Value == candidate and not Util.contains(result, candidate) then
						table.insert(result, candidate)
						break
					end
				end
			end
			return result, true
		end
	else
		normalize = function(value: any): (any, boolean)
			if value == nil then
				return nil, true
			end
			for _, entry in entries do
				if entry.Value == value then
					return value, true
				end
			end
			return nil, false
		end
	end

	local initialValue: any
	if multi then
		initialValue = if type(options.Default) == "table" then options.Default else {}
	else
		initialValue = options.Default
		if initialValue == nil and #entries > 0 then
			initialValue = entries[1].Value
		end
	end
	local normalizedInitial, initialValid = normalize(initialValue)
	if initialValid then
		initialValue = normalizedInitial
	elseif multi then
		initialValue = {}
	else
		initialValue = if #entries > 0 then entries[1].Value else nil
	end
	local control = createControl(section, options, root, "Dropdown", if multi then {} else nil, normalize, options.Callback, true)
	control._kind = "Dropdown"
	control._entries = entries
	control._multi = multi
	local searchTerms = { title }
	for _, entry in entries do
		table.insert(searchTerms, entry.Label)
	end
	control._searchText = string.lower(table.concat(searchTerms, " "))
	control._optionMaid = Maid.new()
	control._menu = menu
	control._menuLayout = menuLayout
	control._selectionLabel = selectionLabel
	control._arrow = arrow
	control._menuOpen = false

	local function isSelected(value: any): boolean
		if multi then
			return Util.contains(control.Value, value)
		end
		return control.Value == value
	end

	local function renderOptions()
		control._optionMaid:DoCleaning()
		for _, child in menu:GetChildren() do
			if child ~= menuLayout and not child:IsA("UIPadding") and not child:IsA("UIStroke") and not child:IsA("UICorner") then
				Util.unbindTheme(window, child)
				child:Destroy()
			end
		end

		local maxVisible = if Util.isFiniteNumber(options.MaxVisibleOptions) then math.clamp(math.floor(options.MaxVisibleOptions), 1, 12) else 6
		menu.Size = UDim2.new(1, 0, 0, math.min(#entries, maxVisible) * 31 + 8)
		menu.CanvasPosition = Vector2.zero
		for index, entry in entries do
			local optionButton = Util.new("TextButton", {
				Name = "Option_" .. tostring(index),
				BackgroundColor3 = window._theme.SurfaceAlt,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -2, 0, 29),
				AutoButtonColor = false,
				Font = Enum.Font.Gotham,
				Text = entry.Label,
				TextColor3 = window._theme.Text,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = index,
			}, menu) :: TextButton
			Util.corner(optionButton, 6)
			Util.padding(optionButton, 0, 26, 0, 9)
			Util.bindTheme(window, optionButton, "TextColor3", "Text")
			local check = Util.new("TextLabel", {
				Name = "Check",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.fromOffset(16, 20),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Text = "\u{2713}",
				TextColor3 = window._theme.Accent,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
			}, optionButton) :: TextLabel
			Util.bindTheme(window, check, "TextColor3", "Accent")
			local function updateOptionStyle()
				optionButton.BackgroundColor3 = if isSelected(entry.Value) then window._theme.AccentMuted else window._theme.SurfaceAlt
				check.Visible = isSelected(entry.Value)
			end
			updateOptionStyle()
			control._optionMaid:GiveTask(optionButton.Activated:Connect(function()
				if multi then
					local nextValue: { any } = table.clone(control.Value)
					local foundIndex: number? = nil
					for selectedIndex, selected in nextValue do
						if selected == entry.Value then
							foundIndex = selectedIndex
						break
						end
					end
					if foundIndex then
						table.remove(nextValue, foundIndex)
					else
						table.insert(nextValue, entry.Value)
					end
					control:Set(nextValue)
				else
					control:Set(entry.Value)
					control._menuOpen = false
					menu.Visible = false
					arrow.Text = "v"
				end
			end))
			control._optionMaid:GiveTask(optionButton.MouseEnter:Connect(function()
				if not isSelected(entry.Value) then
					Util.tween(optionButton, window._animationDuration, { BackgroundColor3 = window._theme.SurfaceRaised })
				end
			end))
			control._optionMaid:GiveTask(optionButton.MouseLeave:Connect(updateOptionStyle))
		end
	end

	control._render = function(value: any)
		local labels = {}
		if multi then
			for _, entry in entries do
				if Util.contains(value, entry.Value) then
					table.insert(labels, entry.Label)
				end
			end
			selectionLabel.Text = if #labels == 0 then "None" else table.concat(labels, ", ")
		else
			local selectedLabel = "Select..."
			for _, entry in entries do
				if entry.Value == value then
					selectedLabel = entry.Label
					break
				end
			end
			selectionLabel.Text = selectedLabel
		end
		for _, child in menu:GetChildren() do
			if child:IsA("TextButton") then
				local entry = entries[tonumber(string.match(child.Name, "%d+")) or -1]
				if entry then
					child.BackgroundColor3 = if isSelected(entry.Value) then window._theme.AccentMuted else window._theme.SurfaceAlt
					local check = child:FindFirstChild("Check")
					if check then
						check.Visible = isSelected(entry.Value)
					end
				end
			end
		end
	end

	control.SetOptions = function(self: any, newOptions: any): boolean
		if self._destroyed then
			return false
		end
		self._entries = parseDropdownOptions(newOptions)
		entries = self._entries
		renderOptions()
		local normalizedValue, validValue = normalize(control.Value)
		if validValue then
			control:Set(normalizedValue, false)
		elseif multi then
			control:Set({}, false)
		else
			control:Set(if #entries > 0 then entries[1].Value else nil, false)
		end
		local labels = {}
		for _, entry in entries do
			table.insert(labels, entry.Label)
		end
		control._searchText = string.lower(title .. " " .. table.concat(labels, " "))
		self._section:_refreshSearch(self._window._searchQuery)
		return true
	end

	control._maid:GiveTask(control._optionMaid)
	control._maid:GiveTask(headerButton.Activated:Connect(function()
		control._menuOpen = not control._menuOpen
		menu.Visible = control._menuOpen
		arrow.Text = if control._menuOpen then "^" else "v"
	end))
	renderOptions()
	setDefault(control, initialValue)
	return control
end

function Controls.Textbox(section: any, rawOptions: any): any
	local options = asOptions(rawOptions)
	local title = titleOf(options, "Textbox")
	local window = section._window
	local root = makeRoot(section, "TextboxControl", 58)
	local titleLabel = makeText(root, window, "Title", title, {
		Position = UDim2.new(0, 2, 0, 0),
		Size = UDim2.new(1, -4, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
	})
	titleLabel.Active = false
	local field = Util.new("TextBox", {
		Name = "Input",
		Position = UDim2.new(0, 0, 0, 23),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = window._theme.SurfaceAlt,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		PlaceholderColor3 = window._theme.SubtleText,
		PlaceholderText = tostring(options.Placeholder or "Digite aqui..."),
		Text = if options.Default == nil then "" else tostring(options.Default),
		TextColor3 = window._theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextEditable = options.ReadOnly ~= true,
	}, root) :: TextBox
	Util.corner(field, 8)
	local outline = Util.stroke(field, window._theme.Border, 1, 0.5)
	Util.padding(field, 0, 10, 0, 10)
	Util.bindTheme(window, field, "BackgroundColor3", "SurfaceAlt")
	Util.bindTheme(window, field, "PlaceholderColor3", "SubtleText")
	Util.bindTheme(window, field, "TextColor3", "Text")
	Util.bindTheme(window, outline, "Color", "Border")

	local function normalize(value: any): (any, boolean)
		if type(value) ~= "string" then
			return nil, false
		end
		return value, true
	end
	local control = createControl(section, options, root, "Textbox", field.Text, normalize, options.Callback, true)
	control._kind = "Textbox"
	control._field = field
	control._render = function(value: string)
		if field.Text ~= value then
			field.Text = value
		end
	end
	control._maid:GiveTask(field.Focused:Connect(function()
		outline.Color = window._theme.Accent
		outline.Transparency = 0.2
	end))
	control._maid:GiveTask(field.FocusLost:Connect(function(enterPressed: boolean)
		outline.Color = window._theme.Border
		outline.Transparency = 0.5
		if options.SubmitOnEnter == true and not enterPressed then
			return
		end
		control:Set(field.Text)
		if options.ClearOnSubmit == true and enterPressed then
			control:Set("", false)
		end
	end))
	return control
end

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
	return Enum.KeyCode.None
end

function Controls.Keybind(section: any, rawOptions: any): any
	local options = asOptions(rawOptions)
	local title = titleOf(options, "Keybind")
	local window = section._window
	local root = makeRoot(section, "KeybindControl", 42)
	local titleLabel = makeText(root, window, "Title", title, {
		Position = UDim2.new(0, 2, 0, 0),
		Size = UDim2.new(0.62, 0, 1, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
	})
	titleLabel.Active = false
	local keyButton = Util.new("TextButton", {
		Name = "KeyButton",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(112, 32),
		BackgroundColor3 = window._theme.SurfaceAlt,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		Text = "",
		TextColor3 = window._theme.Text,
		TextSize = 12,
	}, root) :: TextButton
	Util.corner(keyButton, 8)
	local outline = Util.stroke(keyButton, window._theme.Border, 1, 0.5)
	Util.bindTheme(window, keyButton, "BackgroundColor3", "SurfaceAlt")
	Util.bindTheme(window, keyButton, "TextColor3", "Text")
	Util.bindTheme(window, outline, "Color", "Border")
	local keyLabel = makeText(keyButton, window, "KeyLabel", "", {
		Position = UDim2.new(0, 5, 0, 0),
		Size = UDim2.new(1, -10, 1, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	local initialKey = resolveKeyCode(options.Default or Enum.KeyCode.RightControl)
	local function normalize(value: any): (any, boolean)
		if value == nil then
			return Enum.KeyCode.None, true
		end
		local keyCode = resolveKeyCode(value)
		if keyCode == Enum.KeyCode.None and value ~= Enum.KeyCode.None and value ~= "Unknown" then
			return nil, false
		end
		return keyCode, true
	end
	local control = createControl(section, options, root, "Keybind", initialKey, normalize, options.Changed, true)
	control._kind = "Keybind"
	control._pressCallback = options.Callback
	control._mode = if string.lower(tostring(options.Mode or "Toggle")) == "hold" then "Hold" else "Toggle"
	control._render = function(value: EnumItem)
		keyLabel.Text = if value == Enum.KeyCode.None then "Unbound" else value.Name
		keyButton.BackgroundColor3 = if control._capturing then window._theme.AccentMuted else window._theme.SurfaceAlt
	end
	control._setCapturing = function(value: boolean)
		control._capturing = value
		keyLabel.Text = if value then "Press a key..." else if control.Value == Enum.KeyCode.None then "Unbound" else control.Value.Name
		keyButton.BackgroundColor3 = if value then window._theme.AccentMuted else window._theme.SurfaceAlt
	end
	control._maid:GiveTask(keyButton.Activated:Connect(function()
		window:_beginKeybindCapture(control)
	end))
	control._maid:GiveTask(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if not window._gui.Enabled or not root.Visible or window._activeTab ~= control._section._tab then
			return
		end
		if control._capturing then
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			if input.KeyCode == Enum.KeyCode.None then
				return
			end
			if input.KeyCode == Enum.KeyCode.Escape then
				control:Set(Enum.KeyCode.None, true)
			else
				control:Set(input.KeyCode, true)
			end
			window:_endKeybindCapture(control)
			return
		end
		if window._activeKeybind ~= nil then
			return
		end
		if gameProcessed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == control.Value then
			if control._mode == "Hold" then
				Util.safeCall(control._pressCallback, true)
			else
				Util.safeCall(control._pressCallback, input)
			end
		end
	end))
	if control._mode == "Hold" then
		control._maid:GiveTask(UserInputService.InputEnded:Connect(function(input: InputObject)
			if not control._destroyed and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == control.Value then
				Util.safeCall(control._pressCallback, false)
			end
		end))
	end
	setDefault(control, initialKey)
	return control
end

function Controls.ColorPicker(section: any, rawOptions: any): any
	local options = asOptions(rawOptions)
	local title = titleOf(options, "Color")
	local window = section._window
	local root = Util.new("Frame", {
		Name = "ColorPickerControl",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = #section._controls + 1,
	}, section._body) :: Frame
	Util.layout(root, Enum.FillDirection.Vertical, 6)

	local header = makeSurface(root, window, "Header", 42)
	header.LayoutOrder = 1
	local titleLabel = makeText(header, window, "Title", title, {
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(1, -65, 1, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
	})
	titleLabel.Active = false
	local headerButton = Util.new("TextButton", {
		Name = "OpenPicker",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(32, 26),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
	}, header) :: TextButton
	local swatch = Util.new("Frame", {
		Name = "Swatch",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 0, 1),
		BorderSizePixel = 0,
	}, headerButton) :: Frame
	Util.corner(swatch, 6)
	Util.stroke(swatch, window._theme.Border, 1, 0.25)

	local popup = Util.new("Frame", {
		Name = "Picker",
		BackgroundColor3 = window._theme.SurfaceAlt,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 148),
		Visible = false,
		LayoutOrder = 2,
		ClipsDescendants = false,
	}, root) :: Frame
	Util.corner(popup, 8)
	local popupStroke = Util.stroke(popup, window._theme.Border, 1, 0.5)
	Util.bindTheme(window, popup, "BackgroundColor3", "SurfaceAlt")
	Util.bindTheme(window, popupStroke, "Color", "Border")

	local saturationValue = Util.new("Frame", {
		Name = "SaturationValue",
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(1, -49, 0, 90),
		BackgroundColor3 = Color3.fromHSV(0, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
	}, popup) :: Frame
	Util.corner(saturationValue, 6)
	local whiteOverlay = Util.new("Frame", {
		Name = "SaturationGradient",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, saturationValue) :: Frame
	Util.corner(whiteOverlay, 6)
	Util.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 0,
	}, whiteOverlay)
	local valueOverlay = Util.new("Frame", {
		Name = "ValueGradient",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
	}, saturationValue) :: Frame
	Util.corner(valueOverlay, 6)
	Util.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(0, 0, 0)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Rotation = 90,
	}, valueOverlay)
	local svMarker = Util.new("Frame", {
		Name = "Selector",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, saturationValue) :: Frame
	Util.corner(svMarker, 6)
	Util.stroke(svMarker, Color3.new(1, 1, 1), 2, 0)

	local hueBar = Util.new("Frame", {
		Name = "Hue",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(14, 90),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
	}, popup) :: Frame
	Util.corner(hueBar, 6)
	Util.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		}),
		Rotation = 90,
	}, hueBar)
	local hueMarker = Util.new("Frame", {
		Name = "HueSelector",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(1, 4, 0, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, hueBar) :: Frame
	Util.corner(hueMarker, 2)
	Util.stroke(hueMarker, Color3.fromRGB(20, 20, 25), 1, 0)

	local hexBox = Util.new("TextBox", {
		Name = "HexValue",
		Position = UDim2.new(0, 10, 0, 110),
		Size = UDim2.new(1, -20, 0, 28),
		BackgroundColor3 = window._theme.Surface,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamMedium,
		PlaceholderColor3 = window._theme.SubtleText,
		PlaceholderText = "#RRGGBB",
		Text = "#FF00FF",
		TextColor3 = window._theme.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, popup) :: TextBox
	Util.corner(hexBox, 6)
	local hexStroke = Util.stroke(hexBox, window._theme.Border, 1, 0.55)
	Util.bindTheme(window, hexBox, "BackgroundColor3", "Surface")
	Util.bindTheme(window, hexBox, "PlaceholderColor3", "SubtleText")
	Util.bindTheme(window, hexBox, "TextColor3", "Text")
	Util.bindTheme(window, hexStroke, "Color", "Border")

	local function normalize(value: any): (any, boolean)
		if typeof(value) == "Color3" then
			return value, true
		end
		return nil, false
	end
	local control = createControl(section, options, root, "ColorPicker", Color3.fromRGB(255, 0, 255), normalize, options.Callback, true)
	control._kind = "ColorPicker"
	control._popup = popup
	control._render = function(value: Color3)
		local hue, saturation, brightness = value:ToHSV()
		swatch.BackgroundColor3 = value
		saturationValue.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		svMarker.Position = UDim2.new(saturation, 0, 1 - brightness, 0)
		hueMarker.Position = UDim2.new(0.5, 0, hue, 0)
		if not hexBox:IsFocused() then
			hexBox.Text = Util.colorToHex(value)
		end
	end

	local dragMode: string? = nil
	local activeInput: InputObject? = nil
	local function updateSaturationValue(position: Vector2)
		local size = saturationValue.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local saturation = math.clamp((position.X - saturationValue.AbsolutePosition.X) / size.X, 0, 1)
		local brightness = 1 - math.clamp((position.Y - saturationValue.AbsolutePosition.Y) / size.Y, 0, 1)
		local hue = select(1, control.Value:ToHSV())
		control:Set(Color3.fromHSV(hue, saturation, brightness))
	end
	local function updateHue(position: Vector2)
		local size = hueBar.AbsoluteSize.Y
		if size <= 0 then
			return
		end
		local hue = math.clamp((position.Y - hueBar.AbsolutePosition.Y) / size, 0, 1)
		local _, saturation, brightness = control.Value:ToHSV()
		control:Set(Color3.fromHSV(hue, saturation, brightness))
	end
	local function beginPickerDrag(input: InputObject, mode: string)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragMode = mode
			activeInput = input
			local position = Vector2.new(input.Position.X, input.Position.Y)
			if mode == "SV" then
				updateSaturationValue(position)
			else
				updateHue(position)
			end
		end
	end
	control._maid:GiveTask(saturationValue.InputBegan:Connect(function(input: InputObject)
		beginPickerDrag(input, "SV")
	end))
	control._maid:GiveTask(hueBar.InputBegan:Connect(function(input: InputObject)
		beginPickerDrag(input, "Hue")
	end))
	control._maid:GiveTask(UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragMode and (input.UserInputType == Enum.UserInputType.MouseMovement or input == activeInput) then
			local position = Vector2.new(input.Position.X, input.Position.Y)
			if dragMode == "SV" then
				updateSaturationValue(position)
			else
				updateHue(position)
			end
		end
	end))
	control._maid:GiveTask(UserInputService.InputEnded:Connect(function(input: InputObject)
		if input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragMode = nil
			activeInput = nil
		end
	end))
	control._maid:GiveTask(hexBox.FocusLost:Connect(function()
		local color = Util.hexToColor(hexBox.Text)
		if color then
			control:Set(color)
		else
			control._render(control.Value)
		end
	end))
	control._maid:GiveTask(headerButton.Activated:Connect(function()
		popup.Visible = not popup.Visible
	end))
	setDefault(control, if typeof(options.Default) == "Color3" then options.Default else Color3.fromRGB(255, 0, 255))
	return control
end

function Controls.Label(section: any, rawOptions: any): any
	local options = asOptions(rawOptions)
	local text = tostring(options.Text or options.Title or options.Name or "Label")
	local window = section._window
	local root = Util.new("Frame", {
		Name = "LabelControl",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = #section._controls + 1,
	}, section._body) :: Frame
	local label = makeText(root, window, "Text", text, {
		Size = UDim2.new(1, -4, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local control = createControl(section, options, root, "Label", text, function(value: any): (any, boolean)
		return if type(value) == "string" then value else nil, type(value) == "string"
	end, nil, false)
	control._kind = "Label"
	control._label = label
	control._render = function(value: string)
		label.Text = value
		control._searchText = string.lower(value)
	end
	setDefault(control, text)
	return control
end

function Controls.Paragraph(section: any, rawOptions: any): any
	local options = asOptions(rawOptions)
	local title = titleOf(options, "Paragraph")
	local bodyText = tostring(options.Description or options.Content or options.Text or "")
	local window = section._window
	local root = Util.new("Frame", {
		Name = "ParagraphControl",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = #section._controls + 1,
	}, section._body) :: Frame
	local panel = Util.new("Frame", {
		Name = "ParagraphCard",
		BackgroundColor3 = window._theme.SurfaceAlt,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, root) :: Frame
	Util.corner(panel, 9)
	local panelStroke = Util.stroke(panel, window._theme.Border, 1, 0.55)
	Util.padding(panel, 11, 12, 11, 12)
	Util.layout(panel, Enum.FillDirection.Vertical, 5)
	Util.bindTheme(window, panel, "BackgroundColor3", "SurfaceAlt")
	Util.bindTheme(window, panelStroke, "Color", "Border")
	makeText(panel, window, "Title", title, {
		Size = UDim2.new(1, -2, 0, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		LayoutOrder = 1,
	})
	local body = makeText(panel, window, "Text", bodyText, {
		Size = UDim2.new(1, -2, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		TextColor3 = window._theme.MutedText,
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
	})
	Util.bindTheme(window, body, "TextColor3", "MutedText")
	local control = createControl(section, options, root, "Paragraph", bodyText, function(value: any): (any, boolean)
		return if type(value) == "string" then value else nil, type(value) == "string"
	end, nil, false)
	control._kind = "Paragraph"
	control._render = function(value: string)
		body.Text = value
		control._searchText = string.lower(title .. " " .. value)
	end
	setDefault(control, bodyText)
	return control
end

function Controls.Divider(section: any, rawOptions: any): any
	local options = asOptions(rawOptions)
	local window = section._window
	local root = Util.new("Frame", {
		Name = "DividerControl",
		BackgroundColor3 = window._theme.Border,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = #section._controls + 1,
	}, section._body) :: Frame
	Util.bindTheme(window, root, "BackgroundColor3", "Border")
	local control = createControl(section, options, root, "Divider", nil, nil, nil, false)
	control._kind = "Divider"
	return control
end

function Controls.ProgressBar(section: any, rawOptions: any): any
	local options = asOptions(rawOptions)
	local title = titleOf(options, "Progress")
	local window = section._window
	local minimum = if Util.isFiniteNumber(options.Min) then options.Min else 0
	local maximum = if Util.isFiniteNumber(options.Max) then options.Max else 100
	assert(minimum < maximum, "ProgressBar Max must be greater than Min")
	local root = makeRoot(section, "ProgressBarControl", 48)
	makeText(root, window, "Title", title, {
		Position = UDim2.new(0, 2, 0, 0),
		Size = UDim2.new(0.7, 0, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
	})
	local valueLabel = makeText(root, window, "Value", "", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 0),
		Size = UDim2.new(0.3, 0, 0, 18),
		Font = Enum.Font.Gotham,
		TextColor3 = window._theme.MutedText,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	Util.bindTheme(window, valueLabel, "TextColor3", "MutedText")
	local track = Util.new("Frame", {
		Name = "Track",
		Position = UDim2.new(0, 0, 0, 27),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = window._theme.SurfaceRaised,
		BorderSizePixel = 0,
	}, root) :: Frame
	Util.corner(track, 4)
	Util.bindTheme(window, track, "BackgroundColor3", "SurfaceRaised")
	local fill = Util.new("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = window._theme.Accent,
		BorderSizePixel = 0,
	}, track) :: Frame
	Util.corner(fill, 4)
	Util.bindTheme(window, fill, "BackgroundColor3", "Accent")
	local function normalize(value: any): (any, boolean)
		if not Util.isFiniteNumber(value) then
			return nil, false
		end
		return math.clamp(value, minimum, maximum), true
	end
	local control = createControl(section, options, root, "ProgressBar", minimum, normalize, options.Callback, true)
	control._kind = "ProgressBar"
	control._render = function(value: number)
		local fraction = math.clamp((value - minimum) / (maximum - minimum), 0, 1)
		fill.Size = UDim2.new(fraction, 0, 1, 0)
		valueLabel.Text = if options.ShowPercent == false then tostring(value) else (tostring(math.floor(fraction * 100 + 0.5)) .. "%")
	end
	setDefault(control, if Util.isFiniteNumber(options.Default) then options.Default else minimum)
	return control
end

return Controls
