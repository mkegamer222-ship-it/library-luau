--!strict

export type Maid = {
	GiveTask: (self: Maid, taskItem: any, key: any?) -> any,
	Remove: (self: Maid, key: any) -> (),
	DoCleaning: (self: Maid) -> (),
	Destroy: (self: Maid) -> (),
}

type InternalMaid = Maid & {
	_tasks: { [any]: any },
	_nextId: number,
	_destroyed: boolean,
}

local MaidClass = {}
MaidClass.__index = MaidClass

local function cleanupTask(taskItem: any)
	if taskItem == nil then
		return
	end

	local itemType = typeof(taskItem)
	if type(taskItem) == "function" then
		taskItem()
	elseif itemType == "RBXScriptConnection" then
		taskItem:Disconnect()
	elseif itemType == "Instance" then
		taskItem:Destroy()
	elseif type(taskItem) == "table" then
		if type(taskItem.Destroy) == "function" then
			taskItem:Destroy()
		elseif type(taskItem.Disconnect) == "function" then
			taskItem:Disconnect()
		elseif type(taskItem.Cancel) == "function" then
			taskItem:Cancel()
		elseif type(taskItem.DoCleaning) == "function" then
			taskItem:DoCleaning()
		end
	end
end

function MaidClass.new(): Maid
	local self: InternalMaid = setmetatable({
		_tasks = {},
		_nextId = 0,
		_destroyed = false,
	}, MaidClass) :: any
	return self
end

function MaidClass.GiveTask(self: InternalMaid, taskItem: any, key: any?): any
	assert(taskItem ~= nil, "Maid:GiveTask does not accept nil")
	if self._destroyed then
		cleanupTask(taskItem)
		return taskItem
	end

	local taskKey = key
	if taskKey == nil then
		self._nextId += 1
		taskKey = self._nextId
	end

	self:Remove(taskKey)
	self._tasks[taskKey] = taskItem
	return taskItem
end

function MaidClass.Remove(self: InternalMaid, key: any)
	local taskItem = self._tasks[key]
	if taskItem == nil then
		return
	end

	self._tasks[key] = nil
	cleanupTask(taskItem)
end

function MaidClass.DoCleaning(self: InternalMaid)
	local tasks = self._tasks
	self._tasks = {}

	for key, taskItem in tasks do
		tasks[key] = nil
		local ok, message = pcall(function()
			cleanupTask(taskItem)
			return true
		end)
		if not ok then
			warn(("[LumaUI] Cleanup failed: %s"):format(tostring(message)))
		end
	end
end

function MaidClass.Destroy(self: InternalMaid)
	if self._destroyed then
		return
	end

	self._destroyed = true
	self:DoCleaning()
end

return MaidClass
