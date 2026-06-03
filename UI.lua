local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Folder = Workspace:WaitForChild("Entities")
local charactersFolder = Workspace:WaitForChild("Characters"):WaitForChild("Player")

-- ==========================
-- LIBRARY INITIALIZATION
-- ==========================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

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

-- ==========================
-- LOGIC & UTILITIES
-- ==========================

local isLegacyChat = TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService
local function chatMessage(str)
    str = tostring(str)
    if not isLegacyChat then
        TextChatService.TextChannels.RBXGeneral:SendAsync(str)
    else
        ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(str, "All")
    end
end

-- Reusable revive sequence
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

local function reviveAllDowned()
    for _, v in ipairs(charactersFolder:GetDescendants()) do
        if v.Name == "RevivePrompt" and v:IsA("ProximityPrompt") then
            performRevive(v)
            task.wait(0.2)
        end
    end
end

-- Local ESP Module
local function espify(m, espCategoryColor)
    if m:FindFirstChild("__esp") then return end

    local tag = Instance.new("BoolValue")
    tag.Name = "__esp"
    tag.Parent = m
    
    local h = Instance.new("Highlight")
    h.Name = "__highlight"
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.FillTransparency = 0.8
    h.OutlineTransparency = 0
    h.FillColor = espCategoryColor
    h.OutlineColor = espCategoryColor
    h.Enabled = Toggles.ESPHighlight and Toggles.ESPHighlight.Value or false
    h.Adornee = m
    h.Parent = m

    for _, v in ipairs(m:GetDescendants()) do
        if v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
            v.AlwaysOnTop = Toggles.ESPText and Toggles.ESPText.Value or false
        end
    end
end

local function scanEntities()
    for _, v in ipairs(Folder:GetDescendants()) do
        if v:IsA("Model") then
            if Toggles.EntitiesESP.Value then
                espify(v, Options.EntitiesColor.Value)
            end
            
            local h = v:FindFirstChild("__highlight")
            if h then
                h.Enabled = (Toggles.EntitiesESP.Value and Toggles.ESPHighlight.Value)
                h.FillColor = Options.EntitiesColor.Value
                h.OutlineColor = Options.EntitiesColor.Value
            end

            if v:FindFirstChild("__esp") then
                for _, g in ipairs(v:GetDescendants()) do
                    if g:IsA("BillboardGui") or g:IsA("SurfaceGui") then
                        g.AlwaysOnTop = Toggles.ESPText.Value
                    end
                end
            end
        end
    end
end

-- Track new entity spawns for Notifs and ESP
Folder.DescendantAdded:Connect(function(v)
    if v:IsA("Model") then
        if Toggles.NotifyChat.Value then
            local suffix = Options.NotifText.Value
            chatMessage(v.Name .. " " .. suffix)
        end
        if Toggles.EntitiesESP.Value then
            task.defer(espify, v, Options.EntitiesColor.Value)
        end
    end
end)

charactersFolder.DescendantAdded:Connect(function(v)
    if v.Name == "RevivePrompt" and Toggles.AutoRevive.Value and v:IsA("ProximityPrompt") then
        task.wait(1)
        performRevive(v)
    end
end)

-- Background loop for Player mods
task.spawn(function()
    while task.wait() do
        local char = LocalPlayer.Character
        -- Speed Hack loop
        if Toggles.SpeedHack and Toggles.SpeedHack.Value and char and char:FindFirstChild("Humanoid") then
            if Options.SpeedMethod.Value == "Force Walkspeed" then
                char.Humanoid.WalkSpeed = Options.SpeedAmount.Value
            end
        end
        
        -- Instant Prompts loop
        if Toggles.InstantPrompts and Toggles.InstantPrompts.Value then
            for _, v in ipairs(Workspace:GetDescendants()) do
                if v:IsA("ProximityPrompt") then
                    v.HoldDuration = 0
                end
            end
        end
    end
end)

-- ==========================
-- UI LAYOUT & CALLBACKS
-- ==========================

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
    Callback = function(Value)
    end,
})

