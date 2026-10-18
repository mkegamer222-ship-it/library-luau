--!strict
-- Recursive descent parser used by the LumaUI loadstring virtual machine.
-- It turns a token list into an abstract syntax tree that the interpreter walks.

local Lexer = require(script.Parent.Lexer)

export type Node = { [string]: any }

export type ParseResult = {
	Ast: Node?,
	Error: string?,
}

local Parser = {}

type ParserState = {
	tokens: { Lexer.Token },
	position: number,
}

local function current(self: ParserState): Lexer.Token
	return self.tokens[self.position]
end

local function peek(self: ParserState, offset: number): Lexer.Token
	return self.tokens[math.min(self.position + offset, #self.tokens)]
end

local function advance(self: ParserState): Lexer.Token
	local token = self.tokens[self.position]
	if token.Type ~= "EOF" then
		self.position += 1
	end
	return token
end

local typeKeywords: { [string]: boolean } = {
	["then"] = true,
	["do"] = true,
	["end"] = true,
	["else"] = true,
	["elseif"] = true,
	["until"] = true,
	["return"] = true,
	["local"] = true,
	["if"] = true,
	["while"] = true,
	["for"] = true,
	["in"] = true,
	["function"] = true,
	["repeat"] = true,
	["break"] = true,
	["continue"] = true,
	["and"] = true,
	["or"] = true,
	["not"] = true,
	["nil"] = true,
	["true"] = true,
	["false"] = true,
}

local function isSymbol(self: ParserState, value: string): boolean
	local token = current(self)
	return token.Type == "Symbol" and token.Value == value
end

local function isKeyword(self: ParserState, value: string): boolean
	local token = current(self)
	return token.Type == "Keyword" and token.Value == value
end

local function matchSymbol(self: ParserState, value: string): boolean
	if isSymbol(self, value) then
		advance(self)
		return true
	end
	return false
end

local function matchKeyword(self: ParserState, value: string): boolean
	if isKeyword(self, value) then
		advance(self)
		return true
	end
	return false
end

local function describe(token: Lexer.Token): string
	if token.Type == "EOF" then
		return "<eof>"
	end
	return tostring(token.Value)
end

local function fail(self: ParserState, message: string): string
	return ("%s on line %d"):format(message, current(self).Line)
end

local function expectSymbol(self: ParserState, value: string): (boolean, string?)
	if not matchSymbol(self, value) then
		return false, fail(self, ("'%s' expected near '%s'"):format(value, describe(current(self))))
	end
	return true, nil
end

local function expectKeyword(self: ParserState, value: string): (boolean, string?)
	if not matchKeyword(self, value) then
		return false, fail(self, ("'%s' expected near '%s'"):format(value, describe(current(self))))
	end
	return true, nil
end

local function expectName(self: ParserState): (string?, string?)
	local token = current(self)
	if token.Type ~= "Name" then
		return nil, fail(self, ("<name> expected near '%s'"):format(describe(token)))
	end
	advance(self)
	return token.Value, nil
end

local parseExpression: (...any) -> (Node?, string?)
local parseStatement: (self: ParserState) -> (Node?, string?)
local parsePower: (self: ParserState) -> (Node?, string?)

-- Skips a type annotation (`number`, `string?`, `{ [string]: number }`, ...) and
-- the optional `<const>` / `<close>` attributes used by Luau.
local function skipTypeAnnotation(self: ParserState)
	local depth = 0
	while true do
		local token = current(self)
		if token.Type == "EOF" then
			return
		end
		if token.Type == "Symbol" then
			if depth == 0 then
				if token.Value == "=" or token.Value == "," or token.Value == ")" or token.Value == "]"
					or token.Value == "}" or token.Value == ";" then
					return
				end
			end
			if token.Value == "(" or token.Value == "[" or token.Value == "{" then
				depth += 1
			elseif token.Value == ")" or token.Value == "]" or token.Value == "}" then
				depth -= 1
				if depth < 0 then
					depth = 0
				end
			end
		elseif depth == 0 and token.Type == "Keyword" and typeKeywords[token.Value] then
			return
		end
		advance(self)
	end
end

local function skipAttributes(self: ParserState)
	if not isSymbol(self, "<") then
		return
	end
	advance(self)
	local depth = 1
	while depth > 0 do
		local token = current(self)
		if token.Type == "EOF" then
			return
		end
		if token.Type == "Symbol" then
			if token.Value == "<" then
				depth += 1
			elseif token.Value == ">" then
				depth -= 1
			end
		end
		advance(self)
	end
end

local function parseBlock(self: ParserState): ({ Node }, string?)
	local body: { Node } = {}
	while true do
		local token = current(self)
		if token.Type == "EOF" then
			break
		end
		if token.Type == "Keyword" then
			local keyword = token.Value
			if keyword == "end" or keyword == "else" or keyword == "elseif" or keyword == "until" then
				break
			end
		end
		local statement, errorMessage = parseStatement(self)
		if errorMessage ~= nil then
			return body, errorMessage
		end
		if statement ~= nil then
			table.insert(body, statement)
		end
	end
	return body, nil
end

local function parseExpressionList(self: ParserState): ({ Node }, string?)
	local expressions: { Node } = {}
	while true do
		local expression, errorMessage = parseExpression(self)
		if errorMessage ~= nil or expression == nil then
			return expressions, errorMessage
		end
		table.insert(expressions, expression)
		if not matchSymbol(self, ",") then
			break
		end
	end
	return expressions, nil
end

local function parseFunctionBody(self: ParserState): (Node?, string?)
	local ok, errorMessage = expectSymbol(self, "(")
	if not ok then
		return nil, errorMessage
	end
	local parameters: { string } = {}
	local isVararg = false
	if not isSymbol(self, ")") then
		while true do
			if matchSymbol(self, "...") then
				isVararg = true
				break
			end
			local name, nameError = expectName(self)
			if nameError ~= nil then
				return nil, nameError
			end
			table.insert(parameters, name :: string)
			skipAttributes(self)
			if matchSymbol(self, ":") then
				skipTypeAnnotation(self)
			end
			if not matchSymbol(self, ",") then
				break
			end
		end
	end
	local okClose, closeError = expectSymbol(self, ")")
	if not okClose then
		return nil, closeError
	end
	if matchSymbol(self, ":") then
		skipTypeAnnotation(self)
	end
	local body, bodyError = parseBlock(self)
	if bodyError ~= nil then
		return nil, bodyError
	end
	local okEnd, endError = expectKeyword(self, "end")
	if not okEnd then
		return nil, endError
	end
	return {
		type = "Function",
		params = parameters,
		isVararg = isVararg,
		body = { type = "Block", body = body },
	}, nil
end

local function parsePrimary(self: ParserState): (Node?, string?)
	local token = current(self)

	if token.Type == "Number" then
		advance(self)
		return { type = "Number", value = token.Value }, nil
	end

	if token.Type == "String" then
		advance(self)
		return { type = "String", value = token.Value }, nil
	end

	if token.Type == "Keyword" then
		if token.Value == "nil" then
			advance(self)
			return { type = "Nil" }, nil
		end
		if token.Value == "true" then
			advance(self)
			return { type = "True" }, nil
		end
		if token.Value == "false" then
			advance(self)
			return { type = "False" }, nil
		end
		if token.Value == "function" then
			advance(self)
			return parseFunctionBody(self)
		end
	end

	if token.Type == "Symbol" and token.Value == "{" then
		advance(self)
		local arrayItems: { Node } = {}
		local hashItems: { { key: Node, value: Node } } = {}
		while not isSymbol(self, "}") do
			if isSymbol(self, "[") then
				advance(self)
				local key, keyError = parseExpression(self)
				if keyError ~= nil then
					return nil, keyError
				end
				local okAssign, assignError = expectSymbol(self, "]")
				if not okAssign then
					return nil, assignError
				end
				local okEquals, equalsError = expectSymbol(self, "=")
				if not okEquals then
					return nil, equalsError
				end
				local value, valueError = parseExpression(self)
				if valueError ~= nil then
					return nil, valueError
				end
				table.insert(hashItems, { key = key :: Node, value = value :: Node })
			elseif current(self).Type == "Name" and peek(self, 1).Type == "Symbol" and peek(self, 1).Value == "=" then
				local name = advance(self).Value
				advance(self)
				local value, valueError = parseExpression(self)
				if valueError ~= nil then
					return nil, valueError
				end
				table.insert(hashItems, { key = { type = "String", value = name }, value = value :: Node })
			else
				local value, valueError = parseExpression(self)
				if valueError ~= nil then
					return nil, valueError
				end
				table.insert(arrayItems, value :: Node)
			end
			if not (matchSymbol(self, ",") or matchSymbol(self, ";")) then
				break
			end
		end
		local okClose, closeError = expectSymbol(self, "}")
		if not okClose then
			return nil, closeError
		end
		return { type = "Table", arrayItems = arrayItems, hashItems = hashItems }, nil
	end

	if token.Type == "Symbol" and token.Value == "..." then
		advance(self)
		return { type = "Vararg" }, nil
	end

	if token.Type == "Name" then
		advance(self)
		return { type = "Name", name = token.Value }, nil
	end

	if token.Type == "Symbol" and token.Value == "(" then
		advance(self)
		local expression, expressionError = parseExpression(self)
		if expressionError ~= nil then
			return nil, expressionError
		end
		local okClose, closeError = expectSymbol(self, ")")
		if not okClose then
			return nil, closeError
		end
		return { type = "Paren", expression = expression }, nil
	end

	return nil, fail(self, ("unexpected symbol near '%s'"):format(describe(token)))
end

local function parseCallArguments(self: ParserState): ({ Node }, string?)
	local token = current(self)

	if token.Type == "String" then
		advance(self)
		return { { type = "String", value = token.Value } }, nil
	end

	if token.Type == "Symbol" and token.Value == "{" then
		local tableNode, tableError = parsePrimary(self)
		if tableError ~= nil then
			return {}, tableError
		end
		return { tableNode :: Node }, nil
	end

	local ok, errorMessage = expectSymbol(self, "(")
	if not ok then
		return {}, errorMessage
	end
	local arguments: { Node } = {}
	if not isSymbol(self, ")") then
		local listError: string? = nil
		arguments, listError = parseExpressionList(self)
		if listError ~= nil then
			return {}, listError
		end
	end
	local okClose, closeError = expectSymbol(self, ")")
	if not okClose then
		return {}, closeError
	end
	return arguments, nil
end

local function parseSuffix(self: ParserState, expression: Node): (Node?, string?)
	while true do
		local token = current(self)

		if token.Type == "Symbol" and token.Value == "." then
			advance(self)
			local name, nameError = expectName(self)
			if nameError ~= nil then
				return nil, nameError
			end
			expression = { type = "Index", object = expression, key = { type = "String", value = name } }
		elseif token.Type == "Symbol" and token.Value == "[" then
			advance(self)
			local key, keyError = parseExpression(self)
			if keyError ~= nil then
				return nil, keyError
			end
			local okClose, closeError = expectSymbol(self, "]")
			if not okClose then
				return nil, closeError
			end
			expression = { type = "Index", object = expression, key = key :: Node }
		elseif token.Type == "Symbol" and token.Value == ":" then
			advance(self)
			local name, nameError = expectName(self)
			if nameError ~= nil then
				return nil, nameError
			end
			local arguments, argumentsError = parseCallArguments(self)
			if argumentsError ~= nil then
				return nil, argumentsError
			end
			expression = { type = "MethodCall", object = expression, method = name, args = arguments }
		elseif (token.Type == "Symbol" and (token.Value == "(" or token.Value == "{")) or token.Type == "String" then
			local arguments, argumentsError = parseCallArguments(self)
			if argumentsError ~= nil then
				return nil, argumentsError
			end
			expression = { type = "Call", callee = expression, args = arguments }
		else
			return expression, nil
		end
	end
end

local function parseSimpleExpression(self: ParserState): (Node?, string?)
	local expression, errorMessage = parsePrimary(self)
	if errorMessage ~= nil or expression == nil then
		return nil, errorMessage
	end
	return parseSuffix(self, expression :: Node)
end

local function parseUnary(self: ParserState): (Node?, string?)
	local token = current(self)
	if (token.Type == "Keyword" and token.Value == "not") or (token.Type == "Symbol" and token.Value == "-") then
		advance(self)
		local operand, operandError = parseUnary(self)
		if operandError ~= nil then
			return nil, operandError
		end
		return { type = "Unary", operator = token.Value, operand = operand }, nil
	end
	if token.Type == "Symbol" and (token.Value == "#" or token.Value == "~") then
		advance(self)
		local operand, operandError = parseUnary(self)
		if operandError ~= nil then
			return nil, operandError
		end
		return { type = "Unary", operator = token.Value, operand = operand }, nil
	end
	return parsePower(self)
end

parsePower = function(self: ParserState): (Node?, string?)
	local base, baseError = parseSimpleExpression(self)
	if baseError ~= nil then
		return nil, baseError
	end
	if isSymbol(self, "^") then
		advance(self)
		local exponent, exponentError = parseUnary(self)
		if exponentError ~= nil then
			return nil, exponentError
		end
		return { type = "Binary", operator = "^", left = base, right = exponent }, nil
	end
	return base, nil
end

local compoundOperators: { [string]: string } = {
	["+="] = "+",
	["-="] = "-",
	["*="] = "*",
	["/="] = "/",
	["//="] = "//",
	["%="] = "%",
	["^="] = "^",
	["..="] = "..",
}

local binaryPrecedence: { [string]: number } = {
	["or"] = 1,
	["and"] = 2,
	["=="] = 3,
	["~="] = 3,
	["<"] = 3,
	["<="] = 3,
	[">"] = 3,
	[">="] = 3,
	["|"] = 4,
	["~"] = 5,
	["&"] = 6,
	["<<"] = 7,
	[">>"] = 7,
	[".."] = 8,
	["+"] = 9,
	["-"] = 9,
	["*"] = 10,
	["/"] = 10,
	["//"] = 10,
	["%"] = 10,
}

local parseBinary: (self: ParserState, minimumPrecedence: number) -> (Node?, string?)

parseBinary = function(self: ParserState, minimumPrecedence: number): (Node?, string?)
	local left, leftError = parseUnary(self)
	if leftError ~= nil then
		return nil, leftError
	end

	while true do
		local token = current(self)
		if token.Type ~= "Symbol" and token.Type ~= "Keyword" then
			break
		end
		local operator = token.Value
		local precedence = binaryPrecedence[operator]
		if precedence == nil or precedence < minimumPrecedence then
			break
		end
		advance(self)

		local right: Node
		if operator == ".." then
			local rightError: string? = nil
			right, rightError = parseBinary(self, precedence)
			if rightError ~= nil then
				return nil, rightError
			end
		else
			local rightError: string? = nil
			right, rightError = parseBinary(self, precedence + 1)
			if rightError ~= nil then
				return nil, rightError
			end
		end

		left = { type = "Binary", operator = operator, left = left, right = right }
	end

	return left, nil
end

parseExpression = function(self: ParserState): (Node?, string?)
	return parseBinary(self, 1)
end

parseStatement = function(self: ParserState): (Node?, string?)
	local token = current(self)

	if token.Type == "Symbol" and token.Value == ";" then
		advance(self)
		return nil, nil
	end

	if token.Type == "Keyword" then
		local keyword = token.Value

		if keyword == "local" then
			advance(self)
			if matchKeyword(self, "function") then
				local name, nameError = expectName(self)
				if nameError ~= nil then
					return nil, nameError
				end
				local body, bodyError = parseFunctionBody(self)
				if bodyError ~= nil then
					return nil, bodyError
				end
				return { type = "LocalFunction", name = name, func = body }, nil
			end

			local names: { string } = {}
			while true do
				local name, nameError = expectName(self)
				if nameError ~= nil then
					return nil, nameError
				end
				table.insert(names, name :: string)
				skipAttributes(self)
				if matchSymbol(self, ":") then
					skipTypeAnnotation(self)
				end
				if not matchSymbol(self, ",") then
					break
				end
			end

			local values: { Node } = {}
			if matchSymbol(self, "=") then
				local listError: string? = nil
				values, listError = parseExpressionList(self)
				if listError ~= nil then
					return nil, listError
				end
			end
			return { type = "Local", names = names, values = values }, nil
		end

		if keyword == "if" then
			advance(self)
			local clauses: { { test: Node, body: { Node } } } = {}
			local test, testError = parseExpression(self)
			if testError ~= nil then
				return nil, testError
			end
			local okThen, thenError = expectKeyword(self, "then")
			if not okThen then
				return nil, thenError
			end
			local body, bodyError = parseBlock(self)
			if bodyError ~= nil then
				return nil, bodyError
			end
			table.insert(clauses, { test = test :: Node, body = body })

			while isKeyword(self, "elseif") do
				advance(self)
				local branchTest, branchTestError = parseExpression(self)
				if branchTestError ~= nil then
					return nil, branchTestError
				end
				local okBranchThen, branchThenError = expectKeyword(self, "then")
				if not okBranchThen then
					return nil, branchThenError
				end
				local branchBody, branchBodyError = parseBlock(self)
				if branchBodyError ~= nil then
					return nil, branchBodyError
				end
				table.insert(clauses, { test = branchTest :: Node, body = branchBody })
			end

			local orelse: { Node }? = nil
			if matchKeyword(self, "else") then
				local elseBody, elseBodyError = parseBlock(self)
				if elseBodyError ~= nil then
					return nil, elseBodyError
				end
				orelse = elseBody
			end

			local okEnd, endError = expectKeyword(self, "end")
			if not okEnd then
				return nil, endError
			end
			return { type = "If", clauses = clauses, orelse = orelse }, nil
		end

		if keyword == "while" then
			advance(self)
			local test, testError = parseExpression(self)
			if testError ~= nil then
				return nil, testError
			end
			local okDo, doError = expectKeyword(self, "do")
			if not okDo then
				return nil, doError
			end
			local body, bodyError = parseBlock(self)
			if bodyError ~= nil then
				return nil, bodyError
			end
			local okEnd, endError = expectKeyword(self, "end")
			if not okEnd then
				return nil, endError
			end
			return { type = "While", test = test, body = body }, nil
		end

		if keyword == "repeat" then
			advance(self)
			local body, bodyError = parseBlock(self)
			if bodyError ~= nil then
				return nil, bodyError
			end
			local okUntil, untilError = expectKeyword(self, "until")
			if not okUntil then
				return nil, untilError
			end
			local test, testError = parseExpression(self)
			if testError ~= nil then
				return nil, testError
			end
			return { type = "Repeat", body = body, test = test }, nil
		end

		if keyword == "do" then
			advance(self)
			local body, bodyError = parseBlock(self)
			if bodyError ~= nil then
				return nil, bodyError
			end
			local okEnd, endError = expectKeyword(self, "end")
			if not okEnd then
				return nil, endError
			end
			return { type = "Do", body = body }, nil
		end

		if keyword == "for" then
			advance(self)
			local firstName, firstNameError = expectName(self)
			if firstNameError ~= nil then
				return nil, firstNameError
			end

			if matchSymbol(self, "=") then
				local start, startError = parseExpression(self)
				if startError ~= nil then
					return nil, startError
				end
				local okComma, commaError = expectSymbol(self, ",")
				if not okComma then
					return nil, commaError
				end
				local limit, limitError = parseExpression(self)
				if limitError ~= nil then
					return nil, limitError
				end
				local step: Node? = nil
				if matchSymbol(self, ",") then
					local stepExpression, stepError = parseExpression(self)
					if stepError ~= nil then
						return nil, stepError
					end
					step = stepExpression
				end
				local okDo, doError = expectKeyword(self, "do")
				if not okDo then
					return nil, doError
				end
				local body, bodyError = parseBlock(self)
				if bodyError ~= nil then
					return nil, bodyError
				end
				local okEnd, endError = expectKeyword(self, "end")
				if not okEnd then
					return nil, endError
				end
				return {
					type = "NumericFor",
					name = firstName,
					start = start,
					limit = limit,
					step = step,
					body = body,
				}, nil
			end

			local names: { string } = { firstName :: string }
			while matchSymbol(self, ",") do
				local name, nameError = expectName(self)
				if nameError ~= nil then
					return nil, nameError
				end
				table.insert(names, name :: string)
			end
			local okIn, inError = expectKeyword(self, "in")
			if not okIn then
				return nil, inError
			end
			local expressions, listError = parseExpressionList(self)
			if listError ~= nil then
				return nil, listError
			end
			local okDo, doError = expectKeyword(self, "do")
			if not okDo then
				return nil, doError
			end
			local body, bodyError = parseBlock(self)
			if bodyError ~= nil then
				return nil, bodyError
			end
			local okEnd, endError = expectKeyword(self, "end")
			if not okEnd then
				return nil, endError
			end
			return { type = "GenericFor", names = names, expressions = expressions, body = body }, nil
		end

		if keyword == "function" then
			advance(self)
			local name, nameError = expectName(self)
			if nameError ~= nil then
				return nil, nameError
			end
			local target: Node = { type = "Name", name = name }
			local methodName: string? = nil
			local isMethod = false
			while isSymbol(self, ".") do
				advance(self)
				local field, fieldError = expectName(self)
				if fieldError ~= nil then
					return nil, fieldError
				end
				target = { type = "Index", object = target, key = { type = "String", value = field } }
			end
			if matchSymbol(self, ":") then
				local method, methodError = expectName(self)
				if methodError ~= nil then
					return nil, methodError
				end
				methodName = method
				isMethod = true
				target = { type = "Index", object = target, key = { type = "String", value = method } }
			end
			local body, bodyError = parseFunctionBody(self)
			if bodyError ~= nil then
				return nil, bodyError
			end
			return { type = "FunctionStatement", target = target, func = body, isMethod = isMethod, methodName = methodName }, nil
		end

		if keyword == "return" then
			advance(self)
			local values: { Node } = {}
			local tokenAfter = current(self)
			local endsStatement = tokenAfter.Type == "EOF"
				or (tokenAfter.Type == "Keyword" and (tokenAfter.Value == "end" or tokenAfter.Value == "else"
					or tokenAfter.Value == "elseif" or tokenAfter.Value == "until"))
				or (tokenAfter.Type == "Symbol" and tokenAfter.Value == ";")
			if not endsStatement then
				local listError: string? = nil
				values, listError = parseExpressionList(self)
				if listError ~= nil then
					return nil, listError
				end
			end
			matchSymbol(self, ";")
			return { type = "Return", values = values }, nil
		end

		if keyword == "break" then
			advance(self)
			return { type = "Break" }, nil
		end

		if keyword == "continue" then
			advance(self)
			return { type = "Continue" }, nil
		end
	end

	-- Expression statement: either a call or an assignment.
	local first, firstError = parseExpression(self)
	if firstError ~= nil or first == nil then
		return nil, firstError
	end

	local compound = current(self)
	if compound.Type == "Symbol" and compoundOperators[compound.Value] then
		advance(self)
		local values, listError = parseExpressionList(self)
		if listError ~= nil then
			return nil, listError
		end
		return {
			type = "CompoundAssign",
			target = first,
			operator = compoundOperators[compound.Value],
			value = values[1] :: Node,
		}, nil
	end

	if isSymbol(self, "=") or isSymbol(self, ",") then
		local targets: { Node } = { first }
		while matchSymbol(self, ",") do
			local target, targetError = parseExpression(self)
			if targetError ~= nil or target == nil then
				return nil, targetError
			end
			table.insert(targets, target)
		end
		local okEquals, equalsError = expectSymbol(self, "=")
		if not okEquals then
			return nil, equalsError
		end
		local values, listError = parseExpressionList(self)
		if listError ~= nil then
			return nil, listError
		end
		return { type = "Assign", targets = targets, values = values }, nil
	end

	if first.type ~= "Call" and first.type ~= "MethodCall" then
		return nil, fail(self, ("syntax error near '%s'"):format(describe(current(self))))
	end

	return { type = "CallStatement", call = first }, nil
end

function Parser.parse(source: string): ParseResult
	local lexResult = Lexer.tokenize(source)
	if lexResult.Error ~= nil then
		return { Ast = nil, Error = lexResult.Error }
	end

	local self: ParserState = { tokens = lexResult.Tokens, position = 1 }
	local body, blockError = parseBlock(self)
	if blockError ~= nil then
		return { Ast = nil, Error = blockError }
	end
	if current(self).Type ~= "EOF" then
		return { Ast = nil, Error = fail(self, ("'<eof>' expected near '%s'"):format(describe(current(self)))) }
	end
	return { Ast = { type = "Block", body = body }, Error = nil }
end

return Parser
