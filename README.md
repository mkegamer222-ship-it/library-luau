# LumaUI

Biblioteca de interface para **Roblox Luau**, escrita do zero para projetos client-side. Janelas responsivas, temas, componentes interativos, notificações, busca, atalhos, configurações em JSON, **console embutido** e um **`loadstring` próprio** que executa Luau no cliente — sem dependências externas, sem APIs de exploit e sem acesso a arquivos.

> **Requisito:** rode a biblioteca em um `LocalScript`. A interface é criada dentro do `PlayerGui` do jogador.

---

## Roteiro do tutorial

| # | Capítulo | O que você aprende |
| --- | --- | --- |
| 1 | [Instalação](#1-instalação) | Como colocar a LumaUI no seu projeto |
| 2 | [Criando a janela](#2-criando-a-janela) | Opções, atalho global e positionamento |
| 3 | [Abas e seções](#3-abas-e-seções) | Organizando o conteúdo |
| 4 | [Controles](#4-controles) | Todos os componentes, um por um |
| 5 | [Temas](#5-temas) | Presets, temas customizados e troca em tempo real |
| 6 | [Notificações](#6-notificações) | Feedback para o jogador |
| 7 | [Busca e atalhos](#7-busca-e-atalhos) | `Ctrl + K` e hotkeys |
| 8 | [Configurações em JSON](#8-configurações-em-json) | Exportar e importar preferências |
| 9 | [Console embutido](#9-console-embutido) | Executar snippets dentro da interface |
| 10 | [`loadstring` no cliente](#10-loadstring-no-cliente) | A VM Luau da própria biblioteca |

Depois do tutorial há a [referência rápida da API](#referência-rápida-da-api).

---

## 1. Instalação

### Com Rojo (recomendado)

1. Instale o [Rojo](https://rojo.space/) e clone este repositório:

   ```bash
   git clone https://github.com/seu-usuario/library-luau.git
   cd library-luau
   ```

2. Gere o modelo do Roblox:

   ```bash
   rojo build default.project.json -o LumaUI.rbxm
   ```

3. Importe `LumaUI.rbxm` no Studio, ou sincronize em tempo real com:

   ```bash
   rojo serve default.project.json
   ```

4. O `ModuleScript` `LumaUI` fica em `ReplicatedStorage`. Em qualquer `LocalScript`:

   ```luau
   local ReplicatedStorage = game:GetService("ReplicatedStorage")
   local LumaUI = require(ReplicatedStorage:WaitForChild("LumaUI"))
   ```

### Sem Rojo

Copie a pasta [`src/`](src) para dentro de um `ModuleScript` chamado `LumaUI` (em `ReplicatedStorage`) e mantenha a estrutura de pastas — a biblioteca usa `require` relativo.

### Exemplo completo

[`examples/Basic.client.luau`](examples/Basic.client.luau) contém um painel completo com todas as abas e controles. Ele serve de referência e de smoke test visual.

---

## 2. Criando a janela

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LumaUI = require(ReplicatedStorage:WaitForChild("LumaUI"))

local window = LumaUI.new({
    Name = "LumaUI",                  -- nome do ScreenGui
    Title = "Meu painel",             -- título do cabeçalho
    Subtitle = "Configurações do jogo",
    Theme = "Midnight",               -- "Dark", "Light", "Midnight", "Nord", "Amoled" ou tabela
    ToggleKey = Enum.KeyCode.RightShift, -- atalho global (None desativa)
    Animations = true,
    AnimationDuration = 0.16,
    Size = UDim2.fromScale(0.82, 0.78),
    Position = UDim2.fromScale(0.5, 0.5),
})
```

Detalhes que importam:

- A janela é arrastável pelo cabeçalho (mouse ou toque) e redimensionável pelo canto inferior direito.
- `Size` respeita limites (mínimo de 420×300, máximo de 1080×820).
- `Parent` e `Player` são opcionais; por padrão a interface entra no `PlayerGui` do jogador local.
- `ToggleKey = Enum.KeyCode.None` remove o atalho global.

Métodos da janela:

```luau
window:SetVisible(true)      -- mostra ou esconde
window:Toggle()              -- alterna a visibilidade
window:Minimize()            -- minimiza (o conteúdo some, o cabeçalho fica)
window:Minimize(false)       -- restaura
window:SelectTab(tab)        -- troca de aba
window:SetTheme("Nord")      -- troca o tema em tempo real
window:Search("volume")      -- filtra os controles
window:Notify({ Title = "Oi" })
window:ExportConfig()
window:ImportConfig(json, false)
window:Destroy()             -- remove tudo e desconecta os eventos
```

---

## 3. Abas e seções

A janela é organizada em **abas**; cada aba tem **seções**; cada seção tem **controles**.

```luau
local geral = window:Tab({
    Title = "Geral",
    Icon = "01",              -- texto curto exibido no chip da aba
    Description = "Opções básicas",
})

local acoes = geral:Section({
    Title = "Ações",
    Description = "Botões rápidos do painel",
})
```

`Section` aceita tanto uma string quanto uma tabela:

```luau
geral:Section("Ações")                       -- equivalente
geral:Section({ Title = "Ações" })           -- equivalente
```

Você também pode pular a seção e criar controles direto na aba — a LumaUI cria uma seção `General` automaticamente:

```luau
geral:Button({ Title = "Executar" })   -- cria a seção "General" sozinha
```

---

## 4. Controles

Todos os controles aceitam `Title`, `Description` e `Id`. O `Id` precisa ser único na janela e é o que permite salvar e restaurar valores.

### Button

```luau
local botao = acoes:Button({
    Id = "play",
    Title = "Tocar",
    Description = "Inicia a partida",
    Callback = function()
        print("clicou!")
    end,
})
botao:Press() -- dispara o mesmo callback do clique
```

### Toggle

```luau
local toggle = acoes:Toggle({
    Id = "hints",
    Title = "Mostrar dicas",
    Default = true,
    Callback = function(ligado)
        print("dicas:", ligado)
    end,
})

toggle:Get()      --> true
toggle:Set(false) --> atualiza e dispara o callback
```

### Slider

```luau
local volume = acoes:Slider({
    Id = "volume",
    Title = "Volume",
    Min = 0,
    Max = 100,
    Step = 5,
    Default = 70,
    Suffix = "%",
    Decimals = 0,
    Format = function(valor) return string.format("%d%%", valor) end,
    Callback = function(valor) print("volume", valor) end,
})
```

O valor é sempre limitado ao intervalo e alinhado ao `Step`.

### Dropdown

```luau
local modo = acoes:Dropdown({
    Id = "modo",
    Title = "Modo de jogo",
    Options = { "Fácil", "Normal", "Difícil" },
    Default = "Normal",
    Callback = function(valor) print("modo", valor) end,
})

-- opções avançadas
local dificuldade = acoes:Dropdown({
    Options = {
        { Name = "Fácil", Value = "easy" },
        { Name = "Normal", Value = "normal" },
    },
    Default = "easy",
})

-- múltipla seleção
local tags = acoes:Dropdown({
    Options = { "PvP", "PvE", "Ranked" },
    Multi = true,
    Default = { "PvP" },
})
```

`control:SetOptions(novasOpcoes)` troca as opções em tempo real.

### Textbox

```luau
local nick = acoes:Textbox({
    Id = "nick",
    Title = "Apelido",
    Placeholder = "Digite seu nome",
    Default = "Jogador",
    SubmitOnEnter = true,
    ClearOnSubmit = false,
    Callback = function(texto) print("apelido", texto) end,
})
```

### Keybind

```luau
local pulo = acoes:Keybind({
    Id = "pulo",
    Title = "Pular",
    Default = Enum.KeyCode.Space,   -- ou "Space"
    Mode = "Toggle",                -- "Toggle" ou "Hold"
    Changed = function(tecla) print("tecla agora", tecla.Name) end,
})
```

### ColorPicker

```luau
local cor = acoes:ColorPicker({
    Id = "cor",
    Title = "Cor do time",
    Default = Color3.fromRGB(255, 85, 120),
    Callback = function(c) print("cor", c) end,
})
```

### ProgressBar

```luau
local progresso = acoes:ProgressBar({
    Id = "download",
    Title = "Download",
    Min = 0,
    Max = 100,
    Default = 0,
    ShowPercent = true,
})
progresso:Set(42)
```

### Label, Paragraph e Divider

```luau
acoes:Label({ Text = "Versão 1.1.0" })
acoes:Paragraph({ Title = "Aviso", Description = "Reinicie o servidor para aplicar." })
acoes:Divider()
```

### Estado dos controles

| Controle | Métodos |
| --- | --- |
| Toggle, Slider, Dropdown, Textbox, Keybind, ColorPicker, ProgressBar, Label, Paragraph | `Get()`, `Set(valor, fireCallback?)` |
| Button | `Press()` |
| Dropdown | `SetOptions(opcoes)` |
| Todos | `Destroy()` |

`Set` valida o valor: se ele for inválido, a função retorna `false` e nada muda. Passe `false` como segundo argumento para atualizar a interface **sem** disparar o callback.

---

## 5. Temas

Cinco presets prontos: `Dark`, `Light`, `Midnight`, `Nord` e `Amoled`.

```luau
window:SetTheme("Nord")
```

### Tema customizado

Você pode sobrescrever apenas as cores que quiser; o resto vem do tema escuro.

```luau
window:SetTheme({
    Background = Color3.fromRGB(18, 18, 24),
    Surface = Color3.fromRGB(24, 24, 32),
    SurfaceAlt = Color3.fromRGB(30, 30, 40),
    SurfaceRaised = Color3.fromRGB(38, 38, 50),
    Border = Color3.fromRGB(60, 60, 76),
    Accent = Color3.fromRGB(120, 190, 255),
    AccentMuted = Color3.fromRGB(70, 120, 170),
    AccentText = Color3.fromRGB(10, 10, 14),
    Text = Color3.fromRGB(240, 240, 245),
    MutedText = Color3.fromRGB(170, 170, 185),
    SubtleText = Color3.fromRGB(120, 120, 135),
    Success = Color3.fromRGB(80, 210, 140),
    Warning = Color3.fromRGB(240, 190, 80),
    Danger = Color3.fromRGB(240, 90, 90),
    Radius = 14, -- número, aplicado à janela e às seções
})
```

Chaves de cor precisam ser `Color3`; `Radius` é um número não negativo (limitado a 32 px).

---

## 6. Notificações

```luau
window:Notify({
    Title = "Configuração salva",
    Description = "Suas preferências foram aplicadas.",
    Type = "success", -- "info" | "success" | "warning" | "error"
    Duration = 4,     -- segundos; 0 mantém até fechar
})
```

A notificação aparece no canto superior direito, com ícone colorido por tipo.

---

## 7. Busca e atalhos

A barra lateral tem um campo de busca. `Ctrl + K` foca o campo em qualquer momento.

```luau
window:Search("volume") -- filtra por título, descrição e opções
window:Search("")       -- limpa o filtro
```

Para hotkeys, use `Keybind` com `Mode = "Hold"`:

```luau
acoes:Keybind({
    Id = "sprint",
    Title = "Correr",
    Default = Enum.KeyCode.LeftShift,
    Mode = "Hold",
    Callback = function(pressionado)
        -- true ao segurar, false ao soltar
    end,
})
```

---

## 8. Configurações em JSON

Controles com `Id` são exportados e reimportados automaticamente.

```luau
local json, erro = window:ExportConfig()
if not json then
    warn(erro)
    return
end

-- guarde a string onde o seu jogo permitir (DataStore, HttpService, etc.)
local ok, erroImport = window:ImportConfig(json, false)
if not ok then
    warn(erroImport)
end
```

- `ExportConfig()` devolve `json, nil` ou `nil, erro`.
- `ImportConfig(json, fireCallbacks?)` valida o esquema antes de aplicar. Com `fireCallbacks = true` os callbacks também rodam; com `false` (padrão) só a interface é atualizada.
- A biblioteca **não** grava arquivos e **não** usa APIs de exploit: a persistência é responsabilidade do seu jogo, sempre dentro das regras do Roblox.

---

## 9. Console embutido

`window:Console()` cria uma aba com editor multilinha, log e botões. O código roda dentro da VM da própria biblioteca e a saída aparece dentro da interface.

```luau
local console = window:Console({
    Title = "Console",
    Icon = ">_",
    Description = "Execute snippets de Luau",
})

console.Editor.Text = "return 21 * 2"
console.Run()   -- executa
console.Clear() -- limpa o log
console.Log("mensagem manual", "info")
```

- `Ctrl + Enter` executa o conteúdo do editor.
- `print`, `warn` e `log` do código interpretado são direcionados para o log da interface.
- `Sandbox = false` libera também os globals do host; por padrão o console roda estritamente no ambiente curado.
- `MaxInstructions` limita quantos passos a VM pode executar (padrão: 250000) para travar loops infinitos.

---

## 10. `loadstring` no cliente

O Roblox removeu o compilador de strings do cliente: `loadstring` não existe em `LocalScript` e o `loadstring` do servidor vem desabilitado por padrão (`ServerScriptService.LoadStringEnabled`). Por isso a LumaUI traz uma **VM Luau própria** (lexer, parser e interpretador) que executa o mesmo código dentro do jogo.

```luau
local ok, valor, erro = LumaUI.loadstring("return 21 * 2")
-- ok = true, valor = 42
```

Quando o host realmente expõe um compilador funcional (servidores com `LoadStringEnabled`, Lune, CLI do Luau), a biblioteca usa esse caminho automaticamente. Para forçar a VM interna use `UseHostCompiler = false`.

### API do módulo

```luau
LumaUI.loadstring(source, options?)        --> ok, primeiroValor, erro
LumaUI.loadstringValues(source, options?)  --> ok, { valores }, erro
LumaUI.Loadstring.compile(source, options?)   --> chunk, erro
LumaUI.Loadstring.validate(source, options?)  --> ok, erro
LumaUI.Loadstring.sandbox(overrides?, options?) --> ambiente
LumaUI.Loadstring.environment()             --> ambiente padrão
LumaUI.Loadstring.hasHostCompiler()         --> boolean
```

### Opções

| Opção | Descrição |
| --- | --- |
| `ChunkName` | Nome exibido nos erros (padrão `"loadstring"`) |
| `Environment` | Tabela de globals usada pelo código |
| `Args` | Argumentos passados para o chunk (`...`) |
| `MaxInstructions` | Limite de passos da VM (proteção contra loop infinito) |
| `MaxDepth` | Limite de profundidade de chamadas |
| `UseHostCompiler` | `false` força a VM interna mesmo que o host tenha compilador |

### Ambiente isolado

```luau
local ambiente = LumaUI.Loadstring.sandbox({
    greeting = "olá",
})

local ok, valor = LumaUI.loadstring("return greeting .. ' mundo'", {
    Environment = ambiente,
})
-- valor = "olá mundo"
```

O ambiente padrão expõe a biblioteca padrão do Luau (`string`, `table`, `math`, `os`, `coroutine`, `task`, ...) e os globals do Roblox (`game`, `workspace`, `Instance`, `Enum`, `Color3`, `UDim2`, `Vector3`, ...). Escritas em globals ficam dentro do ambiente e **não** vazam para o jogo.

### Vários valores de retorno

```luau
local ok, valores = LumaUI.loadstringValues("return 1, 'dois', true")
-- valores = { 1, "dois", true }
```

### O que a VM suporta

- Funções, closures, recursão, métodos (`("abc"):upper()`), tabelas e tabelas aninhadas.
- `if/elseif/else`, `while`, `repeat`, `for` numérico e genérico, `break` e `continue`.
- `local`, atribuição múltipla, troca de valores, atribuição composta (`+=`, `-=`, `..=`).
- Operadores aritméticos, de comparação, lógicos, bitwise (`&`, `|`, `~`, `<<`, `>>`) e `//`.
- Funções globais Luau: `print`, `pairs`, `ipairs`, `next`, `select`, `pcall`, `xpcall`, `error`, `assert`, `tostring`, `tonumber`, `type`, `setmetatable`, `table.*`, `string.*`, `math.*`.
- Anotações de tipo Luau (`local x: number = 1`, `function f(a: string): number`), `?` opcional e `<const>`.

Não é suportado (e não é necessário no cliente): `loadstring`, `require` dinâmico, `getfenv`/`setfenv`, bytecode, corrotinas complexas e metatables com `__index`/`__newindex` customizados. Para código que precisa de acesso amplo ao engine, prefira um `LocalScript` normal.

---

## Referência rápida da API

```text
LumaUI.new(options) / LumaUI.New / LumaUI.CreateWindow   --> window
LumaUI.Version, LumaUI.Name, LumaUI.Themes, LumaUI.Maid, LumaUI.Signal
LumaUI.loadstring / LumaUI.loadstringValues / LumaUI.Loadstring / LumaUI.Console

window:Tab(options)        --> tab
window:SelectTab(tab)
window:SetVisible(visivel)
window:Toggle()
window:Minimize(estado?)
window:SetTheme(tema)
window:Search(texto)
window:Console(options?)    --> console
window:Notify(options)      --> frame da notificação
window:ExportConfig()       --> json, erro
window:ImportConfig(json, fireCallbacks?)
window:Destroy()

tab:Section(options)        --> section
tab:Button/Toggle/Slider/Dropdown/Textbox/Keybind/ColorPicker/ProgressBar/Label/Paragraph/Divider
tab:Select()
tab:Destroy()

section:Button/Toggle/Slider/Dropdown/Textbox/Keybind/ColorPicker/ProgressBar/Label/Paragraph/Divider
section:Destroy()
```

---

## Organização

```text
src/
  init.luau                     -- API pública
  Core/
    Loadstring.luau             -- API do loadstring
    LoadstringVM/               -- VM Luau: Lexer, Parser, Interpreter, Stdlib
    Maid.luau                   -- limpeza de conexões e eventos
    Signal.luau                 -- eventos com Once/Wait
    Theme.luau                  -- temas e resolução de cores
    Util.luau                   -- helpers de instância, cor, animação
  UI/
    Window.luau                 -- janela, abas, cabeçalho, notificações
    Tab.luau                    -- abas
    Section.luau                -- seções
    Controls.luau               -- todos os controles
    Console.luau                -- console com editor e log
examples/
  Basic.client.luau             -- painel completo de exemplo
preview/
  index.html                    -- demonstração visual (não executa Roblox)
tests/
  Core.spec.luau                -- specs compatíveis com TestEZ
```

---

## Testes

- [`tests/Core.spec.luau`](tests/Core.spec.luau) cobre `Maid`, `Signal`, os temas e a API do `loadstring`. Rode com um runner [TestEZ](https://github.com/Roblox/testez) configurado no Roblox Studio.
- O `loadstring` também é validado por uma suíte de 90 casos (lexer, parser, interpretador) executada fora do Studio, garantindo que a VM não dependa do compilador nativo.

---

## Limitações

- A biblioteca é **client-side**: cada jogador tem a própria interface.
- Não há persistência automática; use `ExportConfig`/`ImportConfig` com o armazenamento do seu jogo.
- A VM do `loadstring` não substitui o Roblox Luau completo: é um interpretador Luau com biblioteca padrão, feito para scripts curtos de configuração e automação leve no cliente.

---

## Licença

MIT — veja [`LICENSE`](LICENSE).
