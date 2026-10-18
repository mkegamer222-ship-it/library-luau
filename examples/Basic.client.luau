--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LumaUI = require(ReplicatedStorage:WaitForChild("LumaUI"))
local window = LumaUI.new({
	Title = "LumaUI",
	Subtitle = "Exemplo de componentes e temas",
	Theme = "Dark",
	ToggleKey = Enum.KeyCode.RightShift,
	Animations = true,
})

local home = window:Tab({ Title = "Início", Icon = "01", Description = "Visão geral do seu painel" })
local overview = home:Section("Visão geral")
overview:Paragraph({
	Title = "Bem-vindo",
	Description = "Uma interface Luau leve, personalizável e pronta para usar no seu jogo.",
})
overview:Button({
	Title = "Mostrar notificação",
	Description = "Dispare uma notificação de exemplo.",
	Callback = function()
		window:Notify({
			Title = "Ação concluída",
			Description = "O botão foi ativado.",
			Type = "success",
			Duration = 3,
		})
	end,
})

local controlsTab = window:Tab({ Title = "Controles", Icon = "02", Description = "Ajuste preferências, atalhos e valores" })
local controls = controlsTab:Section("Interação")
controls:Toggle({
	Id = "notifications_enabled",
	Title = "Notificações",
	Description = "Ativa notificações locais neste exemplo.",
	Default = true,
	Callback = function(enabled: boolean)
		print("Notificações ativadas:", enabled)
	end,
})
controls:Slider({
	Id = "master_volume",
	Title = "Volume principal",
	Min = 0,
	Max = 100,
	Step = 5,
	Default = 65,
	Suffix = "%",
	Callback = function(value: number)
		print("Volume:", value)
	end,
})
controls:Dropdown({
	Id = "difficulty",
	Title = "Dificuldade",
	Options = {
		{ Name = "Tranquilo", Value = "easy" },
		{ Name = "Normal", Value = "normal" },
		{ Name = "Desafio", Value = "hard" },
	},
	Default = "normal",
	Callback = function(value: string)
		print("Dificuldade:", value)
	end,
})
controls:Dropdown({
	Id = "active_modes",
	Title = "Modos ativos",
	Options = { "Exploração", "Construção", "Competitivo", "Treino" },
	Multi = true,
	Default = { "Exploração", "Treino" },
	Callback = function(values: { string })
		print("Modos:", table.concat(values, ", "))
	end,
})
controls:Textbox({
	Id = "player_note",
	Title = "Anotação",
	Placeholder = "Escreva algo e pressione Enter...",
	SubmitOnEnter = true,
	Callback = function(value: string)
		print("Anotação:", value)
	end,
})
controls:Keybind({
	Id = "action_key",
	Title = "Atalho de ação",
	Default = Enum.KeyCode.G,
	Mode = "Toggle" :: "Toggle",
	Callback = function()
		window:Notify({ Title = "Atalho", Description = "Você pressionou G.", Duration = 2 })
	end,
	Changed = function(keyCode: Enum.KeyCode)
		print("Novo atalho:", keyCode.Name)
	end,
})
controls:ColorPicker({
	Id = "accent_color",
	Title = "Cor de destaque",
	Default = Color3.fromRGB(121, 112, 255),
	Callback = function(color: Color3)
		print("Cor:", color)
	end,
})

local status = controls:Label({ Text = "Progresso: 35%" })
local progress = controls:ProgressBar({
	Id = "loading_progress",
	Title = "Carregamento",
	Min = 0,
	Max = 100,
	Default = 35,
})
controls:Button({
	Title = "Avançar progresso",
	Callback = function()
		local nextValue = math.min(progress:Get() + 10, 100)
		progress:Set(nextValue, false)
		status:Set(("Progresso: %d%%"):format(nextValue), false)
	end,
})

local appearance = window:Tab({ Title = "Aparência", Icon = "03", Description = "Personalize as cores e a busca" })
local appearanceSection = appearance:Section("Temas")
appearanceSection:Dropdown({
	Title = "Tema da interface",
	Options = { "Dark", "Light", "Midnight" },
	Default = "Midnight",
	Callback = function(themeName: "Dark" | "Light" | "Midnight")
		window:SetTheme(themeName)
	end,
})
appearanceSection:Button({
	Title = "Buscar controles",
	Description = "Filtra por texto; limpe a busca com outra chamada.",
	Callback = function()
		window:Search("volume")
		window:SelectTab(controlsTab)
		window:Notify({ Title = "Busca aplicada", Description = "Mostrando controles correspondentes a volume." })
	end,
})
appearanceSection:Button({
	Title = "Limpar busca",
	Callback = function()
		window:Search("")
	end,
})
appearanceSection:Button({
	Title = "Alternar janela",
	Callback = function()
		window:Toggle()
	end,
})

-- A biblioteca não escolhe um mecanismo de armazenamento para o jogo.
local configString: string? = nil
local configTab = window:Tab({ Title = "Configuração", Icon = "04", Description = "Importe e exporte suas preferências" })
local configSection = configTab:Section("Importar e exportar")
configSection:Button({
	Title = "Exportar configuração",
	Callback = function()
		local json, message = window:ExportConfig()
		if json then
			configString = json
			print("Config JSON:", json)
			window:Notify({ Title = "Config exportada", Description = "A string foi impressa no Output." })
		else
			warn(message)
		end
	end,
})
configSection:Button({
	Title = "Importar última configuração",
	Callback = function()
		if configString then
			local success, message = window:ImportConfig(configString, false)
			window:Notify({
				Title = if success then "Config importada" else "Falha na importação",
				Description = if success then "Os valores foram restaurados." else tostring(message),
				Type = if success then "success" else "error",
			})
		else
			window:Notify({ Title = "Sem configuração", Description = "Exporte uma configuração primeiro.", Type = "warning" })
		end
	end,
})

-- Este exemplo deve ser executado em um LocalScript.
