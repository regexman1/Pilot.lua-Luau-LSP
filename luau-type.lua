local luauTypes = {}

type TypeStyle = "type" | "function" | "method" | "union" | "intersection"

type Context = {
	style: TypeStyle,
	isMethod: boolean,
	isNullable: boolean,
	isString: boolean,
	isOpenString: boolean,
	isArray: boolean,
	isSparseArray: boolean,
}

type TypeGroup = {
	key: string,
	value: any,
	context: Context,
	generics: { any }?,
	genericDefinitions: { any }?,
}

type State = {
	base: TypeGroup,
	metatable: TypeGroup,
	self: TypeGroup,
	parent: State | RootState,
	isRoot: false,
	root: RootState,
	source: any,
}

type RootState = {
	name: string,
	isRoot: true,
	context: "class" | "declaration" | "type",
}

local NULLABLE_MODIFIER = "nullable"
local STRING_MODIFIER = "string"
local ARRAY_MODIFIER = "array"

local OPEN_STRING_PREFIX = "open"
local SPARSE_ARRAY_PREFIX = "sparse"

local METATABLE_PREFIX = "metatable"
local SELF_PREFIX = "self"

local TYPE_STYLES = { "type", "function", "method", "union", "intersection", "class", "pack" }

local function getTypeStyle(values)
	for _, possibleTypeStyle in TYPE_STYLES do
		if table.find(values, possibleTypeStyle) then
			return possibleTypeStyle
		end
	end

	return nil
end

local function getContextTable(value, key, typeStyle, generics, genericDefinitions)
	local stringIndex = table.find(key, STRING_MODIFIER)
	local arrayIndex = table.find(key, ARRAY_MODIFIER)

	return {
		key = key,
		value = value,
		context = {
			style = if typeStyle == "method" then "function" else typeStyle,
			isMethod = typeStyle == "method",
			isNullable = table.find(key, NULLABLE_MODIFIER) ~= nil,
			isString = stringIndex ~= nil,
			isOpenString = stringIndex ~= nil and key[stringIndex - 1] == OPEN_STRING_PREFIX,
			isArray = arrayIndex ~= nil,
			isSparseArray = arrayIndex ~= nil and key[arrayIndex - 1] == SPARSE_ARRAY_PREFIX,
		},
		generics = generics,
		genericDefinitions = genericDefinitions,
	}
end

local function moveMerge(t, key, value)
	local output = t[key]
	if output then
		for subKey, subValue in value do
			assert(output[subKey] == nil, "duplicate keys")
			output[subKey] = subValue
		end
	else
		t[key] = value
	end
end

function luauTypes.getTypeState(source, parent: State | RootState): State?
	local output: State = {} :: any

	for key, value in source do
		if key == METATABLE_PREFIX or key == SELF_PREFIX then
			assert(value.generics, "no generics table found")

			local typeKey = next(value, "generics") or next(value)

			if typeKey then
				local splitKey = typeKey:split("-")
				local typeStyle = getTypeStyle(splitKey)

				local bundled = getContextTable(value[typeKey], splitKey, typeStyle, value.generics)
				moveMerge(output, key, bundled)
			else
				moveMerge(output, key, { generics = value })
			end
		else
			local splitKey = key:split("-")
			local typeStyle = getTypeStyle(splitKey)

			if not typeStyle then
				continue
			end

			if splitKey[1] == METATABLE_PREFIX or splitKey[1] == SELF_PREFIX then
				local bundled = getContextTable(value, splitKey, typeStyle)
				moveMerge(output, splitKey[1], bundled)
			else
				local bundled =
					getContextTable(value, splitKey, typeStyle, source.generics, source["generic-definitions"])
				moveMerge(output, "base", bundled)
			end
		end
	end

	if next(output) then
		output.parent = parent
		output.root = if parent.isRoot then parent else parent.root
		output.source = source
		return output
	else
		return nil
	end
end

