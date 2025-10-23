--// Services //--
local players = game:GetService("Players")

--// Types //--
type rankType = {
	{
		userId: number,
		rank: number,
	}
}

type rankListType = {rankType}

type commandType = {
	aliases: { string },
    execute: () -> (string?),
	arguments: {
		{
			type: "player" | "int" | "decimal" | "string" | "extPlayer" | "team",
			maxLength: number?,
			minLength: number?,
			multi: boolean?
		}
	},
}

type commandsType = {commandType}

--// Functions //--
local function getPlayers(input: string)
	local playerList = {}

	for _, player in players:GetPlayers() do
		if not (player.Name:find(input) or player.DisplayName:find(input)) then continue end

		table.insert(playerList, player)
	end

	return #playerList > 0 and playerList or nil
end

--// Module
local module = {}
module.__index = module

function module.init(commands: commandsType, rankList: rankListType)
	--// Make sure arguments are valid
	local commandsType = typeof(commands)
	local rankListType = type(rankList)

	assert(commandsType == "table", `Argument #1 (commands) expected table but got {commandsType}`)
	assert(rankListType == "table", `Argument #2 (rankList) excpected table but got {rankListType}`)

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

    --// Create instance
	local self = setmetatable({}, module)

	return self
end

return module
