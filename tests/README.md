# TestEZ specs

`Core.spec.luau` uses the standard TestEZ `describe` / `it` / `expect` API. Add this folder to a TestEZ test container (or a TestEZ runner project) and make sure the library is available as `ReplicatedStorage.LumaUI` before running the suite. The specs require no third-party code inside LumaUI itself.

The visual and interaction smoke test is `examples/Basic.client.luau`; run it from `StarterPlayerScripts` in Studio after mapping `src` to `ReplicatedStorage.LumaUI` with Rojo.
