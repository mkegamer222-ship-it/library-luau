--!strict
-- Ready to use console tab. It runs Luau snippets through the LumaUI
-- loadstring virtual machine and prints the output inside the interface.

local UserInputService = game:GetService("UserInputService")

local Loadstring = require(script.Parent.Parent.Core.Loadstring)
local Util = require(script.Parent.Parent.Core.Util)

local Console = {}

export type ConsoleOptions = {
	Title: string?,
	Icon: string?,
	Description: string?,
	Placeholder: string?,
	Sandbox: boolean?,
	MaxInstructions: number?,
}

local function concatArguments(...: any): string
	local parts: { string } = {}
	for index = 1, select("#", ...) do
		parts[#parts + 1] = tostring((select(index, ...)))
	end
	return table.concat(parts, " ")
end

function Console.new(window: any, options: any?): any
	local data = if type(options) == "table" then options else {}
	local title = tostring(data.Title or "Console")
	local icon = tostring(data.Icon or ">_")
	local placeholder = tostring(data.Placeholder or "-- cole seu codigo Luau aqui")

	local tab = window:Tab({
		Title = title,
		Icon = icon,
		Description = tostring(data.Description or "Execute snippets de Luau no cliente"),
	})

	local editorSection = tab:Section({
		Title = "Editor",
		Description = "Use Ctrl + Enter para executar o codigo.",
	})
	local body = editorSection._body

	local editor = Util.new("TextBox", {
		Name = "Editor",
		Size = UDim2.new(1, 0, 0, 156),
		BackgroundColor3 = window._theme.SurfaceAlt,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		MultiLine = true,
		Font = Enum.Font.Code,
		PlaceholderColor3 = window._theme.SubtleText,
		PlaceholderText = placeholder,
		Text = "",
		TextColor3 = window._theme.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		LayoutOrder = 1,
	}, body) :: TextBox
	Util.corner(editor, 8)
	local editorOutline = Util.stroke(editor, window._theme.Border, 1, 0.5)
	Util.padding(editor, 8, 10, 8, 10)
	Util.bindTheme(window, editor, "BackgroundColor3", "SurfaceAlt")
	Util.bindTheme(window, editor, "PlaceholderColor3", "SubtleText")
	Util.bindTheme(window, editor, "TextColor3", "Text")
	Util.bindTheme(window, editorOutline, "Color", "Border")

	local actions = Util.new("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 2,
	}, body) :: Frame

	local function makeActionButton(name: string, text: string, order: number, offset: number, filled: boolean): TextButton
		local button = Util.new("TextButton", {
			Name = name,
			Position = UDim2.new(0, offset, 0, 0),
			Size = UDim2.fromOffset(112, 32),
			BackgroundColor3 = if filled then window._theme.Accent else window._theme.SurfaceAlt,
			BackgroundTransparency = if filled then 0 else 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Font = Enum.Font.GothamBold,
			Text = text,
			TextColor3 = if filled then window._theme.AccentText else window._theme.Text,
			TextSize = 12,
			LayoutOrder = order,
		}, actions) :: TextButton
		Util.corner(button, 8)
		Util.bindTheme(window, button, "BackgroundColor3", if filled then "Accent" else "SurfaceAlt")
		Util.bindTheme(window, button, "TextColor3", if filled then "AccentText" else "Text")
		if not filled then
			local outline = Util.stroke(button, window._theme.Border, 1, 0.6)
			Util.bindTheme(window, outline, "Color", "Border")
		end
		return button
	end

	local runButton = makeActionButton("Run", "Executar", 1, 0, true)
	local clearButton = makeActionButton("Clear", "Limpar", 2, 120, false)

	local outputSection = tab:Section({
		Title = "Saida",
		Description = "Resultado da ultima execucao.",
	})
	local outputBody = outputSection._body
	local log = Util.new("ScrollingFrame", {
		Name = "Output",
		Active = true,
		Size = UDim2.new(1, 0, 0, 190),
		BackgroundColor3 = window._theme.SurfaceAlt,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = window._theme.Accent,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		LayoutOrder = 1,
	}, outputBody) :: ScrollingFrame
	Util.corner(log, 8)
	local logOutline = Util.stroke(log, window._theme.Border, 1, 0.5)
	Util.padding(log, 6, 6, 6, 6)
	Util.layout(log, Enum.FillDirection.Vertical, 3)
	Util.bindTheme(window, log, "BackgroundColor3", "SurfaceAlt")
	Util.bindTheme(window, log, "ScrollBarImageColor3", "Accent")
	Util.bindTheme(window, logOutline, "Color", "Border")

	local logIndex = 0
	local function logLine(text: string, kind: string?)
		logIndex += 1
		local color = window._theme.Text
		if kind == "success" then
			color = window._theme.Success
		elseif kind == "error" then
			color = window._theme.Danger
		elseif kind == "muted" then
			color = window._theme.MutedText
		end
		local line = Util.new("TextLabel", {
			Name = "Line",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = Enum.Font.Code,
			Text = text,
			TextColor3 = color,
			TextSize = 11,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = logIndex,
		}, log) :: TextLabel
		Util.bindTheme(window, line, "TextColor3", if kind == "success" then "Success" else if kind == "error" then "Danger" else if kind == "muted" then "MutedText" else "Text")
		task.defer(function()
			if log.CanvasPosition.Y < log.AbsoluteCanvasSize.Y then
				log.CanvasPosition = Vector2.new(0, math.max(log.AbsoluteCanvasSize.Y - log.AbsoluteSize.Y, 0))
			end
		end)
		return line
	end

	local environment = Loadstring.sandbox({
		print = function(...: any)
			logLine(concatArguments(...), "muted")
		end,
		warn = function(...: any)
			logLine(concatArguments(...), "muted")
		end,
		log = function(...: any)
			logLine(concatArguments(...), "muted")
		end,
	}, { Strict = data.Sandbox ~= false })

	local function execute()
		local code = editor.Text
		if code == nil or string.match(code, "^%s*$") ~= nil then
			logLine("Nada para executar.", "muted")
			return
		end
		logLine("> " .. code, "muted")
		local ok, value, errorMessage = Loadstring.run(code, {
			ChunkName = "LumaUI.Console",
			Environment = environment,
			MaxInstructions = if type(data.MaxInstructions) == "number" then data.MaxInstructions else 250000,
		})
		if ok then
			if value ~= nil then
				logLine("= " .. tostring(value), "success")
			end
		else
			logLine("x " .. tostring(errorMessage), "error")
		end
	end

	local function clearLog()
		for _, child in log:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		logIndex = 0
		log.CanvasPosition = Vector2.zero
	end

	runButton.Activated:Connect(execute)
	clearButton.Activated:Connect(clearLog)

	window._maid:GiveTask(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if UserInputService:GetFocusedTextBox() ~= editor then
			return
		end
		if input.KeyCode == Enum.KeyCode.Enter and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			execute()
		end
	end))

	logLine("Console pronta. Digite o codigo e pressione Executar.", "muted")

	return {
		Tab = tab,
		Editor = editor,
		Output = log,
		Run = execute,
		Clear = clearLog,
		Log = logLine,
	}
end

return Console
