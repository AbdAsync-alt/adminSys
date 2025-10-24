--// Services //--
local players = game:GetService("Players")
local teams = game:GetService("Teams")
local textChatService = game:GetService("TextChatService")
local runService = game:GetService("RunService")

--// Types //--
type rankType = {
	userId: number,
	rank: number,
}

type rankListType = {rankType}

type additionalArgumentDataType = {
	maxLength: number?,
	minLength: number?,
	player: Player
}

type argumentType = {
	type: "player" | "int" | "decimal" | "string" | "team",
	required: boolean?,
	additionalArgumentData: additionalArgumentDataType?
}

type separateArguments = {string}

type commandType = {
	aliases: {string},
	execute: (adminInstance, Player, unknown) -> (),
	arguments: {argumentType},
	separateArguments: separateArguments,
	rank: number
}


type commandsListType = {commandType}

type adminInstance = {
	name: string,
	commands: commandsListType,
	ranks: rankListType,
	destroy: (adminInstance) -> (),
	addRank: (adminInstance, userId: number) -> (),
	processCommand: (adminInstance, Player, string) -> (),
	prefix: string,
	connections: {RBXScriptConnection}
}

type argumentListType = {argumentType}

type inputArguments = {string}

--// Values //--
local sharedTable = if getgenv then getgenv() else shared
if not sharedTable.activeInstances then 
	sharedTable.activeInstances = {}
end
local argumentProcess = {}
local textChannels = textChatService:WaitForChild("TextChannels")
local generalChat: TextChannel = textChannels:WaitForChild("RBXGeneral")
local localPlayer = players.LocalPlayer

--// General functions //--
--// Argument type processes
function argumentProcess.int(input: string, additionalArgumentData: additionalArgumentDataType)
	local number = tonumber(input)
	if not number then return end 

	number = math.max(additionalArgumentData.minLength or -math.huge, number)
	number = math.min(additionalArgumentData.maxLength or math.huge, number)

	return math.round(number)
end 

function argumentProcess.decimal(input: string, additionalArgumentData: additionalArgumentDataType)
	local number = tonumber(input)
	if not number then return end 

	number = math.max(additionalArgumentData.minLength or -math.huge, number)
	number = math.min(additionalArgumentData.maxLength or math.huge, number)

	return number
end

function argumentProcess.player(input: string, additionalArgumentData: additionalArgumentDataType)
	local lower = input:lower()
	local player = additionalArgumentData.player
	
	local playerList = {}
	if lower == "all" then
		playerList = players:GetPlayers()
	elseif lower == "others" then
		local others = players:GetPlayers()
		table.remove(others, table.find(others, input))
		playerList = others
	elseif lower == "me" then
		playerList = {player}
	else
		for _,otherPlayer in next, players:GetPlayers() do
			if otherPlayer.Name:find(input) or otherPlayer.DisplayName:find(input) then
				table.insert(playerList, otherPlayer)
			end
		end
	end

	return #playerList > 0 and playerList or nil
end

function argumentProcess.string(input: string)
	return input:gsub("_", " ")
end

function argumentProcess.team(input: string)
	local lowerCase = input:lower()

	for _,team in next, teams:GetChildren() do 
		if not team.Name:find(lowerCase) then continue end 

		return team:GetPlayers()
	end
end 

--// Functions
local function sendMessage(message: string, player: Player?) --// Might be an odd way to do this
	if not localPlayer then return end 
	
	pcall(function() 
		if player then
			coroutine.wrap(function() 
				generalChat:SendAsync("/w "..player.DisplayName)
			end)()

			local start = os.clock()
			local channel: TextChannel

			while os.clock()-start < 5 do 
				channel = textChannels:FindFirstChild(`RBXWhisper:{player.UserId}_{localPlayer.UserId}`) or textChannels:FindFirstChild(`RBXWhisper:{localPlayer.UserId}_{player.UserId}`)
				if channel then break end 
				runService.Heartbeat:Wait()
			end

			if not channel then return end 
			channel:SendAsync(message)
		else

			generalChat:SendAsync(message) 
		end 
	end)
end 

local function processArguments(player: Player, input: inputArguments, arguments: argumentListType, separateArguments: {string})
	local processedArguments = {}

	for index, argument in arguments do
		local inputString = input[index]
		local result 
		for _,type in next, separateArguments[index] do 
			if (not inputString and argument.required) then return `Arugment {index} is required!`, true end 
			if not inputString then continue end 

			local processFunction = argumentProcess[type]
			local addionalArgumentData = argument.additionalArgumentData or {}
			if type == "player" then  
				addionalArgumentData.player = localPlayer
			end 

			result = processFunction(inputString, addionalArgumentData)
			if result then break end
		end 

		if (not result and argument.required) then return `Arugment {index} is not the proper type!`, true end 
		table.insert(processedArguments, result)
	end 

	return processedArguments
end 

--// Module //--
local module = {}
module.__index = module

