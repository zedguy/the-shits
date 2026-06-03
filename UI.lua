local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================================
-- 1. FRAMEWORK INTERACTION SETUP
-- ============================================================================
local SharedModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"):WaitForChild("SharedCharacter")
local SharedCharacter = require(SharedModule)

-- Cache references to folders
local entitiesFolder = Workspace:WaitForChild("Entities")
local charactersFolder = Workspace:WaitForChild("Characters"):WaitForChild("Player")

-- State Variables for Heartbeat logic
local states = {
    InfiniteStamina = true,
    SpeedBoost = true,
    SpeedLevel = 3,
    AutoRevive = false,
    AutoExit = false,
    SpamVotes = false,
    
    -- Cache configuration for Framework binding
    SharedCharObj = nil,
    SpeedStackName = "CLIENT_SPEED_OVERRIDE",
    SpeedConnection = nil,
    StaminaConnection = nil
}

-- ============================================================================
-- 2. CORE SYSTEM LOGIC (STAMINA & SPEED MULTIPLIERS)
-- ============================================================================
local function safeGetSharedObject()
    local character = LocalPlayer.Character
    if not character then return nil end
    
    local success, obj = pcall(function()
        return SharedCharacter.getObject(character) or (SharedCharacter.new and SharedCharacter.new(character))
    end)
    
    if success and obj then
        states.SharedCharObj = obj
        return obj
    end
    return nil
end

-- Stamina Management Loop
states.StaminaConnection = RunService.Heartbeat:Connect(function()
    if not states.InfiniteStamina then return end
    local obj = states.SharedCharObj or safeGetSharedObject()
    if obj then
        pcall(function()
            obj:SetStaminaActivity(0)
            obj:RegainStamina(10000, 1, true)
        end)
    end
end)

-- Speed Modifier Loop
states.SpeedConnection = RunService.Heartbeat:Connect(function()
    if not states.SpeedBoost then return end
    local obj = states.SharedCharObj or safeGetSharedObject()
    if obj and obj.Stacks and obj.Stacks.SpeedStack then
        pcall(function()
            local speedStack = obj.Stacks.SpeedStack
            speedStack:RemoveModifier(states.SpeedStackName)
            
            speedStack:AddModifier(states.SpeedStackName, function(modifierData)
                modifierData.Output = (modifierData.Output or 1) * (1 + states.SpeedLevel / 3)
                return false
            end, 5, true)
            
            if obj.UpdateWalkSpeed then
                obj:UpdateWalkSpeed()
            end
        end)
    end
end)

-- Handle automated refreshing whenever character respawns
LocalPlayer.CharacterAdded:Connect(function(character)
    states.SharedCharObj = nil
    task.spawn(function()
        repeat
            task.wait()
            safeGetSharedObject()
        until states.SharedCharObj and states.SharedCharObj.Stacks and states.SharedCharObj.Stacks.SpeedStack
    end)
end)
if LocalPlayer.Character then safeGetSharedObject() end

-- ============================================================================
-- 3. TELEPORTATION & MOVEMENT UTILITIES (With oldpos Integration)
-- ============================================================================
local function getLobbySpawn()
    -- Lobby spawn is placed directly inside a model, not a folder named spawns
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name:lower():match("lobby") then
            for _, descendant in ipairs(obj:GetDescendants()) do
                if descendant:IsA("SpawnLocation") or descendant:IsA("BasePart") and descendant.Name:lower():match("spawn") then
                    return descendant
                end
            end
        end
    end
    -- Fallback directly in Workspace
    return Workspace:FindFirstChild("LobbySpawn") or Workspace:FindFirstChildOfClass("SpawnLocation")
end

