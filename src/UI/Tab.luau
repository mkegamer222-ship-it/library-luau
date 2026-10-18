--!strict

local Maid = require(script.Parent.Parent.Core.Maid)
local Util = require(script.Parent.Parent.Core.Util)
local Section = require(script.Parent.Section)

local Tab = {}
Tab.__index = Tab

function Tab.new(window: any, options: any): any
	local data = if type(options) == "string" then { Title = options } else (options or {})
	local title = tostring(data.Title or data.Name or "Tab")
	local self: any = setmetatable({
		_window = window,
		_title = title,
		_icon = if type(data.Icon) == "string" then data.Icon else "",
		_description = if type(data.Description) == "string" then data.Description else "",
		_sections = {},
		_maid = Maid.new(),
		_destroyed = false,
	}, Tab)

	local page = Util.new("Frame", {
		Name = "Page_" .. title,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ClipsDescendants = true,
	}, window._pages)
	self._page = page

	local pageHeader = Util.new("Frame", {
		Name = "PageHeader",
		Position = UDim2.new(0, 18, 0, 15),
		Size = UDim2.new(1, -36, 0, 39),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, page)
	local pageIcon = Util.new("Frame", {
		Name = "PageIcon",
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = window._theme.AccentMuted,
		BorderSizePixel = 0,
	}, pageHeader)
	Util.corner(pageIcon, 10)
	local pageIconText = Util.new("TextLabel", {
		Name = "Mark",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = if self._icon == "" then "✦" else self._icon,
		TextColor3 = window._theme.Accent,
		TextSize = if #self._icon > 2 then 11 else 13,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, pageIcon)
	Util.bindTheme(window, pageIcon, "BackgroundColor3", "AccentMuted")
	Util.bindTheme(window, pageIconText, "TextColor3", "Accent")
	local pageTitle = Util.new("TextLabel", {
		Name = "Title",
		Position = UDim2.new(0, 46, 0, 0),
		Size = UDim2.new(1, -46, 0, if self._description == "" then 34 else 21),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = title,
		TextColor3 = window._theme.Text,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = if self._description == "" then Enum.TextYAlignment.Center else Enum.TextYAlignment.Top,
	}, pageHeader)
	Util.bindTheme(window, pageTitle, "TextColor3", "Text")
	if self._description ~= "" then
		local pageDescription = Util.new("TextLabel", {
			Name = "Description",
			Position = UDim2.new(0, 47, 0, 22),
			Size = UDim2.new(1, -47, 0, 15),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = self._description,
			TextColor3 = window._theme.MutedText,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, pageHeader)
		Util.bindTheme(window, pageDescription, "TextColor3", "MutedText")
	end

	local scroll = Util.new("ScrollingFrame", {
		Name = "Sections",
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 64),
		Size = UDim2.new(1, 0, 1, -64),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = window._theme.Accent,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	}, page)
	self._scroll = scroll
	Util.padding(scroll, 4, 7, 10, 4)
	Util.layout(scroll, Enum.FillDirection.Vertical, 12)
	Util.bindTheme(window, scroll, "ScrollBarImageColor3", "Accent")

	local button = Util.new("TextButton", {
		Name = "Tab_" .. title,
		BackgroundColor3 = window._theme.Surface,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 38),
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		Text = "",
		LayoutOrder = #window._tabs + 1,
	}, window._tabList)
	self._button = button
	Util.corner(button, 8)
	local buttonStroke = Util.stroke(button, window._theme.Accent, 1, 1)
	self._buttonStroke = buttonStroke
	Util.bindTheme(window, buttonStroke, "Color", "Accent")

	local indicator = Util.new("Frame", {
		Name = "SelectedIndicator",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 3, 0, 19),
		BackgroundColor3 = window._theme.Accent,
		BorderSizePixel = 0,
		Visible = false,
	}, button)
	self._indicator = indicator
	Util.corner(indicator, 3)
	Util.bindTheme(window, indicator, "BackgroundColor3", "Accent")

	local labelText = if self._icon == "" then title else (self._icon .. "   " .. title)
	local label = Util.new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 13, 0, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Font = Enum.Font.GothamMedium,
		Text = labelText,
		TextColor3 = window._theme.MutedText,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Active = false,
	}, button)
	self._label = label
	Util.bindTheme(window, label, "TextColor3", "MutedText")

	self._maid:GiveTask(button.Activated:Connect(function()
		window:SelectTab(self)
	end))
	self._maid:GiveTask(button.MouseEnter:Connect(function()
		if not self._selected then
			Util.tween(button, window._animationDuration, {
				BackgroundTransparency = 0,
				BackgroundColor3 = window._theme.SurfaceAlt,
			})
		end
	end))
	self._maid:GiveTask(button.MouseLeave:Connect(function()
		self:_refreshStyle()
	end))

	table.insert(window._tabs, self)
	if #window._tabs == 1 then
		window:SelectTab(self)
	end

	return self