Revives:AddDropdown("ChosenRevive", {
    Text = "Players To Revive",
    Default = 1,
    Multi = true,
    SpecialType = "Players",
    ExcludeLocalPlayer = true,
    EnablePlayerImages = true,
    Searchable = true,
    Values = {},
})

Revives:AddButton("Revive Players", function() 
    task.spawn(reviveAllDowned)
end)

Revives:AddToggle("AutoRevive", {
    Default = false,
    Text = "Enable Auto-Revive",
    Callback = function(Value)
        if Value then task.spawn(reviveAllDowned) end
    end,
})

Revives:AddToggle("ReviveFriends", {
    Default = false,
    Text = "Only Revive Friends",
    Callback = function(Value)
    end,
})

Revives:AddToggle("ReviveChosen", {
    Default = false,
    Text = "Only Revive Chosen Players",
    Callback = function(Value)
    end,
})

RightHome:AddImage("coder", {
    Image = "rbxassetid://109590486755750",
    Height = 200,
})

LeftHome:AddImage("profile", {
    Image = "rbxassetid://96309516831582",
    Height = 200,
})

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
    end,
})

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
    Callback = function(Value)
    end,
})

Trolls:AddToggle("UnderEntity", {
    Default = false,
    Text = "Hide Under Entity",
    Callback = function(Value)
    end,
})

Trolls:AddToggle("OrbitEntity", {
    Default = false,
    Text = "Orbit Entity",
    Callback = function(Value)
    end,
})

Notifs:AddToggle("NotifyChat", {
    Default = false,
    Text = "Notify Chat",
    Callback = function(Value)
    end,
})

Notifs:AddInput("NotifText", {
    Default = "spawned btw",
    Numeric = false,
    Finished = false,
    ClearTextOnFocus = false,
    Text = "Chat Suffix",
    Placeholder = "spawn text",
    Callback = function(Value)
    end,
})

Player:AddToggle("MaxStamina", {
    Default = false,
    Text = "Max Stamina",
    Callback = function(Value)
    end,
})

Player:AddSlider("SpeedAmount", {
    Text = "Walkspeed",
    Default = 24,
    Min = 0,
    Max = 128,
    Rounding = 0,
})

Prompts:AddToggle("InstantPrompts", {
    Default = false,
    Text = "Instant Interact",
    Callback = function(Value)
    end,
})

Prompts:AddToggle("AutoInteract", {
    Default = false,
    Text = "Auto Interact",
    Callback = function(Value)
    end,
})

ESPTab:AddToggle("PlayersESP", {
    Default = false,
    Text = "Player",
    Callback = function(Value)
        -- Hook to Player ESP function if needed later
    end,
}):AddColorPicker("PlayerColor", {
    Default = Color3.new(1, 1, 1),
    Title = "PlayerColor",
    Transparency = 0,
})

ESPTab:AddToggle("EntitiesESP", {
    Default = false,
    Text = "Entities",
    Callback = function(Value)
        scanEntities()
    end,
}):AddColorPicker("EntitiesColor", {
    Default = Color3.new(1, 0, 0),
    Title = "EntitiesColor",
    Transparency = 0,
})

ESPTab:AddToggle("ObjectiveESP", {
    Default = false,
    Text = "Objective",
    Callback = function(Value)
    end,
}):AddColorPicker("ObjectiveColor", {
    Default = Color3.new(1, 0.8, 0),
    Title = "ObjectiveColor",
    Transparency = 0,
})

ESPSETTab:AddToggle("ESPHighlight", {
    Default = true,
    Text = "Highlights",
    Callback = function(Value)
        scanEntities()
    end,
})

ESPSETTab:AddToggle("ESPText", {
    Default = true,
    Text = "Text",
    Callback = function(Value)
        scanEntities()
    end,
})

ESPSETTab:AddToggle("ESPTracer", {
    Default = false,
    Text = "Tracers",
    Callback = function(Value)
    end,
})

ESPSETTab:AddToggle("PulseObjectives", {
    Default = false,
    Text = "Pulse Objectives",
    Callback = function(Value)
    end,
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

-- ==========================
-- CONFIG & THEME MANAGER
-- ==========================

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("DarkestHours")
SaveManager:SetFolder("DarkestHours/main")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()