function module.init(name: string, commands: commandsListType, rankList: rankListType, prefix: string)
	local nameType = typeof(name)
	local commandsType = typeof(commands)
	local rankListType = typeof(rankList)
	local prefixType = typeof(prefix)    

	assert(nameType == "string", `Argument #1 (name) expected string but got {nameType}`)
	assert(commandsType == "table", `Argument #2 (commands) expected table but got {commandsType}`)
	assert(rankListType == "table", `Argument #3 (rankList) expected table but got {rankListType}`)
	assert(prefixType == "string", `Argument #4 (prefix) expected but got {prefix}`)

	assert(commands[1], "Commands should have atleast one command!")
	assert(rankList[1], "Rank-list should have atleast one user!")

	for index, command in commands do
		local commandType = typeof(command)
		assert(commandType == "table", `Command #{index} expected table but got {commandType}`)

		local aliasType = typeof(command.aliases)
		assert(aliasType == "table", `Command #{index} expected alias to be table but got {aliasType}`)
		assert(command.aliases[1], `Command #{index} expects atleast one alias!`)

		local funcType = typeof(command.execute)
		assert(funcType == "function", `Command #{index} expected execute to be function but got {funcType}`)

		for _,name in next, command.aliases do 
			local type = typeof(name)
			assert(type == "string", `Command #{index} has alias with type {aliasType} instead of string`)
		end 

		if not command.arguments then continue end 
		
		local separateArguments = {}
		command.separateArguments = separateArguments
		for argumentIndex, argument in command.arguments do
			local argumentSelfType = typeof(argument)
			assert(argumentSelfType == "table", `Command #{index}, Argument #{argumentIndex} expected table but got {argumentSelfType}`)

			local argumentType = typeof(argument.type)
			assert(argumentType == "string", `Command #{index}, Argument #{argumentIndex} expected string but got {argumentType}`)

			local split = argument.type:split("|")
			
			local typeSeparate = {}
			table.insert(separateArguments, typeSeparate)
			for _,type in next, split do 
				assert(table.find({"player", "int", "decimal", "string", "extPlayer", "team"}, type), `Command #{index}, Argument #{argumentIndex} type needs to be 'player', 'int', 'decimal', 'string', 'extPlayer' or 'team'`) 
				
				table.insert(typeSeparate, type)
				if ((argument.type == "int" or argument.type == "decimal") and argument.maxLength and argument.minLength) then 
					local valid = if argument.minLength > argument.maxLength then "min > max" elseif argument.maxLength < argument.minLength then "max < min" else nil
					assert(not valid, `Command #{index}, Argument #{argumentIndex} has invalid range ({valid})`)
				end 
			end
		end 
	end

	for _,instance: adminInstance in next, sharedTable.activeInstances do 
		if typeof(instance) ~= "table" or instance.name ~= name then continue end     
		warn("An admin instance with the same name was found and was overwritten")
		instance:destroy()
	end

	local self = setmetatable({}, module)
	self.connections = {}
	self.commands = commands
	self.rankList = rankList
	self.prefix = prefix
	self.name = name

	table.insert(sharedTable.activeInstances, self)

	local function initPlayer(player) 
		local connection = player.Chatted:Connect(function(str) 
			self:processCommand(player, str)
		end)
		table.insert(self.connections, connection)
	end 

	for _,player in next, players:GetPlayers() do 
		initPlayer(player)
	end 

	table.insert(self.connections, players.PlayerAdded:Connect(initPlayer))

	return self
end

function module:processCommand(player: Player, message: string)
	if message:sub(1, #self.prefix) ~= self.prefix then return end 

	local rest = message:sub(#self.prefix+1)
	local split = rest:split(" ")

	local requestedCommand = split[1]
	local arguments = split
	table.remove(arguments, 1)

	local rank = 0
	for _,playerRank: rankType in next, self.rankList do 
		if playerRank.userId ~= player.UserId then continue end 
		rank = playerRank.rank 
		break
	end

	local foundCommand: commandType 
	for _,command in next, self.commands do 
		if not table.find(command.aliases, requestedCommand) then continue end
		foundCommand = command
		break
	end 
	if not foundCommand then return end

	if foundCommand.rank > rank then sendMessage("You do not have permission to run this command", player) return end 

	local processedArguments, fail = processArguments(player, arguments, foundCommand.arguments, foundCommand.separateArguments)
	if fail then sendMessage(processedArguments, player) return end 

	foundCommand.execute(self, player, unpack(processedArguments))
end 

function module:setRank(userId: number, rank: number)
	for _,playerRank: rankType in next, self.rankList do 
		if playerRank.userId ~= userId then continue end 
		playerRank.rank = rank
		break
	end

	table.insert(self.rankList, {
		userId = userId,
		rank = rank
	})
end 

function module:removeRank(userId: number)
	for index,_ in ipairs(self.rankList) do 
		table.remove(self.rankList, index)
		break
	end
end 

function module:sendMessage(message: string, player: Player?)
	sendMessage(message, player)
end 

function module:destroy()
	for _,connection in next, self.connections do 
		connection:Disconnect()
	end 
	setmetatable(self, nil)
	local ourIndex = table.find(sharedTable.activeInstances, self)
	table.remove(sharedTable.activeInstances, ourIndex)
end 

return module
