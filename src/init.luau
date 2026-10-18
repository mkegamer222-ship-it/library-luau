--!strict

export type ThemeInput = "Dark" | "Light" | "Midnight" | "Nord" | "Amoled" | { [string]: any }

export type WindowOptions = {
	Name: string?,
	Title: string?,
	Subtitle: string?,
	Theme: ThemeInput?,
	ToggleKey: Enum.KeyCode | string?,
	Animations: boolean?,
	AnimationDuration: number?,
	IgnoreGuiInset: boolean?,
	DisplayOrder: number?,
	Size: UDim2?,
	Position: UDim2?,
	Player: Player?,
	Parent: PlayerGui?,
	ShowKeyHint: boolean?,
}

export type ControlOptions = {
	Title: string?,
	Name: string?,
	Description: string?,
	Id: string?,
}

export type ButtonOptions = ControlOptions & {
	Callback: (() -> ())?,
}

export type ToggleOptions = ControlOptions & {
	Default: boolean?,
	Callback: ((boolean) -> ())?,
}

export type SliderOptions = ControlOptions & {
	Min: number?,
	Max: number?,
	Step: number?,
	Default: number?,
	Prefix: string?,
	Suffix: string?,
	Decimals: number?,
	Format: ((number) -> string)?,
	Callback: ((number) -> ())?,
}

export type DropdownOption = string | number | boolean | EnumItem | Color3 | { Name: string?, Title: string?, Value: any? }
export type DropdownOptions = ControlOptions & {
	Options: { DropdownOption },
	Default: any?,
	Multi: boolean?,
	MaxVisibleOptions: number?,
	Callback: ((any) -> ())?,
}

export type TextboxOptions = ControlOptions & {
	Placeholder: string?,
	Default: string?,
	SubmitOnEnter: boolean?,
	ClearOnSubmit: boolean?,
	ReadOnly: boolean?,
	Callback: ((string) -> ())?,
}

export type KeybindOptions = ControlOptions & {
	Default: Enum.KeyCode | string?,
	Mode: "Toggle" | "Hold"?,
	Callback: ((any) -> ())?,
	Changed: ((Enum.KeyCode) -> ())?,
}

export type ColorPickerOptions = ControlOptions & {
	Default: Color3?,
	Callback: ((Color3) -> ())?,
}

export type ProgressBarOptions = ControlOptions & {
	Min: number?,
	Max: number?,
	Default: number?,
	ShowPercent: boolean?,
	Callback: ((number) -> ())?,
}

export type LabelOptions = ControlOptions & {
	Text: string?,
}

export type ParagraphOptions = ControlOptions & {
	Content: string?,
	Text: string?,
}

export type StateControl<T> = {
	Id: string,
	Kind: string,
	Root: GuiObject,
	Get: (self: StateControl<T>) -> T,
	Set: (self: StateControl<T>, value: T, fireCallback: boolean?) -> boolean,
	Destroy: (self: StateControl<T>) -> (),
}

export type ActionControl = {
	Id: string,
	Kind: string,
	Root: GuiObject,
	Press: (self: ActionControl) -> (),
	Destroy: (self: ActionControl) -> (),
}

export type DropdownControl = StateControl<any> & {
	SetOptions: (self: DropdownControl, options: { DropdownOption }) -> boolean,
}

export type Section = {
	Button: (self: Section, options: ButtonOptions | string) -> ActionControl,
	Toggle: (self: Section, options: ToggleOptions | string) -> StateControl<boolean>,
	Slider: (self: Section, options: SliderOptions | string) -> StateControl<number>,
	Dropdown: (self: Section, options: DropdownOptions | string) -> DropdownControl,
	Textbox: (self: Section, options: TextboxOptions | string) -> StateControl<string>,
	Keybind: (self: Section, options: KeybindOptions | string) -> StateControl<Enum.KeyCode>,
	ColorPicker: (self: Section, options: ColorPickerOptions | string) -> StateControl<Color3>,
	ProgressBar: (self: Section, options: ProgressBarOptions | string) -> StateControl<number>,
	Label: (self: Section, options: LabelOptions | string) -> StateControl<string>,
	Paragraph: (self: Section, options: ParagraphOptions | string) -> StateControl<string>,
	Divider: (self: Section, options: ControlOptions?) -> { Destroy: (self: any) -> () },
	Destroy: (self: Section) -> (),
}

export type TabOptions = {
	Title: string?,
	Name: string?,
	Icon: string?,
	Description: string?,
}