function luauTypes.writeFromState(output, state: State)
	local context = state.base.context
	local source = state.source

	if state.parent.isRoot then
		if state.parent.define == false then
			local generics = state.base.genericDefinitions
			if generics then
				output:append("<")
				for index, genericValue in generics do
					output:append(genericValue.name)
					if index < #generics then
						output:append(", ")
					end
				end
				output:append(">")
			end
		else
			if state.root.context == "type" then
				output:append(if source.export ~= false then "export " else nil, "type ", state.root.name)
				local generics = state.base.genericDefinitions
				if generics then
					output:append("<")
					for index, genericValue in generics do
						output:append(genericValue.name)
						if next(genericValue, "name") or next(genericValue) then
							output:append(" = ")
							luauTypes.write(output, genericValue, state)
						end
						if index < #generics then
							output:append(", ")
						end
					end
					output:append(">")
				end
				output:append(" = ")
			elseif state.root.context == "class" then
				output:append("declare class ", state.root.name, "\n"):indent()
			end
		end
	end

	if state.metatable then
		local metatableContext = state.metatable.context

		output:append("typeof(setmetatable(\n"):indent():append("{} :: ")
		luauTypes[`write{context.style:gsub("^%l", string.upper)}`](output, state, state.base)
		output:append(",\n{} :: ")
		luauTypes[`write{metatableContext.style:gsub("^%l", string.upper)}`](output, state, state.metatable)
		output:append("\n"):unindent():append("))")
	else
		luauTypes[`write{context.style:gsub("^%l", string.upper)}`](output, state, state.base)
	end

	if state.parent.isRoot then
		if state.root.context == "type" then
			-- output:append("")
		elseif state.root.context == "class" then
			output:unindent():append("end")
		end
	end
end

function luauTypes.write(output, source: any, parent: State)
	local state = assert(luauTypes.getTypeState(source, parent), "no context found")
	luauTypes.writeFromState(output, state)
end