end

function Tab._refreshStyle(self: any)
	if self._destroyed then
		return
	end
	local theme = self._window._theme
	local wasSelected = self._selected == true
	self._selected = self._window._activeTab == self
	if self._selected then
		self._page.Visible = true
		if not wasSelected then
			self._page.Position = UDim2.new(0, 9, 0, 0)
			if self._window._animationDuration > 0 then
				Util.tween(self._page, self._window._animationDuration, { Position = UDim2.fromScale(0, 0) })
			else
				self._page.Position = UDim2.fromScale(0, 0)
			end
		end
	else
		self._page.Visible = false
		self._page.Position = UDim2.fromScale(0, 0)
	end
	self._indicator.Visible = self._selected
	self._button.BackgroundTransparency = if self._selected then 0 else 1
	self._button.BackgroundColor3 = if self._selected then theme.AccentMuted else theme.Surface
	self._buttonStroke.Transparency = if self._selected then 0.72 else 1
	self._label.TextColor3 = if self._selected then theme.Accent else theme.MutedText
	self._label.Font = if self._selected then Enum.Font.GothamBold else Enum.Font.GothamMedium
end

function Tab.Select(self: any)
	self._window:SelectTab(self)
end

function Tab.Section(self: any, options: any): any
	assert(not self._destroyed, "Cannot add a section to a destroyed tab")
	return Section.new(self, options)
end

function Tab._defaultSection(self: any): any
	if self._defaultSectionValue == nil or self._defaultSectionValue._destroyed then
		self._defaultSectionValue = Section.new(self, { Title = "General" })
	end
	return self._defaultSectionValue
end

function Tab.Button(self: any, options: any): any
	return self:_defaultSection():Button(options)
end

function Tab.Toggle(self: any, options: any): any
	return self:_defaultSection():Toggle(options)
end

function Tab.Slider(self: any, options: any): any
	return self:_defaultSection():Slider(options)
end

function Tab.Dropdown(self: any, options: any): any
	return self:_defaultSection():Dropdown(options)
end

function Tab.Textbox(self: any, options: any): any
	return self:_defaultSection():Textbox(options)
end

function Tab.Keybind(self: any, options: any): any
	return self:_defaultSection():Keybind(options)
end

function Tab.ColorPicker(self: any, options: any): any
	return self:_defaultSection():ColorPicker(options)
end

function Tab.Label(self: any, options: any): any
	return self:_defaultSection():Label(options)
end

function Tab.Paragraph(self: any, options: any): any
	return self:_defaultSection():Paragraph(options)
end

function Tab.Divider(self: any, options: any): any
	return self:_defaultSection():Divider(options)
end

function Tab.ProgressBar(self: any, options: any): any
	return self:_defaultSection():ProgressBar(options)
end

function Tab.Destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._maid:Destroy()
	local sections = table.clone(self._sections) :: { any }
	for _, section in sections do
		section:Destroy()
	end
	table.clear(self._sections)
	Util.unbindTheme(self._window, self._page)
	Util.unbindTheme(self._window, self._button)
	self._page:Destroy()
	self._button:Destroy()

	local window = self._window
	for index, tab in window._tabs do
		if tab == self then
			table.remove(window._tabs, index)
			break
		end
	end
	if window._activeTab == self then
		window._activeTab = nil
		local nextTab = window._tabs[1]
		if nextTab then
			window:SelectTab(nextTab)
		end
	end
end

return Tab
