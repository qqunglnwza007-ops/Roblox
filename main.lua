-- ==============================================================================
-- 👑 MACRO SYSTEM ARCHITECTURE (PHASE 1 & 2: FULLY INTEGRATED & FIXED)
-- ==============================================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer -- [FIXED 1] เพิ่มตัวแปร LocalPlayer

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- ==========================================
-- 📂 1. MACRO FILE SYSTEM (ระบบจัดการไฟล์)
-- ==========================================
local MacroFS = {
    FolderName = "TD_MasterMacros",
    Extension = ".json"
}

if isfolder and not isfolder(MacroFS.FolderName) then
    makefolder(MacroFS.FolderName)
end

function MacroFS.GetMacroFiles()
    local files = {"None"}
    if listfiles then
        local success, result = pcall(function() return listfiles(MacroFS.FolderName) end)
        if success and result then
            for _, path in ipairs(result) do
                local fileName = string.match(path, "([^/\\]+)%.json$")
                if fileName then 
                    table.insert(files, fileName) 
                end
            end
        end
    end
    return #files > 1 and files or {"None"}
end

function MacroFS.CreateEmptyMacro(name)
    if name == "" or name == "None" then return false end
    local path = MacroFS.FolderName .. "/" .. name .. MacroFS.Extension
    local emptyData = HttpService:JSONEncode({ Info = "Created via Master Script", Actions = {} })
    if writefile then
        writefile(path, emptyData)
        return true
    end
    return false
end

function MacroFS.DeleteMacro(name)
    if name == "" or name == "None" then return false end
    local path = MacroFS.FolderName .. "/" .. name .. MacroFS.Extension
    if isfile and isfile(path) and delfile then
        delfile(path)
        return true
    end
    return false
end

-- ==========================================
-- 🧠 2. STATE MANAGEMENT (ระบบจดจำสถานะ)
-- ==========================================
local MacroState = {
    CurrentFile = "None",
    Status = "Idle ⚪",
    CurrentWave = 0,
    InGameTime = 0,
    ActionCount = 0
}

