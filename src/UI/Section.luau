--!strict

local Util = require(script.Parent.Parent.Core.Util)
local Controls = require(script.Parent.Controls)

local Section = {}
Section.__index = Section

function Section.new(tab: any, options: any): any
	local data = if type(options) == "string" then { Title = options } else (options or {})
	local window = tab._window
	local title = tostring(data.Title or data.Name or "Section")

	local self: any = setmetatable({
		_tab = tab,
		_window = window,
		_title = title,
		_controls = {},
		_destroyed = false,
	}, Section)

	local frame = Util.new("Frame", {
		Name = "Section_" .. title,
		BackgroundColor3 = window._theme.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -2, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = false,
		LayoutOrder = #tab._sections + 1,
	}, tab._scroll)
	self._frame = frame
	local frameCorner = Util.corner(frame, window._theme.Radius)
	Util.bindTheme(window, frameCorner, "CornerRadius", "Radius", function(radius: number)
		return UDim.new(0, radius)
	end)
	Util.stroke(frame, window._theme.Border, 1, 0.58)
	Util.bindTheme(window, frame, "BackgroundColor3", "Surface")

	Util.padding(frame, 12, 12, 12, 12)
	Util.layout(frame, Enum.FillDirection.Vertical, 10)

	local headingFrame = Util.new("Frame", {
		Name = "Heading",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if title == "" then 0 else 20),
		Visible = title ~= "",
		LayoutOrder = 1,
	}, frame)
	local headingBar = Util.new("Frame", {
		Name = "Accent",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 1, 0.5, 0),
		Size = UDim2.fromOffset(3, 13),
		BackgroundColor3 = window._theme.Accent,
		BorderSizePixel = 0,
	}, headingFrame) :: Frame
	Util.corner(headingBar, 2)
	Util.bindTheme(window, headingBar, "BackgroundColor3", "Accent")

	local heading = Util.new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 11, 0, 0),
		Size = UDim2.new(1, -11, 1, 0),
		Font = Enum.Font.GothamBold,
		Text = title,
		TextColor3 = window._theme.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, headingFrame)
	self._heading = heading
	Util.bindTheme(window, heading, "TextColor3", "Text")

	local descriptionText = tostring(options.Description or "")
	if descriptionText ~= "" then
		local descriptionHolder = Util.new("Frame", {
			Name = "DescriptionHolder",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
		}, frame) :: Frame
		Util.padding(descriptionHolder, 0, 0, 0, 11)
		local description = Util.new("TextLabel", {
			Name = "Description",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -11, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = Enum.Font.Gotham,
			Text = descriptionText,
			TextColor3 = window._theme.MutedText,
			TextSize = 11,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, descriptionHolder) :: TextLabel
		Util.bindTheme(window, description, "TextColor3", "MutedText")
		self._description = description
	end

	local body = Util.new("Frame", {
		Name = "Controls",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
	}, frame)
	self._body = body
	Util.layout(body, Enum.FillDirection.Vertical, 8)

	table.insert(tab._sections, self)
	if window._searchQuery ~= "" then
		self:_refreshSearch(window._searchQuery)
	end
	return self
end

function Section._refreshSearch(self: any, query: string)
	if self._destroyed then
		return
	end

	local sectionMatches = query == "" or string.find(string.lower(self._title), query, 1, true) ~= nil
	local anyVisible = false
	for _, control in self._controls do
		if not control._destroyed then
			local controlMatches = query == "" or string.find(control._searchText, query, 1, true) ~= nil
			local visible = sectionMatches or controlMatches
			control._root.Visible = visible
			anyVisible = anyVisible or visible
		end
	end
	self._frame.Visible = query == "" or sectionMatches or anyVisible
end

function Section.Destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true

	local controls = table.clone(self._controls) :: { any }
	for _, control in controls do
		control:Destroy()
	end
	table.clear(self._controls)
	Util.unbindTheme(self._window, self._frame)
	self._frame:Destroy()

	for index, section in self._tab._sections do
		if section == self then
			table.remove(self._tab._sections, index)
			break
		end
	end
end

function Section.Button(self: any, options: any): any
	return Controls.Button(self, options)
end

function Section.Toggle(self: any, options: any): any
	return Controls.Toggle(self, options)
end

function Section.Slider(self: any, options: any): any
	return Controls.Slider(self, options)
end

function Section.Dropdown(self: any, options: any): any
	return Controls.Dropdown(self, options)
end

function Section.Textbox(self: any, options: any): any
	return Controls.Textbox(self, options)
end

function Section.Keybind(self: any, options: any): any
	return Controls.Keybind(self, options)
end

function Section.ColorPicker(self: any, options: any): any
	return Controls.ColorPicker(self, options)
end

function Section.Label(self: any, options: any): any
	return Controls.Label(self, options)
end

function Section.Paragraph(self: any, options: any): any
	return Controls.Paragraph(self, options)
end

function Section.Divider(self: any, options: any): any
	return Controls.Divider(self, options)
end

function Section.ProgressBar(self: any, options: any): any
	return Controls.ProgressBar(self, options)
end

return Section
