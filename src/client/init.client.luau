--!strict

local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- Client entry point. Build UI in code from Attributes; never trust or invent server state here.
print(`Client ready: {player.Name}`)