-- ==========================================
-- 🖥️ 3. BUILDING THE UI (สร้างหน้าต่าง Fluent)
-- ==========================================
local Window = Fluent:CreateWindow({
    Title = "AutoPlay Hub Pro",
    SubTitle = "Macro Master Edition",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 500),
    Acrylic = true, 
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = { Macro = Window:AddTab({ Title = "Macro", Icon = "play" }) }
Window:SelectTab(1)

-- [ Section 1: Status ]
Tabs.Macro:AddSection("Status")
local StatusDisplay = Tabs.Macro:AddParagraph({
    Title = "ℹ️ Current Status",
    Content = string.format("File: %s\nStatus: %s\nWave: %d\nIn-Game Time: %d\nActions: %d", MacroState.CurrentFile, MacroState.Status, MacroState.CurrentWave, MacroState.InGameTime, MacroState.ActionCount)
})

local function UpdateUIStatus(newState, newFile, newWave, newTime, newActions)
    MacroState.Status = newState or MacroState.Status
    MacroState.CurrentFile = newFile or MacroState.CurrentFile
    MacroState.CurrentWave = newWave or MacroState.CurrentWave
    MacroState.InGameTime = newTime or MacroState.InGameTime
    MacroState.ActionCount = newActions or MacroState.ActionCount
    StatusDisplay:SetDesc(string.format("File: %s\nStatus: %s\nWave: %d\nIn-Game Time: %ds\nActions: %d", MacroState.CurrentFile, MacroState.Status, MacroState.CurrentWave, MacroState.InGameTime, MacroState.ActionCount))
end

-- [ Section 2: File Management ]
Tabs.Macro:AddSection("File Management")
local NewMacroInput = Tabs.Macro:AddInput("NewMacroName", { Title = "New Macro Name", Placeholder = "Enter Text...", Finished = false })
local MacroDropdown

Tabs.Macro:AddButton({
    Title = "➕ Create & Select File",
    Callback = function()
        local fileName = NewMacroInput.Value
        if fileName and fileName ~= "" then
            if MacroFS.CreateEmptyMacro(fileName) then
                Fluent:Notify({ Title = "Success", Content = "สร้างไฟล์ " .. fileName .. " สำเร็จ!", Duration = 3 })
                MacroDropdown:SetValues(MacroFS.GetMacroFiles())
                MacroDropdown:SetValue(fileName)
                UpdateUIStatus(nil, fileName, nil, nil, 0)
            else
                Fluent:Notify({ Title = "Error", Content = "สร้างไฟล์ไม่สำเร็จ", Duration = 3 })
            end
        end
    end
})

MacroDropdown = Tabs.Macro:AddDropdown("SelectMacroFile", {
    Title = "📂 Select / Load Macro File",
    Values = MacroFS.GetMacroFiles(),
    Multi = false,
    Default = 1,
})

MacroDropdown:OnChanged(function(Value)
    UpdateUIStatus(nil, Value, nil, nil, nil)
end)

Tabs.Macro:AddButton({
    Title = "🔄 Refresh List",
    Callback = function()
        MacroDropdown:SetValues(MacroFS.GetMacroFiles())
        Fluent:Notify({ Title = "Refreshed", Content = "อัปเดตรายชื่อไฟล์แล้ว", Duration = 2 })
    end
})

Tabs.Macro:AddButton({
    Title = "🗑️ Delete Selected File",
    Callback = function()
        local selectedFile = MacroDropdown.Value
        if selectedFile ~= "None" then
            if MacroFS.DeleteMacro(selectedFile) then
                Fluent:Notify({ Title = "Deleted", Content = "ลบไฟล์ " .. selectedFile .. " สำเร็จ!", Duration = 3 })
                MacroDropdown:SetValues(MacroFS.GetMacroFiles())
                MacroDropdown:SetValue("None")
                UpdateUIStatus(nil, "None", nil, nil, 0)
            else
                Fluent:Notify({ Title = "Error", Content = "ลบไฟล์ไม่สำเร็จ", Duration = 3 })
            end
        end
    end
})

-- [ Section 3: Controls ]
Tabs.Macro:AddSection("Controls")
local PlaybackMode = Tabs.Macro:AddDropdown("PlaybackMode", { Title = "⚙️ Playback Mode", Values = {"Strict Time", "Money + Time", "Action Based"}, Multi = false, Default = 2 })

-- ตัวแปรเก็บข้อมูลมาโครที่กำลังอัด (ย้ายขึ้นมาให้ปุ่มรู้จัก)
local RecordedActions = {}
local RecordingStartTime = 0

Tabs.Macro:AddButton({ 
    Title = "🔴 Start Recording", 
    Callback = function()
        if MacroState.CurrentFile == "None" then 
            Fluent:Notify({ Title = "Warning", Content = "โปรดเลือกไฟล์หรือสร้างไฟล์ใหม่ก่อนกดอัด!", Duration = 3 }) 
            return 
        end
        
        RecordedActions = {}
        RecordingStartTime = tick()
        UpdateUIStatus("Recording 🔴", nil, 0, 0, 0)
        Fluent:Notify({ Title = "Recording...", Content = "เริ่มจับตาดูการกระทำของคุณแล้ว!", Duration = 2 })
    end
})

Tabs.Macro:AddButton({ 
    Title = "⏹️ Stop Recording & Auto-Save", 
    Callback = function()
        if MacroState.Status == "Recording 🔴" then
            UpdateUIStatus("Idle ⚪")
            
            local dataToSave = {
                Info = "Recorded by Master Macro System",
                TotalActions = #RecordedActions,
                Actions = RecordedActions
            }
            
            local jsonData = HttpService:JSONEncode(dataToSave)
            local path = MacroFS.FolderName .. "/" .. MacroState.CurrentFile .. MacroFS.Extension
            
            if writefile then
                local success, err = pcall(function() writefile(path, jsonData) end)
                if success then
                    Fluent:Notify({ Title = "Auto-Saved!", Content = string.format("บันทึกสำเร็จ! เก็บมาโครไว้ %d รายการ", #RecordedActions), Duration = 4 })
                else
                    Fluent:Notify({ Title = "Save Error", Content = "เซฟไฟล์ไม่สำเร็จ: " .. tostring(err), Duration = 3 })
                end
            else
                Fluent:Notify({ Title = "Error", Content = "ตัวรันไม่รองรับคำสั่ง writefile", Duration = 3 })
            end
        end
    end
})

local AutoPlayMacro = Tabs.Macro:AddToggle("AutoPlayMacro", { Title = "🟢 Auto Play Selected Macro (Looping)", Default = false })
AutoPlayMacro:OnChanged(function(Value)
    if Value then
        if MacroState.CurrentFile == "None" then AutoPlayMacro:SetValue(false) return end
        UpdateUIStatus("Playing (Loop) 🟢")
    else
        if MacroState.Status == "Playing (Loop) 🟢" then UpdateUIStatus("Idle ⚪") end
    end
end)

Tabs.Macro:AddButton({ Title = "▶️ Play Macro (Run Once)", Callback = function()
    if MacroState.CurrentFile == "None" then return end
    UpdateUIStatus("Playing (Once) ▶️")
end})

Tabs.Macro:AddButton({ Title = "⏹️ Stop Macro", Callback = function()
    if string.find(MacroState.Status, "Playing") then
        UpdateUIStatus("Idle ⚪")
        AutoPlayMacro:SetValue(false)
    end
end})

-- ==============================================================================
-- 🕵️ PHASE 2: METATABLE HOOKING (ระบบดักจับคำสั่ง)
-- ==============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InputRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Input")
local ServerRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Server")

local function GetCurrentWave()
    pcall(function()
        local waveTextObj = LocalPlayer.PlayerGui.HUD.Wave
        local waveText = waveTextObj.Text 
        return tonumber(string.match(waveText, "(%d+)")) or 0
    end)
    return 0
end

local function GetTimeSinceRecording()
    if RecordingStartTime == 0 then return 0 end
    return math.floor(tick() - RecordingStartTime)
end

local function RecordAction(actionType, data)
    if MacroState.Status ~= "Recording 🔴" then return end

    local currentWave = GetCurrentWave()
    local timeInWave = GetTimeSinceRecording() 

    local actionEntry = {
        ActionType = actionType,
        Wave = currentWave,
        TimeInWave = timeInWave,
        Data = data
    }

    table.insert(RecordedActions, actionEntry)
    UpdateUIStatus(nil, nil, currentWave, timeInWave, #RecordedActions)
    print(string.format("[Macro Recorded] %s | Wave: %d | Time: %ds", actionType, currentWave, timeInWave))
end

local function ParsePrice(text)
    if type(text) ~= "string" then return 0 end
    local cleanText = string.gsub(text, "[$,]", "")
    local multiplier = 1
    local lowerText = string.lower(cleanText)
    
    if string.find(lowerText, "k") then
        multiplier = 1000
        lowerText = string.gsub(lowerText, "k", "")
    elseif string.find(lowerText, "m") then
        multiplier = 1000000
        lowerText = string.gsub(lowerText, "m", "")
    end
    
    return (tonumber(lowerText) or 0) * multiplier
end

local function GetUnitCostFromName(targetUnitName)
    local unitsFolder = LocalPlayer.PlayerGui:FindFirstChild("HUD") and LocalPlayer.PlayerGui.HUD:FindFirstChild("BottomFrame") and LocalPlayer.PlayerGui.HUD.BottomFrame:FindFirstChild("Unit")
    if not unitsFolder then return 0 end
    
    for _, slot in pairs(unitsFolder:GetChildren()) do
        local unitObj = slot:FindFirstChild("Unit")
        if unitObj and unitObj:IsA("StringValue") and unitObj.Value == targetUnitName then
            local costLabel = slot:FindFirstChild("ImageLabel") and slot.ImageLabel:FindFirstChild("TextLabel")
            if costLabel then
                return ParsePrice(costLabel.Text) 
            end
        end
    end
    return 0
end

local function GetUpgradeCostFromUI()
    local upgradeUI = LocalPlayer.PlayerGui:FindFirstChild("HUD") 
        and LocalPlayer.PlayerGui.HUD:FindFirstChild("UpgradeV2")
        and LocalPlayer.PlayerGui.HUD.UpgradeV2:FindFirstChild("Actions")
        and LocalPlayer.PlayerGui.HUD.UpgradeV2.Actions:FindFirstChild("Upgrade")
        and LocalPlayer.PlayerGui.HUD.UpgradeV2.Actions.Upgrade:FindFirstChild("Amount")
    
    if upgradeUI then
        return ParsePrice(upgradeUI.Text)
    end
    return 0
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if MacroState.Status == "Recording 🔴" and not checkcaller() then
        
        if method == "FireServer" and self == InputRemote then
            local commandType = args[1]
            if commandType == "Summon" then
                local summonData = args[2]
                
                -- [FIXED 3] เพิ่มการตรวจสอบ Type ของข้อมูลเพื่อความปลอดภัย
                if type(summonData) == "table" and summonData.cframe then
                    local cf = summonData.cframe
                    local cframeTable = {cf:components()} 

                    RecordAction("Summon", {
                        Unit = summonData.Unit,
                        Rotation = summonData.Rotation,
                        CFrameData = cframeTable, 
                        Cost = GetUnitCostFromName(summonData.Unit)
                    })
                end
            end
            
        elseif method == "InvokeServer" and self == ServerRemote then
             local commandType = args[1]
             
             if commandType == "Upgrade" then
                 local targetUnit = args[2] 
                 
                 if targetUnit and typeof(targetUnit) == "Instance" then
                     local currentLevel = 0
                     if targetUnit:FindFirstChild("UpgradeTag") then
                         currentLevel = targetUnit.UpgradeTag.Value
                     end
                     
                     RecordAction("Upgrade", {
                         UnitName = targetUnit.Name,
                         Level = currentLevel,
                         Position = {targetUnit:GetPivot().Position.X, targetUnit:GetPivot().Position.Y, targetUnit:GetPivot().Position.Z},
                         Cost = GetUpgradeCostFromUI()
                     })
                 end
                 
             elseif commandType == "Sell" then
                 local targetUnit = args[2]
                 if targetUnit and typeof(targetUnit) == "Instance" then
                     RecordAction("Sell", {
                         UnitName = targetUnit.Name,
                         Position = {targetUnit:GetPivot().Position.X, targetUnit:GetPivot().Position.Y, targetUnit:GetPivot().Position.Z},
                         Cost = 0 
                     })
                 end
             end
        end
    end -- [FIXED 2] เพิ่ม end ปิดบล็อกตรวจสอบสเตตัสให้ถูกต้อง

    return oldNamecall(self, ...)
end)
