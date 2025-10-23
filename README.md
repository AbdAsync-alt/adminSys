# adminSys
This is a simple admin system i made for personal roblox scripts, but i decided to make it open source

# How to use
The main `.init` function takes 4 arguments: name, command-list, rank-list and prefix, everything must be properly formatted

## Commands
Example of one command
```lua
  local name = "admin"

  local command = {
    aliases = {"print", "p"},
    execute = function(self, player, argument1)
      print(player.Name, "printed", argument1)
    end,
    arguments = {
      {
        type = "string",
        required = true
      }
    },
    rank = 5
  }

  local ranks = {
    {
      userId = 1724538681,
      rank = 999
    }
  }
  
  local prefix = "--"

  adminSys.init(name, {command}, ranks, prefix)
```

Currently adminSys supports 5 types of argument types:
| Argument | input | output |
| --- | --- | --- |
| player | "abd" | {AbdAsync (Instance)} |
| int | "0.999" | 1 |
| decimal | 0.314 | 0.314 |
| string | "Hello_world" | "Hello world" |
| team | "guards" | {AbdAsync (Instance)} |
