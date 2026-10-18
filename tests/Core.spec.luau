--!strict
-- TestEZ spec: make the LumaUI ModuleScript available at ReplicatedStorage.LumaUI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LumaUI = require(ReplicatedStorage:WaitForChild("LumaUI"))

return function()
	describe("LumaUI core", function()
		describe("Maid", function()
			it("cleans replaced keyed tasks and is idempotent", function()
				local maid = LumaUI.Maid.new()
				local cleaned = 0

				maid:GiveTask(function()
					cleaned += 1
				end, "replaceable")
				maid:GiveTask(function()
					cleaned += 1
				end, "replaceable")
				expect(cleaned).to.equal(1)

				maid:Destroy()
				maid:Destroy()
				expect(cleaned).to.equal(2)
			end)

			it("cleans tasks added after destruction immediately", function()
				local maid = LumaUI.Maid.new()
				maid:Destroy()
				local cleaned = false
				maid:GiveTask(function()
					cleaned = true
				end)
				expect(cleaned).to.equal(true)
			end)
		end)

		describe("Signal", function()
			it("fires listeners and disconnects Once after the first event", function()
				local signal = LumaUI.Signal.new()
				local calls = 0
				local received = nil
				signal:Once(function(value)
					calls += 1
					received = value
				end)

				signal:Fire("first")
				task.wait()
				signal:Fire("second")
				task.wait()

				expect(calls).to.equal(1)
				expect(received).to.equal("first")
				signal:Destroy()
			end)
		end)

		describe("Themes", function()
			it("exports the built-in theme presets", function()
				expect(LumaUI.Themes.Dark).to.be.ok()
				expect(LumaUI.Themes.Light).to.be.ok()
				expect(LumaUI.Themes.Midnight).to.be.ok()
				expect(LumaUI.Themes.Midnight.Accent).to.be.a("Color3")
			end)

			it("exports the Nord and Amoled presets", function()
				expect(LumaUI.Themes.Nord).to.be.ok()
				expect(LumaUI.Themes.Amoled).to.be.ok()
				expect(LumaUI.Themes.Nord.Accent).to.be.a("Color3")
				expect(LumaUI.Themes.Amoled.Background).to.be.a("Color3")
			end)

			it("exposes the AccentText colour used by the logo", function()
				expect(LumaUI.Themes.Dark.AccentText).to.be.a("Color3")
				expect(LumaUI.Themes.Light.AccentText).to.be.a("Color3")
			end)
		end)

		describe("Loadstring", function()
			it("runs code and returns the first value", function()
				local ok, value = LumaUI.loadstring("return 21 * 2")
				expect(ok).to.equal(true)
				expect(value).to.equal(42)
			end)

			it("returns every value produced by the chunk", function()
				local ok, values = LumaUI.loadstringValues("return 1, 2, 3")
				expect(ok).to.equal(true)
				expect(#values).to.equal(3)
				expect(values[3]).to.equal(3)
			end)

			it("reports syntax errors without throwing", function()
				local ok, value, message = LumaUI.loadstring("this is not lua")
				expect(ok).to.equal(false)
				expect(value).to.equal(nil)
				expect(message).to.be.a("string")
			end)

			it("reports runtime errors without throwing", function()
				local ok, _, message = LumaUI.loadstring("error('boom')")
				expect(ok).to.equal(false)
				expect(message).to.be.a("string")
			end)

			it("validates source without running it", function()
				local ok = LumaUI.Loadstring.validate("local value = 1")
				expect(ok).to.equal(true)
				local invalid, message = LumaUI.Loadstring.validate("local = = 1")
				expect(invalid).to.equal(false)
				expect(message).to.be.a("string")
			end)

			it("exposes the curated sandbox environment", function()
				local environment = LumaUI.Loadstring.sandbox()
				expect(environment).to.be.a("table")
				expect(environment.string).to.be.a("table")
				expect(environment.math).to.be.a("table")
			end)

			it("keeps global writes inside the sandbox", function()
				local ok = LumaUI.loadstring("leaked = 5 return leaked", {
					Environment = LumaUI.Loadstring.sandbox(),
				})
				expect(ok).to.equal(true)
				expect((_G :: any).leaked).to.equal(nil)
			end)

			it("accepts custom environments and arguments", function()
				local environment = LumaUI.Loadstring.sandbox({
					greeting = "olá",
				})
				local ok, value = LumaUI.loadstring("return greeting .. ' mundo'", {
					Environment = environment,
				})
				expect(ok).to.equal(true)
				expect(value).to.equal("olá mundo")
			end)

			it("reports whether the host exposes a native compiler", function()
				expect(LumaUI.Loadstring.hasHostCompiler()).to.be.a("boolean")
			end)
		end)
	end)
end
