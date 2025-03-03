local fs = require("@lune/fs")
local serde = require("@lune/serde")

local luauTypes = require("luau-type")

local partDocumentation = serde.decode("yaml", fs.readFile("./.lune/documentation.yaml")) :: any
local rawPartData = serde.decode("json", fs.readFile("./.lune/partdata.json")) :: any

-- local path = "./test-docs/objects/"
local path = "wiki/docs/Objects/"
local writtenPaths = {}

local function getType(value)
	local function indentString(amount: number, str: string): string
		local indent = string.rep("\t", amount)
		return (str:gsub("\n", "\n" .. indent))
	end

	local output = setmetatable({ _lines = {}, _indent = 0 }, {
		__index = {
			append = function(self, ...: any)
				for index = 1, select("#", ...) do
					local line = select(index, ...)
					if type(line) == "table" then
						for _, subLine in line._lines or line do
							table.insert(self._lines, indentString(self._indent, subLine))
						end
					elseif line ~= nil then
						table.insert(self._lines, indentString(self._indent, line))
					end
				end
				return self
			end,
			newline = function(self, count)
				table.insert(self._lines, string.rep("\n" .. string.rep("\t", self._indent), count or 1))
				return self
			end,
			indent = function(self)
				table.insert(self._lines, "\t")
				self._indent += 1
				return self
			end,
			unindent = function(self)
				self._lines[#self._lines] = self._lines[#self._lines]:gsub("\t$", "")
				self._indent -= 1
				return self
			end,
		},
	})

	luauTypes.write(output, value, { isRoot = true, name = name, context = "type", define = false })

	return table.concat(output._lines)
end

local function sortedIterate<T>(dictionary: { [string]: T }): () -> (string, T)
	local keys = {}
	for key, _ in dictionary do
		table.insert(keys, key)
	end
	table.sort(keys)

	local index = 0
	return function()
		index += 1
		local key = keys[index]
		return key, dictionary[key]
	end
end

local function deprecatedSortedIterate<T>(dictionary: { [string]: T }): () -> (string, T)
	local keys, deprecated = {}, {}
	for key, value in dictionary do
		table.insert(if value.documentation and value.documentation.deprecated then deprecated else keys, key)
	end
	table.sort(keys)
	table.sort(deprecated)

	local index = 0
	return function()
		index += 1
		local key = keys[index] or deprecated[index - #keys]
		return key, dictionary[key]
	end
end

local function aOrAn(str)
	return if table.find({ "a", "e", "i", "o" }, str:sub(1, 1):lower()) then "an" else "a"
end

local function isArray(value)
	if typeof(value) ~= "table" then
		return false
	end

	for index, _ in value do
		if typeof(index) ~= "number" then
			return false
		end
	end

	return true
end

function numberToOrdinalWord(number)
	local units = { "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth" }
	local teens = {
		"eleventh",
		"twelfth",
		"thirteenth",
		"fourteenth",
		"fifteenth",
		"sixteenth",
		"seventeenth",
		"eighteenth",
		"nineteenth",
	}
	local tens = {
		"tenth",
		"twentieth",
		"thirtieth",
		"fortieth",
		"fiftieth",
		"sixtieth",
		"seventieth",
		"eightieth",
		"ninetieth",
	}
	local tens_prefix = { "", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety" }

	if number < 1 or number > 99 then
		return "Number out of range"
	end

	if number <= 9 then
		return units[number]
	elseif number == 10 then
		return tens[1]
	elseif number >= 11 and number <= 19 then
		return teens[number - 10]
	elseif number % 10 == 0 then
		return tens[number / 10]
	else
		local ten_part = math.floor(number / 10)
		local unit_part = number % 10
		return tens_prefix[ten_part] .. "-" .. units[unit_part]
	end
end

function escapeMarkdown(text)
	local markdownCharacters = [[\`*_{}[%]()#+-.!|<>]]
	return (text:gsub("([" .. markdownCharacters .. "])", "\\%1"))
end

local function getMarkdownType(value)
	return escapeMarkdown(getType(value):gsub("\n\t*", " "):gsub(", }", " }"))
end

local function formatSize(size)
	local x = if size[1] % 1 == 0 then tostring(size[1]) else string.format("%.2f", size[1])
	local y = if size[2] % 1 == 0 then tostring(size[2]) else string.format("%.2f", size[2])
	local z = if size[3] % 1 == 0 then tostring(size[3]) else string.format("%.2f", size[3])
	return `{x}x{y}x{z}`
end

local function findPossibleSizes(malleability)
	local sizes = {}

	for i = 1, math.min(math.sqrt(malleability), 2048) do
		if malleability % i == 0 then
			local remaining = malleability / i
			for j = 1, math.min(math.sqrt(remaining), 2048) do
				if remaining % j == 0 then
					local k = remaining / j
					if k <= 2048 and not table.find(sizes, formatSize({ j, k, i })) then
						table.insert(sizes, formatSize({ i, k, j }))
					end
				end
			end
		end
	end

	return sizes
end

local function writeParameters(output, objectName, memberName, parameters, groupName, groupNamePlural)
	for parameterIndex, parameter in parameters do
		if #parameters == 1 then
			table.insert(output, "\n\nThe ")
			if parameter.name == "..." then
				table.insert(output, `variadic {groupName}`)
			elseif parameter.name then
				table.insert(output, `<b>{parameter.name}</b> {groupName}`)
			else
				table.insert(output, `only {groupName}`)
			end
		else
			if parameterIndex == 1 then
				table.insert(output, `\n\nThe {groupNamePlural} for <code>{memberName}</code> are as follows:\n`)
			end

			table.insert(output, "- The ")
			if parameter.name == "..." then
				table.insert(output, `variadic {groupName}`)
			elseif parameter.name then
				table.insert(output, `<b>{parameter.name}</b> {groupName}`)
			else
				table.insert(output, `{numberToOrdinalWord(parameterIndex)} {groupName}`)
			end
		end

		local description = if typeof(parameter.documentation) == "table"
			then parameter.documentation.description
			else parameter.documentation
		if description then
			table.insert(output, " is ")
			table.insert(output, (description:gsub("^%u", string.lower):gsub("\n+", " ")))
			table.insert(output, " It")
		end

		local base = assert(
			luauTypes.getTypeState(parameter, {
				isRoot = true,
				name = parameter.name or "_" .. tostring(parameterIndex),
				context = "type",
				define = false,
			}),
			"no type state"
		).base
		local context = base.context

		if context.style == "union" then
			if context.isString then
				if context.isOpenString then
					table.insert(output, " can be any string, some <i>example</i> possibilities include: ")
				else
					table.insert(output, " is a string that can be ")
				end
				for index, value in base.value do
					if index == #base.value then
						if #base.value > 2 then
							table.insert(output, ", ")
						end
						table.insert(output, " or ")
					elseif index > 1 then
						table.insert(output, ", ")
					end
					table.insert(output, `<code>{string.format("%q", value):sub(2, -2)}</code>`)
				end
			else
				table.insert(output, " can be any of the following types:\n")
				for index, value in base.value do
					table.insert(output, `  - <code>{getMarkdownType(value)}</code>\n`)
				end
				table.insert(output, "\n")
			end
		elseif context.style == "type" and typeof(base.value) == "table" and typeof((next(base.value))) == "table" then
			local indexer, value = next(base.value)
			table.insert(
				output,
				` is a dictionary with keys that are <code>{indexer[1]}</code>s and values that are <code>{getMarkdownType(
					value
				)}</code>s.`
			)
		elseif context.style == "type" and typeof(base.value) == "string" then
			table.insert(
				output,
				if base.value == "any"
					then ` can be anything.`
					else ` is{if context.isArray then " an array of" else ""} {if context.isString
						then "the string"
						else aOrAn(base.value)} <code>{base.value}</code>{if context.isArray then "s" else ""}.`
			)
		elseif context.style == "type" then
			table.insert(output, ` is a dictionary:\n`)
			for key, value in sortedIterate(base.value) do
				local t = getMarkdownType(value)
				table.insert(output, `  - <code>{key}</code> is {aOrAn(t)} <code>{t}</code>.\n`)
			end
		elseif context.style == "function" then
			table.insert(output, ` is a function of type <code>{getMarkdownType(parameter)}</code>.`)
		else
			print(context)
			error(`{objectName}.{groupNamePlural}.{parameter.name or parameterIndex}`)
		end

		if context.isNullable then
			if output[#output]:sub(-1, -1) ~= "\n" then
				table.insert(output, " ")
			end
			table.insert(output, "It can also be <code>nil</code>.")
		end

		table.insert(output, "\n")

		-- table.insert(output, luauType)
	end
end

local function addCodeSamples(output, data)
	if typeof(data.documentation) == "table" then
		local codeSamples = data.documentation["code-samples"] or {}
		if data.documentation["code-sample"] then
			table.insert(codeSamples, 1, data.documentation["code-sample"])
		end

		for _, codeSample in codeSamples do
			table.insert(output, "\n```lua\n")
			table.insert(output, codeSample)
			table.insert(output, "\n```")
		end
	end
end

for objectName, object in partDocumentation.classes do
	-- local objectName, object: any = "PilotObject", partDocumentation.classes.PilotObject
	-- do
	if not object.hydrator then
		continue
		-- return
	end

	objectName = object.hydrator["class-name"] or objectName

	local output = {}
	local metadata = {}

	local tableOfContents = {}

	local function writeGroupHeader(header: string)
		table.insert(output, `\n\n<Member id="{header}" group="group">{header}</Member>\n\n`)
		table.insert(tableOfContents, `\{value: "{header}", id: "{header}", "level": 2\}`)
	end

	local function writeMemberHeader(
		header: string,
		group: "method" | "event" | "configurable" | "property",
		id: string
	)
		table.insert(output, `\n\n---\n\n<Member id="{id}" group="{group}">{header}</Member>\n\n`)
		table.insert(
			tableOfContents,
			`\{value: "{id .. if group == "method" then "()" else ""}", id: "{id}", "level": 3\}`
		)
	end

	if objectName == "PilotObject" then
		metadata.sidebar_position = 1
	end

	if object.documentation and typeof(object.documentation) == "table" then
		local documentation = object.documentation
		metadata.tags = if documentation.categories then table.clone(documentation.categories) else {}

		if documentation.description then
			table.insert(output, documentation.description:gsub("\n+$", "") .. "\n")
		end
		addCodeSamples(output, object)
	elseif typeof(object.documentation) == "string" then
		table.insert(output, object.documentation:gsub("\n+$", "") .. "\n")
	end

	if not metadata.tags then
		metadata.tags = {}
	end

	local rawData = rawPartData.Parts[objectName]
	if rawData then
		table.insert(output, "\n")

		table.insert(
			output,
			`It is a{if rawData.Craftable and rawData.Spawnable
				then " craftable and spawnable"
				elseif rawData.Craftable then " craftable"
				elseif rawData.Spawnable then " spawnable"
				else ""} {if rawData.Flammable then "flammable" else "non-flammable"} {if rawData.ClassState
				then rawData.ClassState:lower()
				else "object"}.\n\n`
		)

		if rawData.Malleability == 0 then
			table.insert(output, `It cannot be resized.\n\n`)
		elseif rawData.Malleability then
			local sizes = findPossibleSizes(rawData.Malleability)
			if #sizes < 32 and #sizes > 0 then
				table.insert(
					output,
					`Here is a list of possible sizes that reach the maximum malleability ({rawData.Malleability}) that have integer components: `
				)
				table.insert(output, table.concat(sizes, ", "))
				table.insert(output, "\n\n")
			else
				table.insert(output, `It has a malleability of {rawData.Malleability}.\n\n`)
			end
		end

		local defaultSize = formatSize(rawData.BaseSize)

		if rawData.BaseDurability == "1inf" then
			table.insert(output, `It has infinite durability and a default size of {defaultSize}.\n\n`)
		elseif rawData.BaseDurability then
			local baseVolume = rawData.BaseSize[1] * rawData.BaseSize[2] * rawData.BaseSize[3]
			table.insert(
				output,
				`At its default size ({defaultSize}) it has a durability of {rawData.BaseDurability}{if rawData.Malleability
						and rawData.Malleability > 0
					then `, at its maximum size it has a durability of {math.floor(
						(rawData.Malleability / baseVolume) ^ (1 / 3) * rawData.BaseDurability + 1
					)}`
					else ""}.\n\n`
			)
		elseif rawData.BaseSize then
			table.insert(output, `It has a default size of {defaultSize}.\n\n`)
		end

		if rawData.Color then
			local hex = string.format("%2x%2x%2x", unpack(rawData.Color))
			table.insert(
				output,
				`By default, its colour is <span style=\{\{color: '#{hex:upper()}'}}>#{hex}</span>.\n\n`
			)
		end

		if rawData.Recipe then
			local recipe = { "It requires " }
			for key, value in sortedIterate(rawData.Recipe) do
				table.insert(recipe, `{value} <code>{key}</code>`)
				if #recipe > 1 then
					table.insert(recipe, ", ")
				end
			end

			if #recipe > 3 then
				recipe[#recipe - 2] = if #recipe == 5 then " and " else ", and "
				recipe[#recipe] = " "
			end
			table.insert(recipe, "to be crafted.")

			table.insert(output, table.concat(recipe) .. "\n\n")
		end
	end

	if typeof(object.hydrator) == "table" then
		local isProgrammable = false
		local isConfigurable = false

		if object.hydrator.methods and next(object.hydrator.methods) then
			isProgrammable = true

			local methods = object.hydrator.methods
			writeGroupHeader("Methods")
			for methodName, methodData in deprecatedSortedIterate(methods) do
				local isDeprecated = if typeof(methodData.documentation) == "table"
					then methodData.documentation.deprecated
					else false

				if methodData.overloads then
					local parameterNames = {}
					for index, parameter in methodData.parameters or {} do
						table.insert(parameterNames, parameter.name or `<i>{string.char(96 + index)}</i>`)
					end

					local returnNames = {}
					for index, value in methodData.returns or {} do
						table.insert(returnNames, value.name or `<i>{string.char(96 + index)}</i>`)
					end

					writeMemberHeader(
						(if isDeprecated then "<del><i>" else "")
							.. methodName
							.. (if isDeprecated then "</i></del>" else ""),
						"method",
						methodName
					)

					if isDeprecated then
						table.insert(output, "\n:::warning\n\n")
						table.insert(output, "This method is deprecated.")
						if typeof(isDeprecated) == "string" then
							table.insert(output, " " .. isDeprecated)
						end
						table.insert(output, "\n\n:::\n\n")
					end

					if typeof(methodData.documentation) == "table" then
						if methodData.documentation.description then
							table.insert(output, methodData.documentation.description)
						end
					elseif methodData.documentation then
						table.insert(output, methodData.documentation)
					end

					for index, overload in methodData.overloads do
						local parameterNames = {}
						for index, parameter in overload.parameters or {} do
							table.insert(parameterNames, parameter.name or `<i>{string.char(96 + index)}</i>`)
						end

						local returnNames = {}
						for index, value in overload.returns or {} do
							table.insert(returnNames, value.name or `<i>{string.char(96 + index)}</i>`)
						end

						table.insert(
							output,
							`\n\n#### Overload {string.char(64 + index)} `
								.. "– "
								.. "("
								.. table.concat(parameterNames, ", ")
								.. ")"
								.. (if #returnNames > 1
									then " → (" .. table.concat(returnNames, ", ") .. ")"
									elseif #returnNames > 0 then " → " .. returnNames[1]
									else "")
								.. "\n"
						)

						if typeof(overload.documentation) == "table" then
							if overload.documentation.description then
								table.insert(output, overload.documentation.description)
							end
						elseif overload.documentation then
							table.insert(output, overload.documentation)
						end

						if overload.parameters then
							writeParameters(
								output,
								objectName,
								methodName,
								overload.parameters,
								"parameter",
								"parameters"
							)
						end

						if overload.returns then
							writeParameters(output, objectName, methodName, overload.returns, "return", "returns")
						end

						addCodeSamples(output, methodData)
					end
				else
					local parameterNames = {}
					for index, parameter in methodData.parameters or {} do
						if not parameter.name then
							print(`{objectName}.{methodName}.parameters.{index}`)
						end
						table.insert(parameterNames, parameter.name or `<i>{string.char(96 + index)}</i>`)
					end

					local returnNames = {}
					for index, value in methodData.returns or {} do
						if not value.name then
							print(`{objectName}.{methodName}.returns.{index}`)
						end
						table.insert(returnNames, value.name or `<i>{string.char(96 + index)}</i>`)
					end

					writeMemberHeader(
						(if isDeprecated then "<del><i>" else "")
							.. methodName
							.. "("
							.. table.concat(parameterNames, ", ")
							.. ")"
							.. (if #returnNames > 1
								then " → (" .. table.concat(returnNames, ", ") .. ")"
								elseif #returnNames > 0 then " → " .. returnNames[1]
								else "")
							.. (if isDeprecated then "</i></del>" else ""),
						"method",
						methodName
					)

					if isDeprecated then
						table.insert(output, "\n:::warning\n\n")
						table.insert(output, "This method is deprecated.")
						if typeof(isDeprecated) == "string" then
							table.insert(output, " " .. isDeprecated)
						end
						table.insert(output, "\n\n:::\n\n")
					end

					if typeof(methodData.documentation) == "table" then
						if methodData.documentation.description then
							table.insert(output, methodData.documentation.description)
						end
					elseif methodData.documentation then
						table.insert(output, methodData.documentation)
					end

					if methodData.parameters then
						writeParameters(
							output,
							objectName,
							methodName,
							methodData.parameters,
							"parameter",
							"parameters"
						)
					end

					if methodData.returns then
						writeParameters(output, objectName, methodName, methodData.returns, "return", "returns")
					end

					addCodeSamples(output, methodData)
				end
			end
		end

		if object.hydrator.configurables and next(object.hydrator.configurables) then
			isConfigurable = true

			local configurables = object.hydrator.configurables
			writeGroupHeader("Configurables")
			for configurableName, configurableData in deprecatedSortedIterate(configurables) do
				writeMemberHeader(configurableName, "configurable", configurableName)

				local configurableDocs = configurableData.documentation
				local typeString = getType(configurableData) or "unknown"
				local configurableType = `It is {aOrAn(typeString)} <code>{escapeMarkdown(typeString)}</code>.`

				if typeof(configurableDocs) == "table" then
					if configurableDocs.description then
						table.insert(output, configurableDocs.description)
						table.insert(output, " " .. configurableType)
					else
						table.insert(output, configurableType)
					end

					local incrementSuffix = if configurableDocs.increment
						then ", and an increment of " .. configurableDocs.increment
						else ""
					if configurableDocs.minimum then
						table.insert(output, `\nIt has a minimum value of {configurableDocs.minimum}{incrementSuffix}.`)
					elseif configurableDocs.maximum then
						table.insert(output, `\nIt has a maximum value of {configurableDocs.maximum}{incrementSuffix}.`)
					elseif configurableDocs.range then
						table.insert(
							output,
							`\nIt ranges between {configurableDocs.range[1]} and {configurableDocs.range[2]}.{if configurableDocs.increment
								then ` It increments by {configurableDocs.increment}.`
								else ""}`
						)
					elseif configurableDocs.increment then
						table.insert(output, `\nIt increments by {configurableDocs.increment}.`)
					end
				elseif configurableDocs then
					table.insert(output, configurableDocs)
					table.insert(output, " " .. configurableType)
				else
					table.insert(output, configurableType)
				end

				addCodeSamples(output, configurableData)
			end
		end

		if object.hydrator.properties and next(object.hydrator.properties) then
			local properties = object.hydrator.properties
			writeGroupHeader("Properties")
			for propertyName, propertyData in deprecatedSortedIterate(properties) do
				writeMemberHeader(propertyName, "property", propertyName)

				local configurableDocs = propertyData.documentation
				local typeString = getType(propertyData) or "unknown"
				local configurableType = `It is {aOrAn(typeString)} <code>{escapeMarkdown(typeString)}</code>.`

				if typeof(configurableDocs) == "table" then
					if configurableDocs.description then
						table.insert(output, configurableDocs.description)
						table.insert(output, " " .. configurableType)
					else
						table.insert(output, configurableType)
					end

					local incrementSuffix = if configurableDocs.increment
						then ", and an increment of " .. configurableDocs.increment
						else ""
					if configurableDocs.minimum then
						table.insert(output, `\nIt has a minimum value of {configurableDocs.minimum}{incrementSuffix}.`)
					elseif configurableDocs.maximum then
						table.insert(output, `\nIt has a maximum value of {configurableDocs.maximum}{incrementSuffix}.`)
					elseif configurableDocs.range then
						table.insert(
							output,
							`\nIt ranges between {configurableDocs.range[1]} and {configurableDocs.range[2]}.{if configurableDocs.increment
								then ` It increments by {configurableDocs.increment}.`
								else ""}`
						)
					elseif configurableDocs.increment then
						table.insert(output, `\nIt increments by {configurableDocs.increment}.`)
					end
				elseif configurableDocs then
					table.insert(output, configurableDocs)
					table.insert(output, " " .. configurableType)
				else
					table.insert(output, configurableType)
				end

				addCodeSamples(output, propertyData)
			end
		end

		if object.hydrator.events and next(object.hydrator.events) then
			local events = object.hydrator.events

			local badEvents = { "Configured", "Damaged", "Loop", "OnClick", "Triggered" }
			for event, _ in events do
				if not table.find(badEvents, event) then
					isProgrammable = true
				end
			end
			writeGroupHeader("Events")
			for eventName, eventData in deprecatedSortedIterate(events) do
				local parameterNames = {}
				for index, parameter in eventData.parameters or {} do
					table.insert(parameterNames, parameter.name or `<i>{string.char(96 + index)}</i>`)
				end

				local header = eventName .. if #parameterNames > 0 then `({table.concat(parameterNames, ", ")})` else ""
				writeMemberHeader(header, "event", eventName)

				if typeof(eventData.documentation) == "table" then
					if eventData.documentation.description then
						table.insert(output, "\n" .. eventData.documentation.description)
					end
				elseif eventData.documentation then
					table.insert(output, "\n" .. eventData.documentation)
				end

				if eventData.parameters then
					writeParameters(output, objectName, eventName, eventData.parameters, "parameter", "parameters")
				end
				addCodeSamples(output, eventData)
			end
		end

		table.insert(metadata.tags, if isProgrammable then "Programmable" else "Non-Programmable")
		table.insert(metadata.tags, if isConfigurable then "Configurable" else "Non-Configurable")
	else
		table.insert(metadata.tags, "Non-Programmable")
		table.insert(metadata.tags, "Non-Configurable")
	end

	local extension
	if #tableOfContents > 0 then
		table.insert(output, 1, `\nexport const toc = [{table.concat(tableOfContents, ",")}]\n\n`)
		table.insert(output, 1, '\nimport Member from "@theme/Member";\n\n')
		extension = ".mdx"
	else
		extension = ".md"
	end

	if next(metadata) then
		table.insert(output, 1, `---\n{serde.encode("yaml", metadata)}---\n`)
	end

	local target = path .. objectName .. extension
	local text = (table.concat(output, ""):gsub("\n\n+", "\n\n"))

	writtenPaths[objectName .. extension] = true

	if not fs.isFile(target) or fs.readFile(target) ~= text then
		fs.writeDir(target)
		fs.writeFile(target, text)
		print(objectName)
	end
	-- print(table.concat(output))
end

for _, subPath in fs.readDir(path) do
	if not writtenPaths[subPath] then
		fs.removeFile(path .. subPath)
	end
end
