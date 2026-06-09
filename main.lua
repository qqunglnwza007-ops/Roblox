local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "AutoPlay Hub",
    SubTitle = "Tower Defense",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true, 
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- ==========================================
-- 1. สร้าง Tabs ทั้งหมด
-- ==========================================
local Tabs = {
    Ingame = Window:AddTab({ Title = "Ingame", Icon = "gamepad-2" }),
    Macro = Window:AddTab({ Title = "Macro", Icon = "play" }),
    Summon = Window:AddTab({ Title = "Summon", Icon = "sparkles" }),
    Raid = Window:AddTab({ Title = "Raid", Icon = "swords" }),
    Automation = Window:AddTab({ Title = "Automation", Icon = "cpu" }),
    Webhook = Window:AddTab({ Title = "Webhook", Icon = "bell" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
    Party = Window:AddTab({ Title = "Party", Icon = "users" }),
    Tower = Window:AddTab({ Title = "Tower", Icon = "castle" }),
    AutoPlace = Window:AddTab({ Title = "Auto Place", Icon = "map-pin" })
}

-- ==========================================
-- [แท็บ Ingame]
-- ==========================================
Tabs.Ingame:AddSection("Main Options")

local SpeedMode = Tabs.Ingame:AddDropdown("SpeedMode", {
    Title = "Speed Mode",
    Values = {"1x", "2x", "3x", "4x"},
    Multi = false,
    Default = 2,
})

local EnableAutoGameSpeed = Tabs.Ingame:AddToggle("EnableAutoGameSpeed", { Title = "Enable Auto GameSpeed", Default = true })

local EndMatchMode = Tabs.Ingame:AddDropdown("EndMatchMode", {
    Title = "End Match Mode",
    Values = {"Auto Next", "Return to Lobby", "Stay in Game"},
    Multi = false,
    Default = 1,
})

Tabs.Ingame:AddSection("Auto Leave Match")
local EnablePullBackToLobby = Tabs.Ingame:AddToggle("EnablePullBackToLobby", { Title = "Enable Pull Back to Lobby", Default = false })
local AutoLeaveWave = Tabs.Ingame:AddInput("AutoLeaveWave", { Title = "Auto Leave Game at Wave", Default = "50", Numeric = true, Finished = false })

Tabs.Ingame:AddSection("Match Progression")
local AutoSkipWave = Tabs.Ingame:AddToggle("AutoSkipWave", { Title = "Auto Skip Wave (Vote Skip)", Default = true })
local EnableEndMatchAutomation = Tabs.Ingame:AddToggle("EnableEndMatchAutomation", { Title = "Enable End Match Automation", Default = true })

Tabs.Ingame:AddSection("Vote Mode")
local AutoVoteMode = Tabs.Ingame:AddDropdown("AutoVoteMode", { Title = "Auto Vote Mode", Values = {"Normal", "Hard", "Extreme"}, Multi = false, Default = 1 })
local EnableAutoVote = Tabs.Ingame:AddToggle("EnableAutoVote", { Title = "Enable Auto Vote", Default = true })

-- ==========================================
-- [แท็บ Macro] ที่เพิ่มเข้ามาใหม่
-- ==========================================
Tabs.Macro:AddSection("Status")

local MacroStatus = Tabs.Macro:AddParagraph({
    Title = "ℹ️ Current Status",
    Content = "File: None\nStatus: Idle ⚪\nActions: 0\nIn-Game Time: --"
})

Tabs.Macro:AddSection("File Management")

local NewMacroName = Tabs.Macro:AddInput("NewMacroName", {
    Title = "New Macro Name",
    Placeholder = "Enter Text...",
    Finished = false,
})

Tabs.Macro:AddButton({
    Title = "➕ Create & Select File",
    Callback = function()
        print("Create file clicked")
    end
})

local SelectMacroFile = Tabs.Macro:AddDropdown("SelectMacroFile", {
    Title = "📂 Select / Load Macro File",
    Values = {"File 1", "File 2", "File 3"}, -- ใส่ไฟล์จำลองไว้ก่อน
    Multi = false,
    Default = 1,
})

Tabs.Macro:AddButton({
    Title = "🔄 Refresh List",
    Callback = function()
        print("Refresh list clicked")
    end
})

Tabs.Macro:AddButton({
    Title = "🗑️ Delete Selected File",
    Callback = function()
        print("Delete clicked")
    end
})

Tabs.Macro:AddSection("Controls")

local PlaybackMode = Tabs.Macro:AddDropdown("PlaybackMode", {
    Title = "⚙️ Playback Mode",
    Values = {"Money + Time", "Time Only", "Action Based"},
    Multi = false,
    Default = 1,
})

Tabs.Macro:AddButton({
    Title = "🔴 Start Recording",
    Callback = function()
        print("Start Recording")
    end
})

Tabs.Macro:AddButton({
    Title = "⏹️ Stop Recording & Auto-Save",
    Callback = function()
        print("Stop Recording")
    end
})

local AutoPlayMacro = Tabs.Macro:AddToggle("AutoPlayMacro", { 
    Title = "🟢 Auto Play Selected Macro (Looping)", 
    Default = false 
})

Tabs.Macro:AddButton({
    Title = "▶️ Play Macro (Run Once)",
    Callback = function()
        print("Play Run Once")
    end
})

Tabs.Macro:AddButton({
    Title = "⏹️ Stop Macro",
    Callback = function()
        print("Stop Macro")
    end
})

-- ==========================================
-- [แท็บ Auto Place] เพิ่มเติมตามรูปที่ส่งมา
-- ==========================================
Tabs.AutoPlace:AddSection("Status")

local AutoPlaceStatus = Tabs.AutoPlace:AddParagraph({
    Title = "Status",
    Content = "Status: Idle ⚪"
})

local AutoPlayFull = Tabs.AutoPlace:AddToggle("AutoPlayFull", {
    Title = "⚡ Auto Play Full",
    Default = false 
})

Tabs.AutoPlace:AddSection("⬆️ Auto Upgrade")

local EnableAutoUpgrade = Tabs.AutoPlace:AddToggle("EnableAutoUpgrade", {
    Title = "✅ Enable Auto Upgrade",
    Default = false
})
-- ==========================================
-- ระบบ Save Config (ในแท็บ Settings)
-- ==========================================
InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder("MyTDHub")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
SaveManager:SetFolder("MyTDHub/configs")
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()
