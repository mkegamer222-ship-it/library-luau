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
		end)
	end)
end
