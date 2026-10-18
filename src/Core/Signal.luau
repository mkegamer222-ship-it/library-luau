--!strict

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, callback: (...any) -> ()) -> Connection,
	Once: (self: Signal, callback: (...any) -> ()) -> Connection,
	Wait: (self: Signal) -> ...any,
	Fire: (self: Signal, ...any) -> (),
	Destroy: (self: Signal) -> (),
}

type InternalConnection = Connection & {
	_signal: any,
	_callback: (...any) -> (),
}

type InternalSignal = Signal & {
	_connections: { InternalConnection },
	_destroyed: boolean,
}

local SignalClass = {}
SignalClass.__index = SignalClass

local ConnectionClass = {}
ConnectionClass.__index = ConnectionClass

function ConnectionClass.Disconnect(self: InternalConnection)
	if not self.Connected then
		return
	end

	self.Connected = false
	local signal = self._signal
	self._signal = nil
	self._callback = function() end

	if signal and not signal._destroyed then
		for index = #signal._connections, 1, -1 do
			if signal._connections[index] == self then
				table.remove(signal._connections, index)
				break
			end
		end
	end
end

function SignalClass.new(): Signal
	local self: InternalSignal = setmetatable({
		_connections = {},
		_destroyed = false,
	}, SignalClass) :: any
	return self
end

function SignalClass.Connect(self: InternalSignal, callback: (...any) -> ()): Connection
	assert(type(callback) == "function", "Signal:Connect expects a function")

	local connection: InternalConnection = setmetatable({
		Connected = not self._destroyed,
		_signal = self,
		_callback = callback,
	}, ConnectionClass) :: any

	if connection.Connected then
		table.insert(self._connections, connection)
	end

	return connection
end

function SignalClass.Once(self: InternalSignal, callback: (...any) -> ()): Connection
	local connection: Connection? = nil
	connection = self:Connect(function(...)
		if connection then
			connection:Disconnect()
		end
		callback(...)
	end)
	return connection :: Connection
end

function SignalClass.Wait(self: InternalSignal): ...any
	assert(not self._destroyed, "Cannot wait on a destroyed signal")
	local thread = coroutine.running()
	assert(thread ~= nil, "Signal:Wait must be called from a coroutine")

	local connection: Connection? = nil
	connection = self:Connect(function(...)
		if connection then
			connection:Disconnect()
		end
		task.spawn(thread, ...)
	end)

	return coroutine.yield()
end

function SignalClass.Fire(self: InternalSignal, ...: any)
	if self._destroyed then
		return
	end

	local listeners = table.clone(self._connections)
	for _, connection in listeners do
		if connection.Connected then
			task.spawn(connection._callback, ...)
		end
	end
end

function SignalClass.Destroy(self: InternalSignal)
	if self._destroyed then
		return
	end

	self._destroyed = true
	for _, connection in self._connections do
		connection.Connected = false
		connection._signal = nil
		connection._callback = function() end
	end
	table.clear(self._connections)
end

return SignalClass
