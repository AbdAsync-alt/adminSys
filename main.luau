--// Services //--
local players = game:GetService("Players")
local teams = game:GetService("Teams")
local textChatService = game:GetService("TextChatService")
local runService = game:GetService("RunService")

--// Types //--
type rankType = {
	{
		userId: number,
		rank: number,
	}
}

type rankListType = {rankType}

type additionalArgumentDataType = {
    maxLength: number?,
	minLength: number?,
    player: Player
}

type argumentType = {
    type: "player" | "int" | "decimal" | "string" | "team",
	multi: boolean?,
    required: boolean?,
    additionalArgumentData: additionalArgumentDataType
}

type commandType = {
	aliases: {string},
    execute: (adminInstance, Player, unknown) -> (string?),
	arguments: {argumentType}
}

type commandsListType = {commandType}

type adminInstance = {
    name: string,
    commands: commandsListType,
    ranks: rankListType,
    destroy: (adminInstance) -> (),
    addRank: (adminInstance) -> (),
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
function argumentProcess.int(player: Player, input: string, additionalArgumentData: additionalArgumentDataType)
    local number = tonumber(input)
    if not number then return end 

    number = math.max(additionalArgumentData.minLength or -math.huge, number)
    number = math.min(additionalArgumentData.maxLength or math.huge, number)

    return math.round(number)
end 

function argumentProcess.decimal(player: Player, input: string, additionalArgumentData: additionalArgumentDataType)
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
			if player.Name:find(input) or player.DisplayName:find(input) then
				table.insert(playerList, player)
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
            generalChat:SendAsync("/w "..player.DisplayName)

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

local function processArguments(player: Player, input: inputArguments, arguments: argumentListType)
    local processedArguments = {}

    for index, argument in arguments do
        local inputString = input[index]
        if (not inputString and argument.required) then return `Arugment {index} is required!`, true end 
        if not inputString then continue end 
        
        local processFunction = argumentProcess[argument.type]
        local addionalArgumentData = argument.additionalArgumentData or {}
        if argument.type == "player" then table.insert(addionalArgumentData, player) end 

        local result = processFunction(inputString, addionalArgumentData)
        if (not result and argument.required) then return `Arugment {index} is not the proper type!`, true end 
        
        table.insert(processedArguments, result)
    end 
    
    return processedArguments
end 

--// Module
local module = {}
module.__index = module

function module.init(name: string, commands: commandsListType, rankList: rankListType, prefix: string)
    --// Make sure arguments are valid
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

	--// Iterate through commands & ranks
	for index, command in commands do
        local aliasType = typeof(command.aliases)
        assert(aliasType == "table", `Command #{index} expected alias to be table but got {aliasType}`)
        assert(command.aliases[1], `Command #{index} expects atleast one alias!`)
         
        local funcType = typeof(command.execute)
        assert(funcType == "function", `Command #{index} expected execute to be function but got {funcType}`)

        --// Iterate through aliases to make sure they're strings to avoid future errors
        for _,name in next, command.aliases do 
            local aliasType = typeof(name)
            assert(aliasType == "string", `Command #{index} has alias with type {aliasType} instead of string`)
        end 
        
        --// Validate arguments
        if not command.arguments then continue end 
        for argumentIndex, argument in command.arguments do
            local argumentType = typeof(argument.type)
            assert(argumentType == "string", `Command #{index}, Argument #{argumentIndex} expected string but got {argumentType}`)
            assert(table.find({"player", "int", "decimal", "string", "extPlayer", "team"}, argument.type), `Command #{index}, Argument #{argumentIndex} needs to be 'player', 'int', 'decimal', 'string', 'extPlayer' or 'team'`) 
            
            --// Make sure range is valid for int and decimal type
            if ((argument.type == "int" or argument.type == "decimal") and argument.maxLength and argument.minLength) then 
                local valid = if argument.minLength > argument.maxLength then "min > max" elseif argument.maxLength < argument.minLength then "max < min" else nil
                assert(not valid, `Command #{index}, Argument #{argumentIndex} has invalid range ({valid})`)
            end 
        end 
	end

    --// Check if an instance already exists
    for _,instance: adminInstance in next, sharedTable.activeInstances do 
        if instance.name ~= name then continue end     
        warn("An admin instance with the same name was found and was overwritten")
        instance:destroy()
    end

    --// Create instance
	local self = setmetatable({}, module)
    self.connections = {}
    self.commands = commands
    self.rankList = rankList
    self.prefix = prefix
    self.name = name

    --// Cache
    table.insert(sharedTable.activeInstances, self)

    --// Connections
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

    --// Return instance
	return self
end

function module:processCommand(player: Player, message: string)
    --// Check if message begins with prefix
    if message:sub(1, #self.prefix) ~= self.prefix then return end 
    
    local rest = message:sub(#self.prefix+1)
    local split = rest:split(" ")

    local requestedCommand = split[1]
    local arguments = split
    table.remove(arguments, 1)

    local foundCommand: commandType 
    for _,command in next, self.commands do 
        if not table.find(command.aliases, requestedCommand) then continue end
        foundCommand = command
        break
    end 
    if not foundCommand then return end

    local processedArguments, fail = processArguments(player, arguments, foundCommand.arguments)
    if fail then sendMessage(message, player) return end 

    foundCommand.execute(self, player, unpack(processedArguments))
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
