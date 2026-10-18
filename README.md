# LumaUI

Uma biblioteca de interface moderna para **Roblox Luau**, criada do zero para projetos client-side. Ela oferece janelas responsivas, temas, componentes interativos, notificações, atalhos, busca por controles e importação/exportação de configurações em JSON — sem dependências externas, APIs de exploit ou acesso a arquivos.

> **Requisito:** execute a biblioteca em um `LocalScript`. A interface é criada dentro do `PlayerGui` do jogador.

## Instalação com Rojo

1. Instale o [Rojo](https://rojo.space/) e clone este repositório.
2. Gere o modelo Roblox:

   ```bash
   rojo build default.project.json -o LumaUI.rbxm
   ```

3. Importe `LumaUI.rbxm` para o Roblox Studio ou sincronize o projeto com `rojo serve`.
4. Coloque o `ModuleScript` `LumaUI` em `ReplicatedStorage` e use-o em um `LocalScript`:

   ```luau
   local ReplicatedStorage = game:GetService("ReplicatedStorage")
   local LumaUI = require(ReplicatedStorage:WaitForChild("LumaUI"))
   ```

O exemplo completo está em [`examples/Basic.client.luau`](examples/Basic.client.luau).

## Início rápido

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LumaUI = require(ReplicatedStorage:WaitForChild("LumaUI"))

local window = LumaUI.new({
    Title = "Meu painel",
    Subtitle = "Configurações do jogo",
    Theme = "Midnight", -- Dark, Light ou Midnight
    ToggleKey = Enum.KeyCode.RightShift,
})

local main = window:Tab({ Title = "Principal", Icon = "01" })
local settings = main:Section("Preferências")

settings:Toggle({
    Id = "show_hints", -- IDs estáveis permitem salvar/carregar config
    Title = "Mostrar dicas",
    Default = true,
    Callback = function(enabled)
        print("Dicas:", enabled)
    end,
})

settings:Slider({
    Id = "volume",
    Title = "Volume",
    Min = 0,
    Max = 100,
    Step = 5,
    Default = 70,
    Suffix = "%",
    Callback = function(value)
        print("Volume:", value)
    end,
})

window:Notify({
    Title = "Tudo pronto",
    Description = "A interface foi carregada com sucesso.",
    Type = "success",
    Duration = 4,
})
```

## API

### Criar e controlar a janela

```luau
local window = LumaUI.new({
    Name = "LumaUI",                 -- nome do ScreenGui
    Title = "Meu aplicativo",
    Subtitle = "Uma breve descrição",
    Theme = "Dark",                  -- "Dark", "Light", "Midnight" ou tabela customizada
    ToggleKey = Enum.KeyCode.RightShift,
    Animations = true,
    AnimationDuration = 0.16,
    IgnoreGuiInset = false,
    DisplayOrder = 20,
    Size = UDim2.fromScale(0.82, 0.78),
    Position = UDim2.fromScale(0.5, 0.5),
    Player = game:GetService("Players").LocalPlayer, -- opcional
    Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"), -- opcional
})
```

`Parent`, quando informado, deve ser um `PlayerGui`. O tamanho da janela respeita limites mínimos/máximos e a janela pode ser arrastada com mouse ou toque. Use `ToggleKey = Enum.KeyCode.None` para desativar o atalho global.

Métodos disponíveis:

- `window:Tab({ Title, Icon?, Description? })` — cria uma aba com cabeçalho e descrição opcional.
- `window:SelectTab(tab)` — seleciona uma aba.
- `window:SetVisible(boolean)`, `window:Toggle()` — mostra/oculta a interface. O atalho padrão é `RightShift`.
- `window:Minimize(boolean?)` — minimiza ou restaura o conteúdo.
- `window:SetTheme(theme)` — troca o tema em tempo real. Temas customizados podem sobrescrever apenas algumas cores; as demais usam o tema escuro.
- `window:Notify({ Title?, Description?, Type?, Duration? })` — cria uma notificação. `Type`: `info`, `success`, `warning` ou `error`; `Duration = 0` mantém a notificação até ela ser fechada.
- `window:Search(text)` — filtra controles pelo título, descrição e opções; a busca também fica na barra lateral (`Ctrl+K` para focar). Use `window:Search("")` para limpar.
- `window:ExportConfig()` — retorna `json, nil` ou `nil, erro`.
- `window:ImportConfig(json, fireCallbacks?)` — valida a configuração antes de aplicá-la; callbacks só são executados se o segundo argumento for `true`.
- `window:Destroy()` — desconecta eventos e remove a interface.

Temas customizados podem usar as chaves `Background`, `Surface`, `SurfaceAlt`, `SurfaceRaised`, `Border`, `Accent`, `AccentMuted`, `Text`, `MutedText`, `SubtleText`, `Success`, `Warning`, `Danger` e `Radius`. As chaves de cor devem ser `Color3`; `Radius` é um número não negativo (limitado a 32 px) aplicado à janela e às seções.

### Abas e seções

`Tab:Section("Nome")` cria uma seção. Os controles também podem ser adicionados diretamente à aba; nesse caso, a biblioteca cria automaticamente a seção `General`.

```luau
local tab = window:Tab({ Title = "Controles", Icon = "02" })
local section = tab:Section("Ações")

-- Ambos são válidos:
section:Button({ Title = "Executar" })
-- ou tab:Button({ Title = "Executar" })
```

Todos os controles oferecem `control:Destroy()`. Controles com estado (como Toggle, Slider e Dropdown) também têm `control:Get()` e `control:Set(value, fireCallback?)`; `Label` e `Paragraph` aceitam `Set(string)`, e `Button` tem `control:Press()`. Dropdowns também oferecem `control:SetOptions(options)`. `Set` valida o valor e, por padrão, executa o callback; passe `false` como segundo argumento para atualizar sem callback.

### Controles disponíveis

| Método | Opções principais | Valor / callback |
| --- | --- | --- |
| `Button` | `Title`, `Description`, `Callback` | `Callback()` ao ativar |
| `Toggle` | `Title`, `Description`, `Default`, `Callback` | `boolean` |
| `Slider` | `Title`, `Min`, `Max`, `Step`, `Default`, `Prefix`, `Suffix`, `Decimals`, `Format`, `Callback` | `number` |
| `Dropdown` | `Title`, `Options`, `Default`, `Multi`, `MaxVisibleOptions`, `Callback` | opção selecionada ou lista de valores |
| `Textbox` | `Title`, `Placeholder`, `Default`, `SubmitOnEnter`, `ClearOnSubmit`, `ReadOnly`, `Callback` | `string`, enviado ao perder foco |
| `Keybind` | `Title`, `Default`, `Mode`, `Changed`, `Callback` | tecla; `Mode = "Hold"` chama `Callback(true/false)` |
| `ColorPicker` | `Title`, `Default` (`Color3`), `Callback` | `Color3`; seletor HSV e campo hexadecimal |
| `ProgressBar` | `Title`, `Min`, `Max`, `Default`, `ShowPercent`, `Callback` | número; alterável com `Set` |
| `Label` | `Text` (ou `Title`) | texto atualizável com `Set(string)` |
| `Paragraph` | `Title`, `Description` (ou `Content`) | descrição atualizável com `Set(string)` |
| `Divider` | — | separador visual |

Todas as opções de controle aceitam `Id`. Os IDs precisam ser únicos na janela. Use IDs estáveis para que os valores sejam associados corretamente ao importar configurações.

Opções de dropdown podem ser valores simples (`{"Fácil", "Normal", "Difícil"}`) ou objetos `{ Name = "Fácil", Value = "easy" }`. Para `Multi = true`, `Default` deve ser uma lista de valores.

Em `Keybind`, `Default` aceita `Enum.KeyCode` ou o nome da tecla. `Escape` limpa o atalho (equivalente a `Enum.KeyCode.None`); `Changed` é chamado quando a tecla é alterada. O callback normal é ignorado quando o Roblox já processou a entrada ou um `TextBox` está em foco. Em modo `Hold`, o callback recebe `true` ao pressionar e `false` ao soltar.

### Exemplo: configuração JSON

```luau
local json, exportError = window:ExportConfig()
if not json then
    warn(exportError)
    return
end

print("Guarde esta string onde seu jogo permitir:", json)
local success, importError = window:ImportConfig(json, false)
if not success then
    warn(importError)
end
```

A biblioteca não grava arquivos nem usa APIs de exploit. A persistência fica a cargo do jogo; em experiências Roblox, use apenas serviços e armazenamento autorizados pelo servidor.

## Organização

```text
src/
  init.luau                 -- API pública
  Core/                     -- Signal, Maid, temas e utilitários
  UI/                       -- janela, abas, seções e controles
examples/
  Basic.client.luau
preview/
  index.html                -- demonstração visual interativa (não executa Roblox)
tests/
  Core.spec.luau             -- specs compatíveis com TestEZ
```

## Testes

`tests/Core.spec.luau` contém testes de unidade para `Maid`, `Signal` e os temas públicos. Execute-os em um runner [TestEZ](https://github.com/Roblox/testez) configurado no Roblox Studio. `examples/Basic.client.luau` serve como smoke test visual para os componentes da interface.

## Licença

MIT — veja [`LICENSE`](LICENSE).
