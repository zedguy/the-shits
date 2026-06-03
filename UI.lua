local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
local Options = Library.Options
local Toggles = Library.Toggles

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Folder = Workspace:WaitForChild("Entities")
local charactersFolder = Workspace:WaitForChild("Characters"):WaitForChild("Player")

----------------------------------------------------------------
-- SPEED EFFECT MODULE SYSTEM
----------------------------------------------------------------
local SharedModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"):WaitForChild("SharedCharacter")
local SharedCharacter = require(SharedModule)

local ClientSpeedEffect = {
    Name = "ClientSpeedBoost",
    Enabled = false, -- Default to false so it respects UI toggle state on load
    SpeedLevel = 3,  -- Initialized via UI value later
    _connection = nil,
    _sharedCharObj = nil,
    _stackName = "CLIENT_SPEED_OVERRIDE"
}

function ClientSpeedEffect:Start()
    local character = LocalPlayer.Character
    if not character then 
        warn("[-] Character not found. Postponing execution until character spawns.")
        return 
    end

    local success, obj = pcall(function()
        return SharedCharacter.getObject(character) or (SharedCharacter.new and SharedCharacter.new(character))
    end)

    if not success or not obj then
        warn("[-] Failed to safely bind to the game's SharedCharacter framework.")
        return
    end

    self._sharedCharObj = obj
    self.Enabled = true
    print("[+] Speed modifier successfully attached.")

    if self._connection then 
        self._connection:Disconnect() 
    end

    self._connection = RunService.Heartbeat:Connect(function(deltaTime)
        if not self.Enabled or not self._sharedCharObj then return end
        
        pcall(function()
            local speedStack = self._sharedCharObj.Stacks and self._sharedCharObj.Stacks.SpeedStack
            if speedStack then
                speedStack:RemoveModifier(self._stackName)
                
                speedStack:AddModifier(self._stackName, function(modifierData)
                    -- Formula matches the decompiler: Base * (1 + Level / 3)
                    modifierData.Output = (modifierData.Output or 1) * (1 + ((self.SpeedLevel - 1) * 5))
                    return false
                end, 5, true)
                
                if self._sharedCharObj.UpdateWalkSpeed then
                    self._sharedCharObj:UpdateWalkSpeed()
                end
            end
        end)
    end)
end

function ClientSpeedEffect:Stop()
    self.Enabled = false
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    
    pcall(function()
        if self._sharedCharObj and self._sharedCharObj.Stacks and self._sharedCharObj.Stacks.SpeedStack then
            self._sharedCharObj.Stacks.SpeedStack:RemoveModifier(self._stackName)
            if self._sharedCharObj.UpdateWalkSpeed then
                self._sharedCharObj:UpdateWalkSpeed()
            end
        end
    end)
    
    self._sharedCharObj = nil
    print("[-] Speed modifier stopped and removed.")
end

local WalkspeedConnection
local function StartForceWalkspeed()
    if WalkspeedConnection then
        WalkspeedConnection:Disconnect()
    end
    WalkspeedConnection = RunService.Heartbeat:Connect(function()
        if not Toggles.SpeedHack.Value then
            return
        end

        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = Options.SpeedAmount.Value
        end
    end)
end
local function StopForceWalkspeed()
    if WalkspeedConnection then
        WalkspeedConnection:Disconnect()
        WalkspeedConnection = nil
    end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = 16
    end
end


LocalPlayer.CharacterAdded:Connect(function(character)
    if not Toggles.SpeedHack or not Toggles.SpeedHack.Value then return end
    if Options.SpeedMethod and Options.SpeedMethod.Value ~= "Speed Effect" then return end

    task.spawn(function()
        repeat
            task.wait()
            local success, obj = pcall(function()
                return SharedCharacter.getObject(character)
            end)
        until success and obj and obj.Stacks and obj.Stacks.SpeedStack

        ClientSpeedEffect:Stop()
        ClientSpeedEffect.Enabled = true
        ClientSpeedEffect._sharedCharObj = obj
        ClientSpeedEffect:Start()
        print("[+] Reattached speed after respawn")
    end)
end)

----------------------------------------------------------------
-- INTERFACE CONFIGURATION
----------------------------------------------------------------
local Window = Library:CreateWindow({
    Title = "Darkest Hours",
    Center = true,
    AutoShow = true,
    ShowCustomCursor = true,
    Icon = 80011400170018,
})

