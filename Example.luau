--!strict
--[[
    example.luau
    Standalone script (NOT a module) demonstrating every public method of the
    Infinite Yield UI Library at:
        https://raw.githubusercontent.com/matpatz/luau/refs/heads/main/public/code/loader/u/ui/infyield.luau

    Just run this directly, e.g.:
        loadstring(game:HttpGet("https://your-domain.com/example.luau"))()
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ========================================
-- 0. LOAD THE LIBRARY
-- ========================================
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/matpatz/luau/refs/heads/main/public/code/loader/u/ui/infyield.luau"
))()

-- ========================================
-- 1. CREATE WINDOW
-- ========================================
-- CreateWindow returns the Library itself (it's a single-window library),
-- so `Window` and `Library` are interchangeable below.
local Window = Library:CreateWindow({
    Title = "My Admin Panel",           -- Custom title (default: "Infinite Yield FE v6.4")
    Version = "1.0",                    -- Version string embedded in default title
    Prefix = ";",                       -- Starting prefix character
    OnCommandRun = function(cmd, args)
        print("[CMD]", cmd, table.concat(args, " "))
    end,
    OnPrefixChange = function(newPrefix: string)
        print("[PREFIX] Changed to:", newPrefix)
    end,
})

local Connections = {}

-- ========================================
-- 2. ADD COMMANDS
-- ========================================

-- Basic command
Window:AddCommand("hello", "Prints hello to the console", function()
    print("Hello, world!")
    Library.Notify("Hello", "Greeting printed to console.", 3)
end)

-- Command with arguments
Window:AddCommand("speed", "Sets walkspeed (usage: speed <number>)", function(...)
    local args = {...}
    local speed = tonumber(args[1])
    if not speed then
        Library.Notify("Error", "Please provide a valid number.\nUsage: speed <number>", 4)
        return
    end
    speed = math.clamp(speed, 0, 1000)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = speed
        Library.Notify("Speed", "WalkSpeed set to " .. tostring(speed), 2)
    end
end)

-- Command with multiple arguments
Window:AddCommand("tp", "Teleport to coordinates (usage: tp <x> <y> <z>)", function(...)
    local args = {...}
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    local z = tonumber(args[3])
    if not x or not y or not z then
        Library.Notify("Error", "Usage: tp <x> <y> <z>", 4)
        return
    end
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(x, y, z)
        Library.Notify("Teleport", string.format("Teleported to (%.1f, %.1f, %.1f)", x, y, z), 2)
    end
end)

-- Command with target player argument
Window:AddCommand("bring", "Brings a player to you (usage: bring <player>)", function(...)
    local args = {...}
    local targetName = table.concat(args, " ")
    local target = nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower():sub(1, #targetName) == targetName:lower() then
            target = player
            break
        end
    end
    if not target then
        Library.Notify("Error", "Player '" .. targetName .. "' not found.", 3)
        return
    end
    local myChar = LocalPlayer.Character
    local theirChar = target.Character
    if myChar and theirChar and myChar:FindFirstChild("HumanoidRootPart") and theirChar:FindFirstChild("HumanoidRootPart") then
        theirChar.HumanoidRootPart.CFrame = myChar.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
        Library.Notify("Bring", "Brought " .. target.Name .. " to you.", 2)
    end
end)

-- Toggle command (manages its own state)
local flyActive = false
local flyConnection = nil
local flyBody = nil
local flyGyro = nil

Window:AddCommand("fly", "Toggles flight on/off", function()
    flyActive = not flyActive
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        flyActive = false
        Library.Notify("Fly", "Cannot fly: no character.", 3)
        return
    end

    if flyActive then
        local hrp = char.HumanoidRootPart
        flyBody = Instance.new("BodyVelocity")
        flyBody.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        flyBody.Velocity = Vector3.zero
        flyBody.Parent = hrp

        flyGyro = Instance.new("BodyGyro")
        flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        flyGyro.P = 9000
        flyGyro.Parent = hrp

        flyConnection = RunService.RenderStepped:Connect(function()
            local camCF = Camera.CFrame
            local moveDir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end
            flyBody.Velocity = moveDir * 80
            flyGyro.CFrame = camCF
        end)

        Library.Notify("Fly", "Flight enabled. WASD to move, Space/Shift for up/down.", 3)
    else
        if flyConnection then flyConnection:Disconnect() flyConnection = nil end
        if flyGyro and flyGyro.Parent then flyGyro:Destroy() flyGyro = nil end
        if flyBody then flyBody:Destroy() flyBody = nil end
        Library.Notify("Fly", "Flight disabled.", 2)
    end
end)

-- Noclip command
local noclipActive = false
local noclipConnection = nil

Window:AddCommand("noclip", "Toggles noclip on/off", function()
    noclipActive = not noclipActive
    if noclipActive then
        noclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
        Library.Notify("Noclip", "Noclip enabled.", 2)
    else
        if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
        Library.Notify("Noclip", "Noclip disabled.", 2)
    end
end)

-- Godmode (simplified)
local godActive = false

Window:AddCommand("god", "Toggles godmode on/off", function()
    godActive = not godActive
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        if godActive then
            char.Humanoid.MaxHealth = math.huge
            char.Humanoid.Health = math.huge
            Library.Notify("God", "Godmode enabled.", 2)
        else
            char.Humanoid.MaxHealth = 100
            char.Humanoid.Health = 100
            Library.Notify("God", "Godmode disabled.", 2)
        end
    end
end)

-- Info command
Window:AddCommand("info", "Shows player and game info", function()
    local char = LocalPlayer.Character
    local pos = char and char:FindFirstChild("HumanoidRootPart")
        and char.HumanoidRootPart.Position or Vector3.zero
    local info = string.format(
        "Player: %s\nUserId: %d\nPosition: (%.1f, %.1f, %.1f)\nPlace: %s\nJobId: %s\nPlayers: %d/%d",
        LocalPlayer.Name,
        LocalPlayer.UserId,
        pos.X, pos.Y, pos.Z,
        game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name,
        game.JobId,
        #Players:GetPlayers(),
        Players.MaxPlayers
    )
    Library.Notify("Info", info, 6)
end)

-- Respawning
Window:AddCommand("respawn", "Respawns your character", function()
    local char = LocalPlayer.Character
    if char then
        char:BreakJoints()
        Library.Notify("Respawn", "Respawning...", 2)
    end
end)

-- Remove command example
Window:AddCommand("temp", "This command will be removed shortly", function()
    Library.Notify("Temp", "You found the temporary command!", 2)
end)
-- Remove it after 5 seconds to demonstrate RemoveCommand
task.delay(5, function()
    Window:RemoveCommand("temp")
    Library.Notify("Removed", "The 'temp' command was removed.", 2)
end)

-- ========================================
-- 3. ALIASES
-- ========================================

Window:AddAlias("hi", "hello")
Window:AddAlias("ws", "speed")
Window:AddAlias("fr", "fly")
Window:AddAlias("clip", "noclip")

-- ========================================
-- 4. WAYPOINTS
-- ========================================

-- Save current position as a waypoint
Window:AddCommand("savepos", "Saves current position as a waypoint (usage: savepos <name>)", function(...)
    local args = {...}
    local name = table.concat(args, " ")
    if #name == 0 then
        Library.Notify("Error", "Usage: savepos <name>", 3)
        return
    end
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        Window:AddWaypoint(name, char.HumanoidRootPart.Position)
        Library.Notify("Waypoint", "Saved waypoint '" .. name .. "'.\nUse Goto in the Waypoints panel to teleport there.", 3)
    end
end)

-- Go to a saved waypoint
Window:AddCommand("goto", "Teleports to a saved waypoint (usage: goto <name>)", function(...)
    local args = {...}
    local name = table.concat(args, " ")
    if #name == 0 then
        Library.Notify("Error", "Usage: goto <name>", 3)
        return
    end
    -- Teleporting by name isn't exposed directly; use the Waypoints panel's Goto button.
    Library.Notify("Waypoint", "Use the Waypoints settings panel to Goto '" .. name .. "'.", 3)
end)

-- ========================================
-- 5. KEYBINDS (programmatic)
-- ========================================

Window:AddKeybind("F", "fly", { Toggle = true })
Window:AddKeybind("N", "noclip", { Toggle = true })
Window:AddKeybind("G", "god", { Toggle = true })
Window:AddKeybind("H", "hello")

-- ========================================
-- 6. PLUGINS (programmatic example)
-- ========================================

Window:AddPlugin("example_plugin.iy")
Window:AddPlugin("utility_pack.iy")

-- ========================================
-- 7. EVENT BINDS (programmatic example)
-- ========================================

Window:AddEventBind("PlayerAdded", "info")
Window:AddEventBind("CharacterAdded", "god")

-- ========================================
-- 8. PREFIX CHANGE
-- ========================================

Window:AddCommand("setprefix", "Changes the command prefix (usage: setprefix <char>)", function(...)
    local args = {...}
    local newPrefix = args[1]
    if not newPrefix or #newPrefix == 0 then
        Library.Notify("Error", "Usage: setprefix <char>", 3)
        return
    end
    if #newPrefix > 3 then
        Library.Notify("Error", "Prefix must be 3 characters or fewer.", 3)
        return
    end
    Window:SetPrefix(newPrefix)
    Library.Notify("Prefix", "Prefix changed to '" .. newPrefix .. "'", 2)
end)

-- ========================================
-- 9. THEME DEMO COMMANDS
-- ========================================

Window:AddCommand("darktheme", "Applies a dark theme", function()
    Window:SetTheme({
        Shade1 = Color3.fromRGB(20, 20, 22),
        Shade2 = Color3.fromRGB(30, 30, 33),
        Shade3 = Color3.fromRGB(55, 55, 60),
        Text1 = Color3.fromRGB(220, 220, 220),
        Text2 = Color3.fromRGB(15, 15, 15),
        Accent = Color3.fromRGB(120, 120, 130),
        Scroll = Color3.fromRGB(55, 55, 60),
    })
    Library.Notify("Theme", "Applied dark theme.", 2)
end)

Window:AddCommand("bluetheme", "Applies a blue theme", function()
    Window:SetTheme({
        Shade1 = Color3.fromRGB(15, 20, 35),
        Shade2 = Color3.fromRGB(20, 28, 50),
        Shade3 = Color3.fromRGB(40, 60, 110),
        Text1 = Color3.fromRGB(180, 200, 255),
        Text2 = Color3.fromRGB(10, 10, 20),
        Accent = Color3.fromRGB(80, 130, 220),
        Scroll = Color3.fromRGB(40, 60, 110),
    })
    Library.Notify("Theme", "Applied blue theme.", 2)
end)

Window:AddCommand("redtheme", "Applies a red theme", function()
    Window:SetTheme({
        Shade1 = Color3.fromRGB(35, 15, 15),
        Shade2 = Color3.fromRGB(50, 20, 20),
        Shade3 = Color3.fromRGB(110, 40, 40),
        Text1 = Color3.fromRGB(255, 200, 200),
        Text2 = Color3.fromRGB(20, 10, 10),
        Accent = Color3.fromRGB(220, 80, 80),
        Scroll = Color3.fromRGB(110, 40, 40),
    })
    Library.Notify("Theme", "Applied red theme.", 2)
end)

Window:AddCommand("greentheme", "Applies a green theme", function()
    Window:SetTheme({
        Shade1 = Color3.fromRGB(15, 30, 15),
        Shade2 = Color3.fromRGB(20, 45, 20),
        Shade3 = Color3.fromRGB(40, 100, 40),
        Text1 = Color3.fromRGB(200, 255, 200),
        Text2 = Color3.fromRGB(10, 20, 10),
        Accent = Color3.fromRGB(80, 200, 80),
        Scroll = Color3.fromRGB(40, 100, 40),
    })
    Library.Notify("Theme", "Applied green theme.", 2)
end)

Window:AddCommand("defaulttheme", "Resets to the default theme", function()
    Window:SetTheme({
        Shade1 = Color3.fromRGB(36, 36, 37),
        Shade2 = Color3.fromRGB(46, 46, 47),
        Shade3 = Color3.fromRGB(78, 78, 79),
        Text1 = Color3.new(1, 1, 1),
        Text2 = Color3.new(0, 0, 0),
        Accent = Color3.fromRGB(150, 150, 151),
        Scroll = Color3.fromRGB(78, 78, 79),
    })
    Library.Notify("Theme", "Reset to default theme.", 2)
end)

-- ========================================
-- 10. WINDOW CONTROL COMMANDS
-- ========================================

Window:AddCommand("hide", "Hides the UI window", function()
    Window:Hide()
end)

Window:AddCommand("show", "Shows the UI window", function()
    Window:Show()
end)

Window:AddCommand("toggleui", "Toggles the UI window visibility", function()
    Window:Toggle()
end)

-- ========================================
-- 11. GETPREFIX EXAMPLE
-- ========================================

Window:AddCommand("getprefix", "Shows the current prefix", function()
    Library.Notify("Prefix", "Current prefix: '" .. Window:GetPrefix() .. "'", 3)
end)

-- ========================================
-- 12. GETELEMENTS EXAMPLE
-- ========================================

Window:AddCommand("getelements", "Prints all UI element references to console", function()
    local elements = Window:GetElements()
    local count = 0
    for name, ref in pairs(elements) do
        count += 1
        print("[Element]", name, "->", tostring(ref))
    end
    Library.Notify("Elements", "All element references printed to console.\nCount: " .. tostring(count), 3)
end)

-- ========================================
-- 13. NOTIFICATION QUEUE DEMO
-- ========================================

Window:AddCommand("notifspam", "Sends 5 queued notifications to test the queue system", function()
    for i = 1, 5 do
        Library.Notify("Queue Test " .. i, "This is notification #" .. i .. " in the queue.", 2)
    end
end)

-- ========================================
-- 14. RUNCOMMAND DEMO (calling commands from code)
-- ========================================

Window:AddCommand("chain", "Runs a chain of commands: hello -> info", function()
    Window:RunCommand(";hello")
    task.wait(0.5)
    Window:RunCommand(";info")
end)

-- ========================================
-- 15. REMOVE ALIAS DEMO
-- ========================================

Window:AddCommand("removealias", "Removes an alias (usage: removealias <name>)", function(...)
    local args = {...}
    local name = args[1]
    if not name then
        Library.Notify("Error", "Usage: removealias <name>", 3)
        return
    end
    Window:RemoveAlias(name)
    Library.Notify("Aliases", "Removed alias '" .. name .. "'", 2)
end)

-- ========================================
-- 16. REMOVE WAYPOINT DEMO
-- ========================================

Window:AddCommand("removepos", "Removes a waypoint (usage: removepos <name>)", function(...)
    local args = {...}
    local name = table.concat(args, " ")
    if #name == 0 then
        Library.Notify("Error", "Usage: removepos <name>", 3)
        return
    end
    Window:RemoveWaypoint(name)
    Library.Notify("Waypoints", "Removed waypoint '" .. name .. "'", 2)
end)

-- ========================================
-- 17. GET THEME DEMO
-- ========================================

Window:AddCommand("gettheme", "Prints current theme colors to console", function()
    local theme = Window:GetTheme()
    for key, color in pairs(theme) do
        print(string.format("[Theme] %s = %d, %d, %d", key,
            math.floor(color.R * 255),
            math.floor(color.G * 255),
            math.floor(color.B * 255)
        ))
    end
    Library.Notify("Theme", "Current theme colors printed to console.", 2)
end)

-- ========================================
-- 18. AUTO-EXEC ON STARTUP
-- ========================================
-- Simulate saving a default waypoint at spawn
task.delay(2, function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        Window:AddWaypoint("SpawnPoint", char.HumanoidRootPart.Position)
        Library.Notify("AutoSave", "Saved spawn point as a waypoint.", 2)
    end
end)

-- ========================================
-- 19. CLEANUP ON CHARACTER REMOVAL
-- ========================================
Connections.CharacterAdded = LocalPlayer.CharacterAdded:Connect(function(char)
    -- Reset toggle states when character changes
    flyActive = false
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
    if flyGyro and flyGyro.Parent then flyGyro:Destroy() flyGyro = nil end
    if flyBody then flyBody:Destroy() flyBody = nil end
    noclipActive = false
    if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
    godActive = false
end)

-- ========================================
-- 20. KEYBIND TO TOGGLE UI VISIBILITY
-- ========================================
-- RightControl to toggle the entire UI
Connections.ToggleUIInput = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        Window:Toggle()
    end
end)

-- ========================================
-- DONE
-- ========================================
Library.Notify("Loaded", "Example script loaded!\n" ..
    "Commands: " .. "hello, speed, tp, bring, fly, noclip, god, info, respawn, " ..
    "savepos, setprefix, darktheme, bluetheme, redtheme, greentheme, defaulttheme, " ..
    "hide, show, toggleui, getprefix, getelements, notifspam, chain, " ..
    "removealias, removepos, gettheme\n" ..
    "Aliases: hi, ws, fr, clip\n" ..
    "Keybinds: F=fly, N=noclip, G=god, H=hello\n" ..
    "RightControl = toggle UI", 8)
