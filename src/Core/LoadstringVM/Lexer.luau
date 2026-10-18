--!strict
-- Tokenizer used by the LumaUI loadstring virtual machine.
-- It converts a chunk of Luau source into a flat list of tokens.

export type TokenType = "Name" | "Number" | "String" | "Keyword" | "Symbol" | "EOF"

export type Token = {
	Type: TokenType,
	Value: any,
	Line: number,
}

export type LexResult = {
	Tokens: { Token },
	Error: string?,
}

local Lexer = {}

local keywords: { [string]: boolean } = {
	["and"] = true,
	["break"] = true,
	["continue"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
	["while"] = true,
}

local symbols: { [string]: boolean } = {
	["+"] = true,
	["-"] = true,
	["*"] = true,
	["/"] = true,
	["%"] = true,
	["^"] = true,
	["#"] = true,
	["?"] = true,
	[".."] = true,
	["+="] = true,
	["-="] = true,
	["*="] = true,
	["/="] = true,
	["//="] = true,
	["%="] = true,
	["^="] = true,
	["..="] = true,
	["=="] = true,
	["~="] = true,
	["<="] = true,
	[">="] = true,
	["//"] = true,
	[">>"] = true,
	["<<"] = true,
	["&"] = true,
	["|"] = true,
	["~"] = true,
	["<"] = true,
	[">"] = true,
	["="] = true,
	["("] = true,
	[")"] = true,
	["{"] = true,
	["}"] = true,
	["["] = true,
	["]"] = true,
	[";"] = true,
	[":"] = true,
	[","] = true,
	["."] = true,
}

local escapeCharacters: { [string]: string } = {
	n = "\n",
	t = "\t",
	r = "\r",
	a = "\a",
	b = "\b",
	f = "\f",
	v = "\v",
	["\\"] = "\\",
	['"'] = '"',
	["'"] = "'",
	["\n"] = "\n",
}

local function isDigit(char: string): boolean
	return char >= "0" and char <= "9"
end

local function isHexDigit(char: string): boolean
	return isDigit(char)
		or (char >= "a" and char <= "f")
		or (char >= "A" and char <= "F")
end

local function isNameStart(char: string): boolean
	return (char >= "a" and char <= "z")
		or (char >= "A" and char <= "Z")
		or char == "_"
end

local function isNameChar(char: string): boolean
	return isNameStart(char) or isDigit(char)
end

local function isSpace(char: string): boolean
	return char == " " or char == "\t" or char == "\r" or char == "\n" or char == "\v" or char == "\f"
end

local function longBracketLevel(text: string, start: number): number?
	-- Returns the number of "=" signs when a long bracket opens at `start`, or nil.
	if text:sub(start, start) ~= "[" then
		return nil
	end
	local index = start + 1
	local level = 0
	while text:sub(index, index) == "=" do
		level += 1
		index += 1
	end
	if text:sub(index, index) == "[" then
		return level
	end
	return nil
end

local function readLongString(text: string, start: number, level: number): (string?, number?)
	local closing = "]" .. string.rep("=", level) .. "]"
	local bodyStart = start + level + 2
	local bodyEnd = text:find(closing, bodyStart, true)
	if not bodyEnd then
		return nil, nil
	end
	return text:sub(bodyStart, bodyEnd - 1), bodyEnd + #closing
end

local function readQuotedString(text: string, start: number): (string?, number?, string?)
	local quote = text:sub(start, start)
	local buffer = {}
	local index = start + 1
	while true do
		local char = text:sub(index, index)
		if char == "" then
			return nil, nil, "unfinished string"
		end
		if char == "\\" then
			local escaped = text:sub(index + 1, index + 1)
			if escaped == "" then
				return nil, nil, "unfinished string"
			end
			if escaped == "x" then
				local hex = text:sub(index + 2, index + 3)
				if not hex:match("^%x%x$") then
					return nil, nil, "hexadecimal digit expected"
				end
				buffer[#buffer + 1] = string.char(tonumber(hex, 16) :: number)
				index += 4
			elseif escaped == "z" then
				index += 2
				while isSpace(text:sub(index, index)) do
					index += 1
				end
			elseif isDigit(escaped) then
				local digits = text:sub(index + 1, index + 3):match("^(%d%d?%d?)")
				buffer[#buffer + 1] = string.char(tonumber(digits, 10) :: number)
				index += 1 + #digits
			else
				local replacement = escapeCharacters[escaped]
				if replacement == nil then
					buffer[#buffer + 1] = escaped
				else
					buffer[#buffer + 1] = replacement
				end
				index += 2
			end
		elseif char == quote then
			return table.concat(buffer), index + 1, nil
		elseif char == "\n" then
			return nil, nil, "unfinished string"
		else
			buffer[#buffer + 1] = char
			index += 1
		end
	end
end

local function readNumber(text: string, start: number): (number?, number?)
	local rest = text:sub(start)
	local hex = rest:match("^0[xX](%x+)")
	if hex then
		local value = tonumber(hex, 16)
		if value == nil then
			return nil, nil
		end
		return value, start + #hex + 1
	end
	local literal = rest:match("^(%d*%.?%d*[eE][%+%-]?%d+)")
		or rest:match("^(%d*%.?%d+)")
		or rest:match("^(%d+%.?)")
	if not literal then
		return nil, nil
	end
	local value = tonumber(literal)
	if value == nil then
		return nil, nil
	end
	return value, start + #literal
end

function Lexer.tokenize(source: string): LexResult
	local tokens: { Token } = {}
	local index = 1
	local line = 1
	local length = #source

	while index <= length do
		local char = source:sub(index, index)

		if char == "\n" then
			line += 1
			index += 1
			continue
		end

		if isSpace(char) then
			index += 1
			continue
		end

		-- Comments
		if char == "-" and source:sub(index + 1, index + 1) == "-" then
			local commentStart = index + 2
			local level = longBracketLevel(source, commentStart)
			if level ~= nil then
				local _, commentEnd = readLongString(source, commentStart, level)
				if commentEnd == nil then
					return { Tokens = tokens, Error = ("unfinished long comment on line %d"):format(line) }
				end
				for _ in source:sub(index, commentEnd):gmatch("\n") do
					line += 1
				end
				index = commentEnd
			else
				while index <= length and source:sub(index, index) ~= "\n" do
					index += 1
				end
			end
			continue
		end

		-- Long strings
		if char == "[" then
			local level = longBracketLevel(source, index)
			if level ~= nil then
				local body, bodyEnd = readLongString(source, index, level)
				if body == nil or bodyEnd == nil then
					return { Tokens = tokens, Error = ("unfinished long string on line %d"):format(line) }
				end
				for _ in body:gmatch("\n") do
					line += 1
				end
				table.insert(tokens, { Type = "String", Value = body, Line = line })
				index = bodyEnd
				continue
			end
		end

		-- Quoted strings
		if char == '"' or char == "'" then
			local value, nextIndex, errorMessage = readQuotedString(source, index)
			if value == nil or nextIndex == nil then
				return { Tokens = tokens, Error = ("%s on line %d"):format(errorMessage or "invalid string", line) }
			end
			table.insert(tokens, { Type = "String", Value = value, Line = line })
			index = nextIndex
			continue
		end

		-- Numbers
		if isDigit(char) or (char == "." and isDigit(source:sub(index + 1, index + 1))) then
			local value, nextIndex = readNumber(source, index)
			if value == nil or nextIndex == nil then
				return { Tokens = tokens, Error = ("malformed number on line %d"):format(line) }
			end
			table.insert(tokens, { Type = "Number", Value = value, Line = line })
			index = nextIndex
			continue
		end

		-- Names and keywords
		if isNameStart(char) then
			local start = index
			while index <= length and isNameChar(source:sub(index, index)) do
				index += 1
			end
			local word = source:sub(start, index - 1)
			table.insert(tokens, { Type = if keywords[word] then "Keyword" else "Name", Value = word, Line = line })
			continue
		end

		-- Symbols
		local three = source:sub(index, index + 2)
		local two = source:sub(index, index + 1)
		if three == "..." or three == "//=" or three == "..=" then
			table.insert(tokens, { Type = "Symbol", Value = three, Line = line })
			index += 3
		elseif two == ".." or two == "==" or two == "~=" or two == "<=" or two == ">="
			or two == "//" or two == ">>" or two == "<<" or two == "+=" or two == "-="
			or two == "*=" or two == "/=" or two == "%=" or two == "^=" or two == "..=" then
			table.insert(tokens, { Type = "Symbol", Value = two, Line = line })
			index += 2
		elseif symbols[char] then
			table.insert(tokens, { Type = "Symbol", Value = char, Line = line })
			index += 1
		else
			return { Tokens = tokens, Error = ("unexpected symbol '%s' on line %d"):format(char, line) }
		end
	end

	table.insert(tokens, { Type = "EOF", Value = "<eof>", Line = line })
	return { Tokens = tokens, Error = nil }
end

return Lexer
