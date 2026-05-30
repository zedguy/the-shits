local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

if not getgenv().LinoriaCache then
    getgenv().LinoriaCache = {
        Library = loadstring(game:HttpGet(repo .. "Library.lua"))(),
        ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))(),
        SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
    }
end

if not getgenv().ESP then
    getgenv().ESP =
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/zedguy/the-shits/refs/heads/main/ESP.lua"
        ))()
else
    print("Loaded ESP library from getgenv")
end

local Library = getgenv().LinoriaCache.Library
local ThemeManager = getgenv().LinoriaCache.ThemeManager
local SaveManager = getgenv().LinoriaCache.SaveManager

local Options = Library.Options
local Toggles = Library.Toggles
local Window = Library:CreateWindow({
    Title = "Darkest Hours",
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

local function FormatName(str)
    return str:gsub("(%l)(%u)", "%1 %2")
end

local Player = Tabs.Main:AddLeftGroupbox("Player")
local Lists = Tabs.Utilities:AddRightGroupbox("Lists")
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")
local LeftTabBox = Tabs.Visuals:AddLeftTabbox("ESP")

local ESPTab = LeftTabBox:AddTab("ESP")
local SettingsTab = LeftTabBox:AddTab("Settings")

ESPTab:AddToggle("PlayerESP", {
    Text = "Players",
    Default = true,
    Callback = function(Value)
        ESP:ToggleCategory("Players", Value)
    end
})

ESPTab:AddToggle("EntityESP", {
    Text = "Entities",
    Default = true,
    Callback = function(Value)
        ESP:ToggleCategory("Entities", Value)
    end
})

ESPTab:AddToggle("ItemESP", {
    Text = "Items",
    Default = true,
    Callback = function(Value)
        ESP:ToggleCategory("Items", Value)
    end
})

SettingsTab:AddToggle("MasterESP", {
    Text = "Enable ESP",
    Default = true,
    Callback = function(Value)
        ESP:Toggle(Value)
    end
})

SettingsTab:AddToggle("HighlightESP", {
    Text = "Highlights",
    Default = true,
    Callback = function(Value)
        ESP:SetSetting("Highlight", Value)
    end
})

SettingsTab:AddToggle("TextESP", {
    Text = "Text Labels",
    Default = true,
    Callback = function(Value)
        ESP:SetSetting("Text", Value)
    end
})

SettingsTab:AddToggle("TracerESP", {
    Text = "Tracers",
    Default = false,
    Callback = function(Value)
        ESP:SetSetting("Tracer", Value)
    end
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