export type Tab = {
	Section: (self: Tab, options: string | { Title: string?, Name: string? }) -> Section,
	Select: (self: Tab) -> (),
	Button: (self: Tab, options: ButtonOptions | string) -> ActionControl,
	Toggle: (self: Tab, options: ToggleOptions | string) -> StateControl<boolean>,
	Slider: (self: Tab, options: SliderOptions | string) -> StateControl<number>,
	Dropdown: (self: Tab, options: DropdownOptions | string) -> DropdownControl,
	Textbox: (self: Tab, options: TextboxOptions | string) -> StateControl<string>,
	Keybind: (self: Tab, options: KeybindOptions | string) -> StateControl<Enum.KeyCode>,
	ColorPicker: (self: Tab, options: ColorPickerOptions | string) -> StateControl<Color3>,
	ProgressBar: (self: Tab, options: ProgressBarOptions | string) -> StateControl<number>,
	Label: (self: Tab, options: LabelOptions | string) -> StateControl<string>,
	Paragraph: (self: Tab, options: ParagraphOptions | string) -> StateControl<string>,
	Divider: (self: Tab, options: ControlOptions?) -> { Destroy: (self: any) -> () },
	Destroy: (self: Tab) -> (),
}

export type NotificationOptions = {
	Title: string?,
	Description: string?,
	Type: "info" | "success" | "warning" | "error" | "danger"?,
	Duration: number?,
}

export type Window = {
	Tab: (self: Window, options: TabOptions | string) -> Tab,
	SelectTab: (self: Window, tab: Tab) -> (),
	SetVisible: (self: Window, visible: boolean) -> (),
	Toggle: (self: Window) -> (),
	Minimize: (self: Window, minimized: boolean?) -> (),
	SetTheme: (self: Window, theme: ThemeInput) -> (),
	Search: (self: Window, query: string?) -> (),
	Console: (self: Window, options: ConsoleOptions?) -> Console?,
	Notify: (self: Window, options: NotificationOptions | string) -> Frame?,
	ExportConfig: (self: Window) -> (string?, string?),
	ImportConfig: (self: Window, serialized: string, fireCallbacks: boolean?) -> (boolean, string?),
	Destroy: (self: Window) -> (),
}

export type LoadstringOptions = {
	ChunkName: string?,
	Environment: { [string]: any }?,
	Args: { any }?,
	MaxInstructions: number?,
	MaxDepth: number?,
	UseHostCompiler: boolean?,
}

export type LoadstringResult = {
	Success: boolean,
	Values: { any },
	Error: string?,
}

export type LoadstringApi = {
	compile: (source: string, options: LoadstringOptions?) -> (any?, string?),
	run: (source: string, options: LoadstringOptions?) -> (boolean, any, string?),
	runValues: (source: string, options: LoadstringOptions?) -> (boolean, { any }, string?),
	validate: (source: string, options: LoadstringOptions?) -> (boolean, string?),
	sandbox: (overrides: { [string]: any }?) -> { [string]: any },
	environment: () -> { [string]: any },
	hasHostCompiler: () -> boolean,
}

export type ConsoleOptions = {
	Title: string?,
	Icon: string?,
	Description: string?,
	Placeholder: string?,
	Sandbox: boolean?,
	MaxInstructions: number?,
}

export type Console = {
	Tab: Tab,
	Editor: TextBox,
	Output: ScrollingFrame,
	Run: () -> (),
	Clear: () -> (),
	Log: (text: string, kind: string?) -> (),
}

export type LibraryApi = {
	Name: string,
	Version: string,
	new: (options: WindowOptions?) -> Window,
	New: (options: WindowOptions?) -> Window,
	CreateWindow: (options: WindowOptions?) -> Window,
	Maid: any,
	Signal: any,
	Themes: { [string]: any },
	Loadstring: LoadstringApi,
	loadstring: (source: string, options: LoadstringOptions?) -> (boolean, any, string?),
	loadstringValues: (source: string, options: LoadstringOptions?) -> (boolean, { any }, string?),
	Console: (window: Window, options: ConsoleOptions?) -> Console?,
}

local WindowModule = require(script.UI.Window)
local Console = require(script.UI.Console)
local Loadstring = require(script.Core.Loadstring)
local Maid = require(script.Core.Maid)
local Signal = require(script.Core.Signal)
local Theme = require(script.Core.Theme)

local Library: LibraryApi = {
	Name = "LumaUI",
	Version = WindowModule.Version,
	new = WindowModule.new,
	New = WindowModule.new,
	CreateWindow = WindowModule.new,
	Maid = Maid,
	Signal = Signal,
	Themes = Theme.Presets,
	Loadstring = Loadstring,
	loadstring = Loadstring.run,
	loadstringValues = Loadstring.runValues,
	Console = Console.new,
}

return Library
