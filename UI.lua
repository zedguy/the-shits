local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

if not getgenv().LinoriaCache then
    getgenv().LinoriaCache = {
        Library = loadstring(game:HttpGet(repo .. "Library.lua"))(),
        ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))(),
        SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
    }
end

local Library = getgenv().LinoriaCache.Library
local ThemeManager = getgenv().LinoriaCache.ThemeManager
local SaveManager = getgenv().LinoriaCache.SaveManager

local Options = Library.Options
local Toggles = Library.Toggles
local Window = Library:CreateWindow({
    Title = "Darkest Hours Menu",
    Center = true,
    AutoShow = true,
    ShowCustomCursor = true,
})
local Tabs = {
    Main = Window:AddTab("Main", "sword"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Visuals = Window:AddTab("Utilities", "wrench"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

local MainGroupBox = Tabs.Main:AddLeftGroupbox("Main")
local UtilityGroupBox = Tabs.Main:AddRightGroupbox("Utilities")

MainGroupBox:AddToggle("ESPToggle", {
    Text = "ESP",
    Default = false,
    Callback = function(Value)
    end,
})

MainGroupBox:AddToggle("ReviveToggle", {
    Text = "Auto-Revive",
    Default = false,
    Callback = function(Value)
    end,
})

MainGroupBox:AddToggle("ExitToggle", {
    Text = "Auto-Exit",
    Default = false,
    Callback = function(Value)
    end,
})

MainGroupBox:AddToggle("VoteToggle", {
    Text = "Spam Votes",
    Default = false,
    Callback = function(Value)
    end,
})

UtilityGroupBox:AddToggle("TrackerToggle", {
    Text = "Show Entity Overlay",
    Default = true,
    Callback = function(Value)
    end,
})

UtilityGroupBox:AddDivider()

UtilityGroupBox:AddButton({
    Text = "Print Spawned Entities",
    Func = function()
    end,
})

UtilityGroupBox:AddButton({
    Text = "Force Revive All",
    Func = function()
    end,
})

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")

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