local Tabs = {
    Home = Window:AddTab("Home", "door-closed"),
    Main = Window:AddTab("Main", "sword"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Utilities = Window:AddTab("Utilities", "wrench"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

local function FormatName(str)
    return str:gsub("(%l)(%u)", "%1 %2")
end

local function performRevive(prompt)
    local char = LocalPlayer.Character
    if char and char.PrimaryPart and prompt.Parent then
        local ogcf = char.PrimaryPart.CFrame
        char:PivotTo(prompt.Parent.CFrame * CFrame.new(0, -3, 0))
        task.wait(.55)
        if keypress then keypress("0x45") end
        prompt.HoldDuration = 0
        if fireproximityprompt then fireproximityprompt(prompt) end
        task.wait(0.5)
        if keyrelease then keyrelease("0x45") end
        task.wait()
        char:PivotTo(ogcf)
    end
end

local isLegacyChat = TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService
local function chatMessage(str)
    str = tostring(str)
    if not isLegacyChat then
        TextChatService.TextChannels.RBXGeneral:SendAsync(str)
    else
        ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(str, "All")
    end
end

local function getMapSpawns()
    if workspace.MapFolder.Main:FindFirstChildOfClass("Model") then
        game.Players.LocalPlayer.Character:PivotTo(workspace.MapFolder.Main:FindFirstChildOfClass("Model").Spawns:GetChildren()[1].Position + Vector3.new(0,4,0))
    end
end

local function getLobbySpawns()
    game.Players.LocalPlayer.Character:PivotTo(workspace.MapFolder.Lobby:FindFirstChildOfClass("Model").LobbySpawn.Position + Vector3.new(0,4,0))
end

local LeftHome = Tabs.Home:AddLeftGroupbox("you")
local RightHome = Tabs.Home:AddRightGroupbox("main coder")
local Player = Tabs.Main:AddLeftGroupbox("Player")
local Revives = Tabs.Main:AddRightGroupbox("Revives")
local Prompts = Tabs.Main:AddLeftGroupbox("Prompts")
local Trolls = Tabs.Utilities:AddLeftGroupbox("Trolls")
local Lists = Tabs.Utilities:AddRightGroupbox("Lists")
local Teleports = Tabs.Utilities:AddRightGroupbox("Teleports")
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")
local ESPBox = Tabs.Visuals:AddLeftTabbox("ESP")
local Notifs = Tabs.Visuals:AddRightGroupbox("Notifications")
local ESPTab = ESPBox:AddTab("ESP")
local ESPSETTab = ESPBox:AddTab("Settings")

Teleports:AddButton("Lobby", function() game.Players.LocalPlayer:SetAttribute("Ingame", false) end)
Teleports:AddButton("Current Map", function() game.Players.LocalPlayer:SetAttribute("Ingame", true) end)

Lists:AddToggle("ShowRoundInfo", {
    Default = false,
    Text = "Show Round Info Overlay",
    Callback = function(Value) end,
})

Revives:AddDropdown("ChosenRevive", {
    Text = "Players To Reivive",
    Default = 1,
    Multi = true,
    SpecialType = "Players",
    ExcludeLocalPlayer = true,
    EnablePlayerImages = true,
    Searchable = true,
    Values = {},
})
Revives:AddButton("Revive Players", function() end)

Revives:AddToggle("AutoRevive", {
    Default = false,
    Text = "Enable Auto-Revive",
    Callback = function(Value) end,
})

Revives:AddToggle("ReviveFriends", {
    Default = false,
    Text = "Only Revive Friends",
    Callback = function(Value) end,
})

Revives:AddToggle("ReviveChosen", {
    Default = false,
    Text = "Only Revive Chosen Players",
    Callback = function(Value) end,
})

RightHome:AddImage("coder", {
    Image = "rbxassetid://109590486755750",
    Height = 200,
})

LeftHome:AddImage("profile", {
    Image = "rbxassetid://96309516831582",
    Height = 200,
})

----------------------------------------------------------------
-- SPEED INTERFACE LOGIC INTERACTION
----------------------------------------------------------------
Player:AddDropdown("SpeedMethod", {
    Text = "Speed Method",
    Values = { "Speed Effect", "Force Walkspeed" },
    Default = 1,
    Multi = false,
})

Player:AddToggle("SpeedHack", {
    Default = false,
    Text = "Enable Speed Hack",
    Callback = function(Value)
        if Value then
            if Options.SpeedMethod.Value == "Speed Effect" then
                ClientSpeedEffect:Start()
            elseif Options.SpeedMethod.Value == "Force Walkspeed" then 
                StartForceWalkspeed()
            end
        else
            ClientSpeedEffect:Stop()
            StopForceWalkspeed()
            
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = 16
            end
        end
    end,
})

Player:AddSlider("SpeedAmount", {
    Text = "Walkspeed",
    Default = 3,
    Min = 0,
    Max = 45,
    Rounding = 0,
    Callback = function(Value)
        ClientSpeedEffect.SpeedLevel = Value
        if Toggles.SpeedHack.Value and Options.SpeedMethod.Value == "Force Walkspeed" then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = Value
            end
        end
    end
})

Options.SpeedMethod:OnChanged(function()
    if Toggles.SpeedHack.Value then
        if Options.SpeedMethod.Value == "Speed Effect" then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
            ClientSpeedEffect:Start()
            StopForceWalkspeed()
        else
            ClientSpeedEffect:Stop()
            StartForceWalkspeed()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = Options.SpeedAmount.Value end
        end
    end
end)

----------------------------------------------------------------
-- UTILITIES & MISC
----------------------------------------------------------------
Trolls:AddLabel("warnn", {
    DoesWrap = true,
    Text = '[<font color="rgb(220, 0, 0)">WARNING</font>] this can get you banned since its visible asf.'
})

Trolls:AddDropdown("ChosenTrollEnt", {
    Text = "Entity To Troll",
    Values = {"None Spawned"},
    Default = 1,
    Multi = false,
})

Trolls:AddToggle("HoverEntity", {
    Default = false,
    Text = "Hover Over Entity",
    Callback = function(Value) end,
})

Trolls:AddToggle("UnderEntity", {
    Default = false,
    Text = "Hide Under Entity",
    Callback = function(Value) end,
})

Trolls:AddToggle("OrbitEntity", {
    Default = false,
    Text = "Orbit Entity",
    Callback = function(Value) end,
})

Notifs:AddToggle("NotifyChat", {
    Default = false,
    Text = "Notify Chat",
    Callback = function(Value) end,
})

Notifs:AddInput("NotifText", {
    Default = "spawned btw",
    Numeric = false,
    Finished = false,
    ClearTextOnFocus = false,
    Text = "Chat Suffix",
    Placeholder = "spawn text",
    Callback = function(Value) end,
})

Player:AddToggle("MaxStamina", {
    Default = false,
    Text = "Max Stamina",
    Callback = function(Value) end,
})

Prompts:AddToggle("InstantPrompts", {
    Default = false,
    Text = "Instant Interact",
    Callback = function(Value) end,
})

Prompts:AddToggle("AutoInteract", {
    Default = false,
    Text = "Auto Interact",
    Callback = function(Value) end,
})

ESPTab:AddToggle("PlayersESP", {
    Default = false,
    Text = "Player",
    Callback = function(Value) end,
}):AddColorPicker("PlayerColor", {
    Default = Color3.new(1, 1, 1),
    Title = "PlayerColor",
    Transparency = 0,
})

ESPTab:AddToggle("EntitiesESP", {
    Default = false,
    Text = "Entities",
    Callback = function(Value) end,
}):AddColorPicker("EntitiesColor", {
    Default = Color3.new(1, 0, 0),
    Title = "EntitiesColor",
    Transparency = 0,
})

ESPTab:AddToggle("ObjectiveESP", {
    Default = false,
    Text = "Objective",
    Callback = function(Value) end,
}):AddColorPicker("ObjectiveColor", {
    Default = Color3.new(1, 0.8, 0),
    Title = "ObjectiveColor",
    Transparency = 0,
})

ESPSETTab:AddToggle("ESPHighlight", {
    Default = true,
    Text = "Highlights",
    Callback = function(Value) end,
})

ESPSETTab:AddToggle("ESPText", {
    Default = true,
    Text = "Text",
    Callback = function(Value) end,
})

ESPSETTab:AddToggle("ESPTracer", {
    Default = false,
    Text = "Tracers",
    Callback = function(Value) end,
})

ESPSETTab:AddToggle("PulseObjectives", {
    Default = false,
    Text = "Pulse Objectives",
    Callback = function(Value) end,
})

MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = false,
    Text = "Open Keybind Menu",
    Callback = function(Value)
        Library.KeybindFrame.Visible = Value
    end,
})

MenuGroup:AddLabel("Menu bind")
    :AddKeyPicker("MenuKeybind", {
        Default = "RightShift",
        NoUI = true,
        Text = "Menu keybind"
    })

MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("DarkestHours")
SaveManager:SetFolder("DarkestHours/main")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()