local function getRandomMapSpawn()
    -- Map spawns reside within a dedicated "Spawns" folder structural system
    for _, folder in ipairs(Workspace:GetDescendants()) do
        if folder:IsA("Folder") and folder.Name == "Spawns" then
            local children = folder:GetChildren()
            if #children > 0 then
                return children[math.random(1, #children)]
            end
        end
    end
    return nil
end

local function teleportToLocation(targetPart)
    local char = LocalPlayer.Character
    if char and char.PrimaryPart and targetPart then
        local oldpos = char.PrimaryPart.CFrame
        char:PivotTo(targetPart.CFrame * CFrame.new(0, 3, 0))
        return oldpos
    end
    return nil
end

-- ============================================================================
-- 4. AUTOMATION LOOPS (Revive, Exit, Vote-Spam)
-- ============================================================================
local isLegacyChat = game.TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService
local function chatMessage(str)
    str = tostring(str)
    if not isLegacyChat then
        local channel = game.TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if channel then channel:SendAsync(str) end
    else
        ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(str, "All")
    end
end

local function performRevive(prompt)
    local char = LocalPlayer.Character
    if char and char.PrimaryPart and prompt.Parent then
        local oldpos = char.PrimaryPart.CFrame -- Preserving Position via oldpos
        char:PivotTo(prompt.Parent.CFrame * CFrame.new(0, -3, 0))
        task.wait(0.55)
        
        if keypress then keypress("0x45") end
        prompt.HoldDuration = 0
        if fireproximityprompt then fireproximityprompt(prompt) end
        task.wait(0.5)
        if keyrelease then keyrelease("0x45") end
        
        task.wait()
        char:PivotTo(oldpos) -- Return to oldpos securely
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

-- Unified Heartbeat Automation Routine
RunService.Heartbeat:Connect(function()
    -- Auto Exit Sequence
    if states.AutoExit and Workspace:FindFirstChild("Client") and Workspace.Client:FindFirstChild("ExitPoint") then
        local char = LocalPlayer.Character
        if char and char.PrimaryPart then
            char:PivotTo(Workspace.Client.ExitPoint.CFrame)
        end
    end
    
    -- Map Vote Spam Sequence
    local mapVoteModel = Workspace:FindFirstChild("Client") 
        and Workspace.Client:FindFirstChild("MapVoteModel") 
        and Workspace.Client.MapVoteModel:FindFirstChild("VoteScreenModels")

    if mapVoteModel and states.SpamVotes then
        for i = 1, 4 do
            local screenName = "Screen" .. i
            local screenModel = mapVoteModel:FindFirstChild(screenName)
            local insetPart = screenModel and screenModel:FindFirstChild("Inset")

            if insetPart and insetPart:IsA("BasePart") then
                local screenPos, onScreen = Camera:WorldToScreenPoint(insetPart.Position)
                if onScreen and mousemoveabs and mouse1click then
                    mousemoveabs(screenPos.X, screenPos.Y)
                    mouse1click()
                end
            end
        end
    end
end)

charactersFolder.DescendantAdded:Connect(function(v)
    if v.Name == "RevivePrompt" and states.AutoRevive and v:IsA("ProximityPrompt") then
        task.wait(0.5)
        performRevive(v)
    end
end)

-- ============================================================================
-- 5. CREATING THE LINORIA-STYLE NATIVE OVERLAY PANEL
-- ============================================================================
local OverlayGui = Instance.new("ScreenGui")
OverlayGui.Name = "DarkestHours_OverlayHUD"
OverlayGui.ResetOnSpawn = false
OverlayGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local OverlayFrame = Instance.new("Frame")
OverlayFrame.Size = UDim2.new(0, 240, 0, 280)
OverlayFrame.Position = UDim2.new(1, -260, 0, 50)
OverlayFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
OverlayFrame.BorderColor3 = Color3.fromRGB(40, 40, 40)
OverlayFrame.BorderSizePixel = 1
OverlayFrame.Active = true
OverlayFrame.Draggable = true
OverlayFrame.Parent = OverlayGui

local OverlayCorner = Instance.new("UICorner")
OverlayCorner.CornerRadius = UDim.new(0, 4)
OverlayCorner.Parent = OverlayFrame

local OverlayStroke = Instance.new("UIStroke")
OverlayStroke.Color = Color3.fromRGB(40, 40, 40)
OverlayStroke.Thickness = 1
OverlayStroke.Parent = OverlayFrame

local OverlayLayout = Instance.new("UIListLayout")
OverlayLayout.Padding = UDim.new(0, 6)
OverlayLayout.SortOrder = Enum.SortOrder.LayoutOrder
OverlayLayout.Parent = OverlayFrame

local OverlayPadding = Instance.new("UIPadding")
OverlayPadding.PaddingTop = UDim.new(0, 10)
OverlayPadding.PaddingBottom = UDim.new(0, 10)
OverlayPadding.PaddingLeft = UDim.new(0, 12)
OverlayPadding.PaddingRight = UDim.new(0, 12)
OverlayPadding.Parent = OverlayFrame

local function createOverlayLabel(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.SourceSansSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = text
    lbl.LayoutOrder = order
    lbl.Parent = OverlayFrame
    return lbl
end

-- Construct Overlay Components
local timerHUD = createOverlayLabel("Timer: N/A", 1)
local roundHUD = createOverlayLabel("Roundtype: Intermission", 2)

-- Custom Divider Line Match Linoria Profiles
local overlayDivider = Instance.new("Frame")
overlayDivider.Size = UDim2.new(1, 0, 0, 1)
overlayDivider.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
overlayDivider.BorderSizePixel = 0
overlayDivider.LayoutOrder = 3
overlayDivider.Parent = OverlayFrame

local entityListTitleHUD = createOverlayLabel("Entity List:", 4)
entityListTitleHUD.TextColor3 = Color3.fromRGB(160, 160, 160)

local entityScrollingFrame = Instance.new("ScrollingFrame")
entityScrollingFrame.Size = UDim2.new(1, 0, 1, -70)
entityScrollingFrame.BackgroundTransparency = 1
entityScrollingFrame.BorderSizePixel = 0
entityScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
entityScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
entityScrollingFrame.ScrollBarThickness = 2
entityScrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
entityScrollingFrame.LayoutOrder = 5
entityScrollingFrame.Parent = OverlayFrame

local entityListHUD = Instance.new("TextLabel")
entityListHUD.Size = UDim2.new(1, 0, 0, 0)
entityListHUD.AutomaticSize = Enum.AutomaticSize.Y
entityListHUD.BackgroundTransparency = 1
entityListHUD.TextColor3 = Color3.fromRGB(255, 100, 100)
entityListHUD.TextSize = 13
entityListHUD.Font = Enum.Font.SourceSans
entityListHUD.TextXAlignment = Enum.TextXAlignment.Left
entityListHUD.TextYAlignment = Enum.TextYAlignment.Top
entityListHUD.TextWrapped = true
entityListHUD.Text = "None"
entityListHUD.Parent = entityScrollingFrame

-- Dynamic Overlay Data Controller
RunService.Heartbeat:Connect(function()
    local clientFolder = Workspace:FindFirstChild("Client")
    local extractedTimer = "N/A"
    local extractedRound = "Intermission"
    
    if clientFolder then
        local timerObj = clientFolder:FindFirstChild("Timer") or clientFolder:GetAttribute("Timer")
        local roundObj = clientFolder:FindFirstChild("RoundType") or clientFolder:FindFirstChild("Round") or clientFolder:GetAttribute("RoundType")
        
        if typeof(timerObj) == "Instance" and timerObj:IsA("ValueBase") then extractedTimer = tostring(timerObj.Value)
        elseif timerObj then extractedTimer = tostring(timerObj) end
        
        if typeof(roundObj) == "Instance" and roundObj:IsA("ValueBase") then extractedRound = tostring(roundObj.Value)
        elseif roundObj then extractedRound = tostring(roundObj) end
    end
    
    timerHUD.Text = "Timer: " .. extractedTimer
    roundHUD.Text = "Roundtype: " .. extractedRound
    
    -- Dynamic Real-time Entities Scanner
    local activeEntities = {}
    for _, entity in ipairs(entitiesFolder:GetChildren()) do
        if entity:IsA("Model") then
            table.insert(activeEntities, "• " .. entity.Name)
        end
    end
    
    if #activeEntities > 0 then
        entityListHUD.Text = table.concat(activeEntities, "\n")
    else
        entityListHUD.Text = "No entities present"
    end
end)

-- ============================================================================
-- 6. LINORIA INTERFACE GENERATION & INTEGRATION
-- ============================================================================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

if not getgenv().LinoriaCache then
    getgenv().LinoriaCache = {
        Library = loadstring(game:HttpGet(repo .. "Library.lua"))(),
        ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))(),
        SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
    }
end

if not getgenv().ESP then
    getgenv().ESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/zedguy/the-shits/refs/heads/main/ESP.lua"))()
else
    print("Loaded ESP library from getgenv")
end

local Library = getgenv().LinoriaCache.Library
local ThemeManager = getgenv().LinoriaCache.ThemeManager
local SaveManager = getgenv().LinoriaCache.SaveManager
local ESP = getgenv().ESP

ESP:CreateCategory("Players", { Color = Color3.fromRGB(0, 255, 0), Text = true })
ESP:CreateCategory("Entities", { Color = Color3.fromRGB(255, 80, 80), Text = true })
ESP:CreateCategory("Items", { Color = Color3.fromRGB(255, 255, 0), Text = true })

local Options = Library.Options
local Toggles = Library.Toggles
local Window = Library:CreateWindow({
    Title = "Darkest Hours | Premium Suite",
    Center = true,
    AutoShow = true,
    ShowCustomCursor = true,
    Icon = 95816097006870,
})

local Tabs = {
    Main = Window:AddTab("Main", "sword"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Utilities = Window:AddTab("Utilities", "wrench"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

-- Populating Main Configuration Columns
local PlayerGroup = Tabs.Main:AddLeftGroupbox("Player Modifiers")
local AutomationGroup = Tabs.Main:AddRightGroupbox("Automation Modifiers")
local ListsGroup = Tabs.Utilities:AddRightGroupbox("Diagnostics")
local LeftTabBox = Tabs.Visuals:AddLeftTabbox("ESP")

local ESPTab = LeftTabBox:AddTab("ESP")
local SettingsTab = LeftTabBox:AddTab("Settings")

-- Player Column Options
PlayerGroup:AddToggle("InfiniteStaminaToggle", {
    Text = "Infinite Stamina",
    Default = true,
    Callback = function(Value) states.InfiniteStamina = Value end
})

PlayerGroup:AddToggle("SpeedBoostToggle", {
    Text = "Speed Multiplier Override",
    Default = true,
    Callback = function(Value) 
        states.SpeedBoost = Value 
        if not Value and states.SharedCharObj and states.SharedCharObj.Stacks and states.SharedCharObj.Stacks.SpeedStack then
            pcall(function()
                states.SharedCharObj.Stacks.SpeedStack:RemoveModifier(states.SpeedStackName)
                if states.SharedCharObj.UpdateWalkSpeed then states.SharedCharObj:UpdateWalkSpeed() end
            end)
        end
    end
})

PlayerGroup:AddSlider("SpeedLevelSlider", {
    Text = "Speed Multiplier Level",
    Default = 3,
    Min = 1,
    Max = 15,
    Rounding = 0,
    Compact = false,
    Callback = function(Value) states.SpeedLevel = Value end
})

PlayerGroup:AddButton("Teleport to Lobby", function()
    local lobbyPart = getLobbySpawn()
    if lobbyPart then
        teleportToLocation(lobbyPart)
    else
        Library:Notify("Failed to automatically detect a direct Lobby spawn part.", 3)
    end
end)

PlayerGroup:AddButton("Teleport to Random Map Spawn", function()
    local mapSpawnPart = getRandomMapSpawn()
    if mapSpawnPart then
        teleportToLocation(mapSpawnPart)
    else
        Library:Notify("Failed to find map structure or Spawns folder container.", 3)
    end
end)

-- Automation Column Options
AutomationGroup:AddToggle("AutoReviveToggle", {
    Text = "Auto-Revive Downed Players [H]",
    Default = false,
    Callback = function(Value) 
        states.AutoRevive = Value 
        if Value then task.spawn(reviveAllDowned) end
    end
})

AutomationGroup:AddButton("Force Revive All Sweeper", function()
    task.spawn(reviveAllDowned)
end)

AutomationGroup:AddToggle("AutoExitToggle", {
    Text = "Auto-Exit Teleporter Loop [M]",
    Default = false,
    Callback = function(Value) states.AutoExit = Value end
})

AutomationGroup:AddToggle("VoteSpamToggle", {
    Text = "Spam Map Selection Votes [B]",
    Default = false,
    Callback = function(Value) states.SpamVotes = Value end
})

-- Visual Toggles Profile
ESPTab:AddToggle("PlayerESP", { Text = "Players", Default = true, Callback = function(Value) ESP:ToggleCategory("Players", Value) end })
ESPTab:AddToggle("EntityESP", { Text = "Entities", Default = true, Callback = function(Value) ESP:ToggleCategory("Entities", Value) end })
ESPTab:AddToggle("ItemESP", { Text = "Items", Default = true, Callback = function(Value) ESP:ToggleCategory("Items", Value) end })

SettingsTab:AddToggle("MasterESP", { Text = "Enable ESP", Default = true, Callback = function(Value) ESP:Toggle(Value) end })
SettingsTab:AddToggle("HighlightESP", { Text = "Highlights", Default = true, Callback = function(Value) ESP:SetSetting("Highlight", Value) end })
SettingsTab:AddToggle("TextESP", { Text = "Text Labels", Default = true, Callback = function(Value) ESP:SetSetting("Text", Value) end })
SettingsTab:AddToggle("TracerESP", { Text = "Tracers", Default = false, Callback = function(Value) ESP:SetSetting("Tracer", Value) end })

-- Diagnostics Column Options
ListsGroup:AddButton("Print Spawned Entities", function()
    local entitiesFound = entitiesFolder:GetChildren()
    if #entitiesFound == 0 then
        Library:Notify("Zero active instances found inside entity system container.", 3)
    else
        for _, entity in ipairs(entitiesFound) do
            chatMessage(entity.Name .. " has spawned currently.")
            task.wait(0.2)
        end
    end
end)

-- Window / Interface Keybind Assignments
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu Settings")
MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = false,
    Text = "Open Keybind Configuration Overlay",
    Callback = function(Value) Library.KeybindFrame.Visible = Value end,
})

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })

MenuGroup:AddButton("Unload Suite", function()
    if states.SpeedConnection then states.SpeedConnection:Disconnect() end
    if states.StaminaConnection then states.StaminaConnection:Disconnect() end
    OverlayGui:Destroy()
    Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

-- Global Automation Managers Execution
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("DarkestHours")
SaveManager:SetFolder("DarkestHours/main")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()

-- Manual Input Fallbacks Mapping
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.H then
        local targetState = not states.AutoRevive
        local toggle = Toggles.AutoReviveToggle
        if toggle then toggle:SetValue(targetState) else states.AutoRevive = targetState end
    elseif input.KeyCode == Enum.KeyCode.M then
        local targetState = not states.AutoExit
        local toggle = Toggles.AutoExitToggle
        if toggle then toggle:SetValue(targetState) else states.AutoExit = targetState end
    elseif input.KeyCode == Enum.KeyCode.B then
        local targetState = not states.SpamVotes
        local toggle = Toggles.VoteSpamToggle
        if toggle then toggle:SetValue(targetState) else states.SpamVotes = targetState end
    end
end)