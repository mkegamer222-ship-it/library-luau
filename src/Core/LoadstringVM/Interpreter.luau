--!strict
-- Tree walking interpreter used by the LumaUI loadstring virtual machine.
-- It executes the AST produced by the parser and supports the most common
-- Luau constructs: locals, closures, tables, loops, methods and varargs.

export type Scope = {
	values: { [string]: any },
	declared: { [string]: boolean },
	parent: Scope?,
}

export type FunctionDefinition = {
	params: { string },
	isVararg: boolean,
	body: any,
}

export type InterpreterOptions = {
	Globals: { [string]: any },
	Fallback: { [string]: any }?,
	Args: { any }?,
	ChunkName: string?,
	MaxInstructions: number?,
	MaxDepth: number?,
}

export type InterpreterResult = {
	values: { any },
	error: string?,
}

type State = {
	globals: { [string]: any },
	fallback: { [string]: any },
	interpreted: { [any]: any },
	chunkName: string,
	instructions: number,
	maxInstructions: number,
	depth: number,
	maxDepth: number,
	line: number,
}

type Signal = {
	kind: "break" | "continue" | "return",
	values: { any }?,
}

local Interpreter = {}

local function truthy(value: any): boolean
	return value ~= nil and value ~= false
end

local function describeType(value: any): string
	local valueType = type(value)
	if valueType == "table" and getmetatable(value) ~= nil then
		return "table"
	end
	return valueType
end