local function writeKey(output, key: { string } | string)
	if typeof(key) == "table" then
		assert(#key == 1 and typeof(key[1]) == "string", "malformed indexer")
		output:append("[", key[1], "]: ")
	elseif typeof(key) == "string" then
		if key:match("^[_%a][_%w]*$") then
			output:append(key, ": ")
		else
			output:append("[", string.format("%q", key), "]: ")
		end
	else
		error("invalid luau key")
	end
end

function luauTypes.writeType(output, state: State, group: TypeGroup)
	local value, context = group.value, group.context

	if context.isArray then
		output:append("{ ")
	end

	if context.isString then
		if typeof(value) == "string" then
			output:append(string.format("%q", value))
		else
			error("expected a string literal")
		end
	else
		if typeof(value) == "string" or typeof(value) == "boolean" then
			output:append(tostring(value))

			if group.generics then
				output:append("<")
				for index, subValue in group.generics do
					luauTypes.write(output, subValue, state)
					if index < #group.generics then
						output:append(", ")
					end
				end
				output:append(">")
			end
		elseif typeof(value) == "table" then
			output:append("{\n"):indent()
			for key, subValue in value do
				writeKey(output, key)
				luauTypes.write(output, subValue, state)
				output:append(",\n")
			end
			output:unindent():append("}")
		else
			error("expected a string literal or dictionary")
		end
	end

	if context.isArray then
		if context.isSparseArray then
			output:append("?")
		end
		output:append(" }")
	end

	if context.isNullable then
		output:append("?")
	end
end

function luauTypes.writePack(output, state: State, group: TypeGroup)
	local parameters=  state.base.value

	output:append("(")
	for index, parameter in parameters do
		luauTypes.write(output, parameter, state)
		if index < #parameters then
			output:append(", ")
		end
	end
	output:append(")")
end

local function getParameters(state: State, group: TypeGroup)
	if not state.base.context.isMethod then
		return group.value.parameters
	end

	local node = state
	local previous
	while node ~= nil and not node.isRoot and not node.self do
		node, previous = node.parent, node
	end

	local parameters = if group.value.parameters then table.clone(group.value.parameters) else {}

	if node and node.isRoot then
		local generics
		if previous.base.genericDefinitions then
			generics = {}
			for _, generic in previous.base.genericDefinitions do
				table.insert(generics, { type = generic.name })
			end
		end

		table.insert(parameters, 1, {
			name = "self",
			type = node.name,
			generics = generics,
		})
	elseif node then
		local selfType = node.self

		local keyTable = table.clone(selfType.key)
		if keyTable[1] == SELF_PREFIX then
			table.remove(keyTable, 1)
		end
		local key = table.concat(keyTable, "-")

		table.insert(parameters, 1, {
			name = "self",
			[key] = selfType.value,
			generics = selfType.generics,
		})
	else
		table.insert(parameters, 1, { name = "self", type = "unknown" })
	end

	return parameters
end

local function writeFunctionDeclaration(output, state: State, group: TypeGroup)
	local value, context = group.value, group.context

	output:append("(")

	local node = state
	while node ~= nil and not node.isRoot and not node.self do
		node = node.parent
	end

	local parameters = getParameters(state, group)

	if parameters and #parameters > 0 then
		output:append("self, ")

		for index, parameter in parameters do
			if parameter.name then
				output:append(parameter.name, ": ")
			end
			luauTypes.write(output, parameter, state)
			if index < #parameters then
				output:append(", ")
			end
		end
	else
		output:append("self")
	end

	if value.returns and #value.returns > 0 then
		output:append("): ")

		local needsBrackets = #value.returns > 1 or context.isNullable

		if needsBrackets then
			output:append("(")
		end

		for index, returnValue in value.returns do
			if returnValue.name == "..." then
				output:append("...")
			end
			luauTypes.write(output, returnValue, state)
			if index < #value.returns then
				output:append(", ")
			end
		end

		if needsBrackets then
			output:append(")")
		end
	else
		output:append(")")
	end

	if context.isNullable then
		output:append("?")
	end
end

local function writeFunctionLuauType(output, state: State, group: TypeGroup)
	local value, context = group.value, group.context

	local parameters = getParameters(state, group)
	local returns = value.returns

	output:append("(")

	if parameters and #parameters > 0 then
		for index, parameter in parameters do
			if parameter.name == "..." then
				output:append("...")
			elseif parameter.name then
				output:append(parameter.name, ": ")
			end

			luauTypes.write(output, parameter, state)
			if index < #parameters then
				output:append(", ")
			end
		end
	end

	output:append(") -> ")

	if returns and #returns > 0 then
		local needsBrackets = #returns > 1 or context.isNullable

		if needsBrackets then
			output:append("(")
		end

		for index, returnValue in returns do
			if returnValue.name == "..." then
				output:append("...")
			end
			luauTypes.write(output, returnValue, state)
			if index < #returns then
				output:append(", ")
			end
		end

		if needsBrackets then
			output:append(")")
		end
	else
		output:append("()")
	end

	if context.isNullable then
		output:append("?")
	end
end

function luauTypes.writeFunction(output, state: State, group: TypeGroup)
	local context = group.context
	assert(not context.isString, "you cannot have a string literal function")

	if state.parent.isRoot and state.root.context == "class" or state.root.context == "declaration" then
		writeFunctionDeclaration(output, state, group)
	else
		writeFunctionLuauType(output, state, group)
	end
end

function luauTypes.writeUnion(output, state: State, group: TypeGroup)
	local value, context = group.value, group.context
	local parent = state.parent

	if context.isArray then
		output:append("{ ")
		if context.isSparseArray then
			output:append("(")
		end
	elseif parent and parent.style == "intersection" then
		output:append("(")
		if context.isNullable then
			output:append("(")
		end
	elseif context.isNullable then
		output:append("(")
	end

	if context.isString then
		for index, subValue in value do
			output:append(string.format("%q", subValue))
			if context.isOpenString or index < #value then
				output:append(" | ")
			end
		end

		if context.isOpenString then
			output:append("string")
		end
	else
		for index, subValue in value do
			luauTypes.write(output, subValue, state)
			if index < #value then
				output:append(" | ")
			end
		end
	end

	if context.isArray then
		if context.isSparseArray then
			output:append(")?")
		end
		output:append(" }")
	elseif parent and parent.style == "intersection" then
		output:append(")")
	elseif context.isNullable then
		output:append(")")
	end

	if context.isNullable then
		output:append("?")
	end
end

function luauTypes.writeIntersection(output, state: State, group: TypeGroup)
	local value, context = group.value, group.context

	assert(not context.isString, "you cannot have a string literal intersection")

	local parent = state.parent

	if context.isArray then
		output:append("{ ")
		if context.isSparseArray then
			output:append("(")
		end
	elseif context.isNullable or (parent and parent.style == "union") then
		output:append("(")
	end

	for index, type in value do
		luauTypes.write(output, type, state)
		if index < #value then
			output:append(" & ")
		end
	end

	if context.isArray then
		if context.isSparseArray then
			output:append(")?")
		end
		output:append(" }")
	elseif parent and parent.style == "union" then
		output:append(")")
	end

	if context.isNullable then
		output:append("?")
	end
end

function luauTypes.writeClass(output, state: State, group: TypeGroup)
	local value = group.value

	assert(state.parent.isRoot, "classes must be defined as the root")

	for key, member in value do
		local memberState = assert(luauTypes.getTypeState(member, state), "no context found")

		if memberState.base.context.style == "method" then
			assert(
				typeof(key) == "string" and key:match("^[_%a][_%w]*$"),
				"class methods must have valid luau identifiers as keys"
			)
			output:append("function ", key)
		else
			writeKey(output, key)
		end

		luauTypes.writeFromState(output, memberState)
	end
end

return luauTypes