function Interpreter.run(ast: any, options: InterpreterOptions): InterpreterResult
	local state: State = {
		globals = options.Globals,
		fallback = options.Fallback or {},
		interpreted = {},
		chunkName = options.ChunkName or "loadstring",
		instructions = 0,
		maxInstructions = options.MaxInstructions or 500000,
		depth = 0,
		maxDepth = options.MaxDepth or 180,
		line = 1,
	}

	local function raise(message: string): never
		error(("%s:%d: %s"):format(state.chunkName, state.line, message), 0)
	end

	local function tick()
		state.instructions += 1
		if state.instructions > state.maxInstructions then
			raise("instruction limit exceeded (possible infinite loop)")
		end
	end

	local function newScope(parent: Scope?): Scope
		return { values = {}, declared = {}, parent = parent }
	end

	local function declare(scope: Scope, name: string, value: any)
		scope.values[name] = value
		scope.declared[name] = true
	end

	local function findLocal(scope: Scope, name: string): Scope?
		local current: Scope? = scope
		while current do
			if current.declared[name] then
				return current
			end
			current = current.parent
		end
		return nil
	end

	local function readName(scope: Scope, name: string): any
		local owner = findLocal(scope, name)
		if owner then
			return owner.values[name]
		end
		local value = state.globals[name]
		if value == nil then
			return state.fallback[name]
		end
		return value
	end

	local function writeName(scope: Scope, name: string, value: any)
		local owner = findLocal(scope, name)
		if owner then
			owner.values[name] = value
			return
		end
		state.globals[name] = value
	end

	local function toNumber(value: any): number
		if type(value) == "number" then
			return value
		end
		if type(value) == "string" then
			local converted = tonumber(value)
			if converted ~= nil then
				return converted
			end
		end
		raise(("attempt to perform arithmetic on a %s value"):format(describeType(value)))
	end

	local function toConcat(value: any): string
		if type(value) == "string" then
			return value
		end
		if type(value) == "number" then
			return tostring(value)
		end
		raise(("attempt to concatenate a %s value"):format(describeType(value)))
	end

	local function toInteger(value: any): number
		local number = toNumber(value)
		if number % 1 ~= 0 then
			raise("number has no integer representation")
		end
		return number
	end

	local function toBits(value: number): number
		local bits = value % 4294967296
		if bits < 0 then
			bits += 4294967296
		end
		return bits
	end

	local function fromBits(value: number): number
		local bits = value % 4294967296
		if bits >= 2147483648 then
			bits -= 4294967296
		end
		return bits
	end

	local function bitwise(a: number, b: number, mode: string): number
		local left = toBits(a)
		local right = toBits(b)
		local result = 0
		local bit = 1
		for _ = 1, 32 do
			local leftBit = left % 2
			local rightBit = right % 2
			local output = 0
			if mode == "and" then
				if leftBit == 1 and rightBit == 1 then
					output = 1
				end
			elseif mode == "or" then
				if leftBit == 1 or rightBit == 1 then
					output = 1
				end
			else
				if leftBit ~= rightBit then
					output = 1
				end
			end
			result += output * bit
			left = math.floor(left / 2)
			right = math.floor(right / 2)
			bit *= 2
		end
		return fromBits(result)
	end

	local function lengthOf(value: any): number
		if type(value) == "string" then
			return #value
		end
		if type(value) == "table" then
			local count = 0
			while value[count + 1] ~= nil do
				count += 1
			end
			return count
		end
		raise(("attempt to get length of a %s value"):format(describeType(value)))
	end

	local function indexValue(object: any, key: any): any
		if type(object) == "string" then
			local library = state.globals.string or state.fallback.string
			if type(library) == "table" then
				local member = library[key]
				if member ~= nil then
					return member
				end
			end
			return nil
		end
		if type(object) ~= "table" then
			raise(("attempt to index a %s value"):format(describeType(object)))
		end
		return object[key]
	end

	local function computeBinary(operator: any, left: any, right: any): any
		if operator == "+" then
			return toNumber(left) + toNumber(right)
		elseif operator == "-" then
			return toNumber(left) - toNumber(right)
		elseif operator == "*" then
			return toNumber(left) * toNumber(right)
		elseif operator == "/" then
			return toNumber(left) / toNumber(right)
		elseif operator == "%" then
			return toNumber(left) % toNumber(right)
		elseif operator == "^" then
			return toNumber(left) ^ toNumber(right)
		elseif operator == "//" then
			return math.floor(toNumber(left) / toNumber(right))
		elseif operator == "<<" then
			local shift = toInteger(right)
			if shift < 0 then
				raise("shift amount is negative")
			end
			if shift >= 32 then
				return 0
			end
			return fromBits(toBits(toInteger(left)) * (2 ^ shift))
		elseif operator == ">>" then
			local shift = toInteger(right)
			if shift < 0 then
				raise("shift amount is negative")
			end
			if shift >= 32 then
				return toInteger(left) < 0 and -1 or 0
			end
			return math.floor(toInteger(left) / (2 ^ shift))
		elseif operator == "&" then
			return bitwise(toInteger(left), toInteger(right), "and")
		elseif operator == "|" then
			return bitwise(toInteger(left), toInteger(right), "or")
		elseif operator == "~" then
			return bitwise(toInteger(left), toInteger(right), "xor")
		elseif operator == ".." then
			return toConcat(left) .. toConcat(right)
		elseif operator == "==" then
			return left == right
		elseif operator == "~=" then
			return left ~= right
		elseif operator == "<" then
			return toNumber(left) < toNumber(right)
		elseif operator == "<=" then
			return toNumber(left) <= toNumber(right)
		elseif operator == ">" then
			return toNumber(left) > toNumber(right)
		elseif operator == ">=" then
			return toNumber(left) >= toNumber(right)
		end
		raise(("unknown binary operator '%s'"):format(tostring(operator)))
	end

	local eval: (node: any, scope: Scope) -> any
	local evalMulti: (node: any, scope: Scope) -> { any }
	local execBlock: (block: any, scope: Scope) -> Signal?
	local execStatement: (statement: any, scope: Scope) -> Signal?

	local function callValue(fn: any, args: { any }): { any }
		if type(fn) ~= "function" then
			raise(("attempt to call a %s value"):format(describeType(fn)))
		end

		local definition = state.interpreted[fn]
		if definition ~= nil then
			state.depth += 1
			if state.depth > state.maxDepth then
				state.depth -= 1
				raise("stack overflow")
			end

			local scope = newScope(definition.scope)
			for index, parameter in definition.definition.params do
				declare(scope, parameter, args[index])
			end
			if definition.definition.isVararg then
				local varargs: { any } = {}
				for index = #definition.definition.params + 1, args.n do
					varargs[#varargs + 1] = args[index]
				end
				declare(scope, "...", varargs)
			end

			local signal = execBlock(definition.definition.body, scope)
			state.depth -= 1
			if signal ~= nil and signal.kind == "return" then
				return signal.values or {}
			end
			return {}
		end

		local packed = table.pack(pcall(fn, table.unpack(args, 1, args.n)))
		if not packed[1] then
			raise(tostring(packed[2]))
		end
		local values: { any } = {}
		for index = 2, packed.n do
			values[index - 1] = packed[index]
		end
		return values
	end

	local function makeFunction(definition: FunctionDefinition, scope: Scope, name: string): any
		local closure: any
		closure = function(...): ...any
			local args = table.pack(...)
			local values = callValue(closure, args)
			return table.unpack(values, 1, #values)
		end
		state.interpreted[closure] = { definition = definition, scope = scope }
		return closure
	end

	local function isMultiNode(node: any): boolean
		return node.type == "Call" or node.type == "MethodCall" or node.type == "Vararg"
	end

	local function evalArguments(nodes: { any }, scope: Scope): { [any]: any }
		local values: { [any]: any } = { n = 0 }
		for index, node in nodes do
			if index == #nodes and isMultiNode(node) then
				local expanded = evalMulti(node, scope)
				for _, value in expanded do
					values.n += 1
					values[values.n] = value
				end
			else
				values.n += 1
				values[values.n] = eval(node, scope)
			end
		end
		return values
	end

	local function evalCall(node: any, scope: Scope): { any }
		tick()
		if node.type == "Call" then
			local fn = eval(node.callee, scope)
			local args = evalArguments(node.args, scope)
			return callValue(fn, args)
		end
		local object = eval(node.object, scope)
		local fn = indexValue(object, node.method)
		local evaluated = evalArguments(node.args, scope)
		local args: { [any]: any } = { n = evaluated.n + 1 }
		args[1] = object
		for index = 1, evaluated.n do
			args[index + 1] = evaluated[index]
		end
		return callValue(fn, args)
	end

	evalMulti = function(node: any, scope: Scope): { any }
		if node.type == "Call" or node.type == "MethodCall" then
			return evalCall(node, scope)
		end
		if node.type == "Vararg" then
			local owner = findLocal(scope, "...")
			if owner == nil then
				raise("cannot use '...' outside a vararg function")
			end
			local varargs = owner.values["..."]
			local copy: { any } = {}
			for index, value in varargs do
				copy[index] = value
			end
			return copy
		end
		return { eval(node, scope) }
	end

	eval = function(node: any, scope: Scope): any
		local nodeType = node.type

		if nodeType == "Number" or nodeType == "String" then
			return node.value
		elseif nodeType == "True" then
			return true
		elseif nodeType == "False" then
			return false
		elseif nodeType == "Nil" then
			return nil
		elseif nodeType == "Name" then
			return readName(scope, node.name)
		elseif nodeType == "Paren" then
			return eval(node.expression, scope)
		elseif nodeType == "Index" then
			local object = eval(node.object, scope)
			local key = eval(node.key, scope)
			return indexValue(object, key)
		elseif nodeType == "Call" or nodeType == "MethodCall" then
			local values = evalCall(node, scope)
			return values[1]
		elseif nodeType == "Vararg" then
			local values = evalMulti(node, scope)
			return values[1]
		elseif nodeType == "Table" then
			local tableValue: { [any]: any } = {}
			for index, item in node.arrayItems do
				if index == #node.arrayItems and isMultiNode(item) then
					local expanded = evalMulti(item, scope)
					for _, value in expanded do
						tableValue[#tableValue + 1] = value
					end
				else
					tableValue[#tableValue + 1] = eval(item, scope)
				end
			end
			for _, item in node.hashItems do
				tableValue[eval(item.key, scope)] = eval(item.value, scope)
			end
			return tableValue
		elseif nodeType == "Function" then
			local definition: FunctionDefinition = {
				params = node.params,
				isVararg = node.isVararg == true,
				body = node.body,
			}
			return makeFunction(definition, scope, "anonymous")
		elseif nodeType == "Unary" then
			local operator = node.operator
			if operator == "not" then
				return not truthy(eval(node.operand, scope))
			elseif operator == "-" then
				return -toNumber(eval(node.operand, scope))
			elseif operator == "#" then
				return lengthOf(eval(node.operand, scope))
			elseif operator == "~" then
				return fromBits(4294967295 - toBits(toInteger(eval(node.operand, scope))))
			end
			raise(("unknown unary operator '%s'"):format(tostring(operator)))
		elseif nodeType == "Binary" then
			local operator = node.operator

			if operator == "and" then
				local left = eval(node.left, scope)
				if not truthy(left) then
					return left
				end
				return eval(node.right, scope)
			elseif operator == "or" then
				local left = eval(node.left, scope)
				if truthy(left) then
					return left
				end
				return eval(node.right, scope)
			end

			local left = eval(node.left, scope)
			local right = eval(node.right, scope)
			return computeBinary(operator, left, right)
		end

		raise(("unsupported expression '%s'"):format(tostring(nodeType)))
	end

	local function assignTo(target: any, value: any, scope: Scope)
		if target.type == "Name" then
			writeName(scope, target.name, value)
			return
		end
		if target.type == "Index" then
			local object = eval(target.object, scope)
			local key = eval(target.key, scope)
			if type(object) ~= "table" then
				raise(("attempt to index a %s value"):format(describeType(object)))
			end
			object[key] = value
			return
		end
		raise("cannot assign to this expression")
	end

	local function evalStatementList(nodes: { any }, scope: Scope): { any }
		local values: { any } = {}
		for index, node in nodes do
			if index == #nodes and isMultiNode(node) then
				local expanded = evalMulti(node, scope)
				for _, value in expanded do
					values[#values + 1] = value
				end
			else
				values[#values + 1] = eval(node, scope)
			end
		end
		return values
	end

	execBlock = function(block: any, scope: Scope): Signal?
		for _, statement in block.body do
			tick()
			local signal = execStatement(statement, scope)
			if signal ~= nil then
				return signal
			end
		end
		return nil
	end

	local function execStatementImpl(statement: any, scope: Scope): Signal?
		local statementType = statement.type

		if statementType == "Local" then
			local values = evalStatementList(statement.values, scope)
			for index, name in statement.names do
				declare(scope, name, values[index])
			end
			return nil
		elseif statementType == "LocalFunction" then
			declare(scope, statement.name, nil)
			local definition: FunctionDefinition = {
				params = statement.func.params,
				isVararg = statement.func.isVararg == true,
				body = statement.func.body,
			}
			scope.values[statement.name] = makeFunction(definition, scope, statement.name)
			return nil
		elseif statementType == "Assign" then
			local values = evalStatementList(statement.values, scope)
			for index, target in statement.targets do
				assignTo(target, values[index], scope)
			end
			return nil
		elseif statementType == "CompoundAssign" then
			local target = statement.target
			local operand = eval(statement.value, scope)
			if target.type == "Name" then
				local current = readName(scope, target.name)
				writeName(scope, target.name, computeBinary(statement.operator, current, operand))
			elseif target.type == "Index" then
				local object = eval(target.object, scope)
				local key = eval(target.key, scope)
				if type(object) ~= "table" then
					raise(("attempt to index a %s value"):format(describeType(object)))
				end
				local current = indexValue(object, key)
				object[key] = computeBinary(statement.operator, current, operand)
			else
				raise("cannot assign to this expression")
			end
			return nil
		elseif statementType == "CallStatement" then
			evalCall(statement.call, scope)
			return nil
		elseif statementType == "Do" then
			return execBlock({ type = "Block", body = statement.body }, newScope(scope))
		elseif statementType == "If" then
			for _, clause in statement.clauses do
				if truthy(eval(clause.test, scope)) then
					return execBlock({ type = "Block", body = clause.body }, newScope(scope))
				end
			end
			if statement.orelse ~= nil then
				return execBlock({ type = "Block", body = statement.orelse }, newScope(scope))
			end
			return nil
		elseif statementType == "While" then
			while truthy(eval(statement.test, scope)) do
				tick()
				local signal = execBlock({ type = "Block", body = statement.body }, newScope(scope))
				if signal ~= nil then
					if signal.kind == "break" then
						return nil
					end
					if signal.kind == "continue" then
						continue
					end
					return signal
				end
			end
			return nil
		elseif statementType == "Repeat" then
			while true do
				tick()
				local loopScope = newScope(scope)
				local signal = execBlock({ type = "Block", body = statement.body }, loopScope)
				if signal ~= nil then
					if signal.kind == "break" then
						return nil
					end
					if signal.kind == "continue" then
						if truthy(eval(statement.test, loopScope)) then
							return nil
						end
						continue
					end
					return signal
				end
				if truthy(eval(statement.test, loopScope)) then
					return nil
				end
			end
		elseif statementType == "NumericFor" then
			local start = toNumber(eval(statement.start, scope))
			local limit = toNumber(eval(statement.limit, scope))
			local step = if statement.step ~= nil then toNumber(eval(statement.step, scope)) else 1
			if step == 0 then
				raise("'for' step is zero")
			end
			local index = start
			while (step > 0 and index <= limit) or (step < 0 and index >= limit) do
				tick()
				local loopScope = newScope(scope)
				declare(loopScope, statement.name, index)
				local signal = execBlock({ type = "Block", body = statement.body }, loopScope)
				if signal ~= nil then
					if signal.kind == "break" then
						return nil
					end
					if signal.kind == "continue" then
						index += step
						continue
					end
					return signal
				end
				index += step
			end
			return nil
		elseif statementType == "GenericFor" then
			local values = evalStatementList(statement.expressions, scope)
			local iterator = values[1]
			local stateValue = values[2]
			local control = values[3]
			while true do
				tick()
				local iteratorArgs: { [any]: any } = { n = 2 }
				iteratorArgs[1] = stateValue
				iteratorArgs[2] = control
				local results = callValue(iterator, iteratorArgs)
				local first = results[1]
				if first == nil then
					return nil
				end
				control = first
				local loopScope = newScope(scope)
				for index, name in statement.names do
					declare(loopScope, name, results[index])
				end
				local signal = execBlock({ type = "Block", body = statement.body }, loopScope)
				if signal ~= nil then
					if signal.kind == "break" then
						return nil
					end
					if signal.kind == "continue" then
						continue
					end
					return signal
				end
			end
		elseif statementType == "FunctionStatement" then
			local definition: FunctionDefinition = {
				params = statement.func.params,
				isVararg = statement.func.isVararg == true,
				body = statement.func.body,
			}
			if statement.isMethod == true then
				local parameters = { "self" }
				for _, parameter in definition.params do
					parameters[#parameters + 1] = parameter
				end
				definition.params = parameters
			end
			local fn = makeFunction(definition, scope, statement.methodName or "function")
			assignTo(statement.target, fn, scope)
			return nil
		elseif statementType == "Return" then
			local values = evalStatementList(statement.values, scope)
			return { kind = "return", values = values }
		elseif statementType == "Break" then
			return { kind = "break" }
		elseif statementType == "Continue" then
			return { kind = "continue" }
		end

		raise(("unsupported statement '%s'"):format(tostring(statementType)))
	end

	execStatement = execStatementImpl

	local ok, result = pcall(function()
		local scope = newScope(nil)
		if options.Args ~= nil then
			declare(scope, "...", options.Args)
		end
		local signal = execBlock(ast, scope)
		if signal ~= nil and signal.kind == "return" then
			return signal.values or {}
		end
		return {}
	end)

	if not ok then
		return { values = {}, error = tostring(result) }
	end

	return { values = result, error = nil }
end

return Interpreter
