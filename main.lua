-- ==============================================================================
-- 👑 ULTIMATE MACRO SYSTEM (V4) : THE MASTERPIECE
-- Architecture: Safe Action Queue + Smart Playback Engine + Money Tracking
-- ==============================================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")

local InputRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Input")
local ServerRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Server")

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- ==========================================
-- ⚙️ 1. CORE STATE & VARIABLES
-- ==========================================
local MacroState = {
    CurrentFile = "None",
    Status = "Idle ⚪",
    CurrentWave = 0,
    InGameTime = 0,
    ActionCount = 0
}

local RecordedActions = {}
local RecordingStartTime = 0
local ActionQueue = {}

local Playback = {
    Running = false,
    Token = 0,
    LastError = nil,
    PositionTolerance = 4, -- ระยะคลาดเคลื่อนที่ยอมรับได้ตอนหาตัวละคร (สตั๊ด)
}

-- ==========================================
-- 📂 2. FILE SYSTEM (MacroFS)
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
                if fileName then table.insert(files, fileName) end
            end
        end
    end
    return #files > 1 and files or {"None"}
end

function MacroFS.CreateEmptyMacro(name)
    if name == "" or name == "None" then return false end
    local path = MacroFS.FolderName .. "/" .. name .. MacroFS.Extension
    local emptyData = HttpService:JSONEncode({ Info = "Master Macro File", Actions = {} })
    if writefile then writefile(path, emptyData) return true end
    return false
end

function MacroFS.DeleteMacro(name)
    if name == "" or name == "None" then return false end
    local path = MacroFS.FolderName .. "/" .. name .. MacroFS.Extension
    if isfile and isfile(path) and delfile then delfile(path) return true end
    return false
end

-- ==========================================
-- 🧮 3. UTILITY & PARSING FUNCTIONS
-- ==========================================
local function ParsePrice(value)
    if type(value) == "number" then return math.max(0, math.floor(value + 0.5)) end
    if type(value) ~= "string" then return 0 end

    local text = string.lower(value)
    text = text:gsub("[$,]", ""):gsub("%s+", "")

    local numberText, suffix = text:match("([%d%.]+)([kmbt]?)")
    local amount = tonumber(numberText)
    if not amount then return 0 end

    local multipliers = { k = 1000, m = 1000000, b = 1000000000, t = 1000000000000 }
    local multiplier = multipliers[suffix] or 1
    return math.max(0, math.floor((amount * multiplier) + 0.5))
end

local function ReadText(instance)
    if instance and (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then
        return instance.Text
    end
    return ""
end

local function GetCurrentWave()
    local ok, wave = pcall(function()
        local waveLabel = LocalPlayer.PlayerGui.HUD.Wave
        return tonumber(ReadText(waveLabel):match("(%d+)")) or 0
    end)
    return ok and wave or 0
end

local function GetCurrentCash()
    local ok, cash = pcall(function()
        local cashLabel = LocalPlayer.PlayerGui.HUD.BottomFrame.CurrencyList.Cash
        return ParsePrice(ReadText(cashLabel))
    end)
    return ok and cash or 0
end

local function GetTimeSinceRecording()
    if RecordingStartTime == 0 then return 0 end
    return math.max(0, tick() - RecordingStartTime)
end

-- 🛠️ [FIXED] ตัด cf:GetComponents() ทิ้ง ป้องกันบัคตัวรัน 100%
local function CFrameToTable(cf)
    if typeof(cf) ~= "CFrame" then return nil end
    return { cf.X, cf.Y, cf.Z } 
end

local function TableToCFrame(values)
    if type(values) ~= "table" or #values < 3 then return nil end
    return CFrame.new(values[1], values[2], values[3])
end

local function GetUnitCostFromName(targetUnitName)
    local unitsFolder = LocalPlayer.PlayerGui:FindFirstChild("HUD") and LocalPlayer.PlayerGui.HUD:FindFirstChild("BottomFrame") and LocalPlayer.PlayerGui.HUD.BottomFrame:FindFirstChild("Unit")
    if not unitsFolder then return 0 end
    
    for _, slot in ipairs(unitsFolder:GetChildren()) do
        local unitObj = slot:FindFirstChild("Unit")
        if unitObj and unitObj:IsA("StringValue") and unitObj.Value == targetUnitName then
            local costLabel = slot:FindFirstChild("ImageLabel") and slot.ImageLabel:FindFirstChild("TextLabel")
            return ParsePrice(ReadText(costLabel))
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
    
    return upgradeUI and ParsePrice(ReadText(upgradeUI)) or 0
end

local function GetUnitPosition(unitInstance)
    if typeof(unitInstance) ~= "Instance" then return nil end
    local ok, pivot = pcall(function() return unitInstance:GetPivot() end)
    if ok and typeof(pivot) == "CFrame" then return pivot.Position end
    if unitInstance:IsA("BasePart") then return unitInstance.Position end
    return nil
end

-- ==========================================
-- 🖥️ 4. UI CREATION & LOGIC
-- ==========================================
local Window = Fluent:CreateWindow({
    Title = "AutoPlay Hub Pro",
    SubTitle = "Ultimate Macro V4",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 500),
    Acrylic = true, 
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = { Macro = Window:AddTab({ Title = "Macro Engine", Icon = "play" }) }
Window:SelectTab(1)

-- [ Status Section ]
Tabs.Macro:AddSection("Status")
local StatusDisplay = Tabs.Macro:AddParagraph({
    Title = "ℹ️ Current Status",
    Content = "Loading..."
})

local function UpdateUIStatus(newState, newFile, newWave, newTime, newActions)
    MacroState.Status = newState or MacroState.Status
    MacroState.CurrentFile = newFile or MacroState.CurrentFile
    MacroState.CurrentWave = newWave or MacroState.CurrentWave
    MacroState.InGameTime = newTime or MacroState.InGameTime
    MacroState.ActionCount = newActions or MacroState.ActionCount
    StatusDisplay:SetDesc(string.format("File: %s\nStatus: %s\nWave: %d\nIn-Game Time: %ds\nActions: %d", MacroState.CurrentFile, MacroState.Status, MacroState.CurrentWave, MacroState.InGameTime, MacroState.ActionCount))
end
UpdateUIStatus()

-- [ File Management Section ]
Tabs.Macro:AddSection("File Management")
local NewMacroInput = Tabs.Macro:AddInput("NewMacroName", { Title = "New Macro Name", Placeholder = "Enter Text...", Finished = false })
local MacroDropdown

Tabs.Macro:AddButton({
    Title = "➕ Create & Select File",
    Callback = function()
        local fileName = NewMacroInput.Value
        if fileName ~= "" and MacroFS.CreateEmptyMacro(fileName) then
            Fluent:Notify({ Title = "Success", Content = "สร้างไฟล์มาโครสำเร็จ!", Duration = 3 })
            MacroDropdown:SetValues(MacroFS.GetMacroFiles())
            MacroDropdown:SetValue(fileName)
            UpdateUIStatus(nil, fileName, nil, nil, 0)
        end
    end
})

MacroDropdown = Tabs.Macro:AddDropdown("SelectMacroFile", { Title = "📂 Select / Load Macro File", Values = MacroFS.GetMacroFiles(), Multi = false, Default = 1 })
MacroDropdown:OnChanged(function(Value) UpdateUIStatus(nil, Value, nil, nil, nil) end)

Tabs.Macro:AddButton({
    Title = "🔄 Refresh List",
    Callback = function() MacroDropdown:SetValues(MacroFS.GetMacroFiles()) end
})

Tabs.Macro:AddButton({
    Title = "🗑️ Delete Selected File",
    Callback = function()
        local selectedFile = MacroDropdown.Value
        if selectedFile ~= "None" and MacroFS.DeleteMacro(selectedFile) then
            Fluent:Notify({ Title = "Deleted", Content = "ลบไฟล์มาโครสำเร็จ!", Duration = 3 })
            MacroDropdown:SetValues(MacroFS.GetMacroFiles())
            MacroDropdown:SetValue("None")
            UpdateUIStatus(nil, "None", nil, nil, 0)
        end
    end
})

-- ==========================================
-- 📼 5. PLAYBACK ENGINE (Logic & Replay)
-- ==========================================
local function RecordAction(actionType, data)
    if MacroState.Status ~= "Recording 🔴" then return end
    local currentWave = GetCurrentWave()
    local timestamp = GetTimeSinceRecording()

    local actionEntry = {
        ActionType = actionType,
        Wave = currentWave,
        TimeInWave = timestamp,
        Timestamp = timestamp,
        Cost = ParsePrice(data.Cost or 0),
        Data = data
    }
    table.insert(RecordedActions, actionEntry)
    UpdateUIStatus(nil, nil, currentWave, math.floor(timestamp), #RecordedActions)
    print(string.format("[Macro Recorded] %s | Cost: %d | Time: %.1fs", actionType, actionEntry.Cost, timestamp))
end

local function StopMacroPlayback()
    Playback.Token += 1
    Playback.Running = false
    UpdateUIStatus("Idle ⚪")
end

local function FindUnitForAction(data)
    local wantedName = data.UnitName or data.Unit
    local wantedPosition = data.Position and Vector3.new(data.Position[1], data.Position[2], data.Position[3])
    local bestUnit, bestDistance = nil, math.huge

    local unitFolder = workspace:FindFirstChild("Unit") or workspace
    for _, candidate in ipairs(unitFolder:GetDescendants()) do
        if (candidate:IsA("Model") or candidate:IsA("BasePart")) and candidate.Name == wantedName then
            if wantedPosition then
                local pos = GetUnitPosition(candidate)
                if pos then
                    local distance = (pos - wantedPosition).Magnitude
                    if distance < bestDistance and distance <= Playback.PositionTolerance then
                        bestDistance = distance
                        bestUnit = candidate
                    end
                end
            else
                return candidate
            end
        end
    end
    return bestUnit
end

local PlaybackMode = Tabs.Macro:AddDropdown("PlaybackMode", { Title = "⚙️ Playback Mode", Values = {"Strict Time", "Money + Time", "Action Based"}, Multi = false, Default = 2 })

local function WaitForActionReady(action, playbackStartTime, token)
    local mode = PlaybackMode.Value
    local targetTime = tonumber(action.Timestamp or action.TimeInWave) or 0
    local targetWave = tonumber(action.Wave) or 0
    local targetCost = ParsePrice(action.Cost)

    -- รอเวลา
    if mode == "Strict Time" or mode == "Money + Time" then
        while Playback.Running and Playback.Token == token and (tick() - playbackStartTime < targetTime) do task.wait(0.1) end
    end
    -- รอเวฟ
    if targetWave > 0 then
        while Playback.Running and Playback.Token == token and (GetCurrentWave() < targetWave) do task.wait(0.5) end
    end
    -- รอเงิน (สำคัญสุด)
    if mode == "Money + Time" and targetCost > 0 then
        while Playback.Running and Playback.Token == token and (GetCurrentCash() < targetCost) do task.wait(0.2) end
    end
    
    return Playback.Running and Playback.Token == token
end

local function PlayMacro(loopPlayback)
    if Playback.Running then StopMacroPlayback() task.wait(0.2) end
    local path = MacroFS.FolderName .. "/" .. MacroState.CurrentFile .. MacroFS.Extension
    
    if not isfile(path) then Fluent:Notify({ Title = "Error", Content = "หาไฟล์ไม่เจอ!", Duration = 3 }) return end
    local ok, result = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or not result.Actions then return end

    local actions = result.Actions
    Playback.Running = true
    Playback.Token += 1
    local token = Playback.Token

    task.spawn(function()
        repeat
            local playbackStartTime = tick()
            for index, action in ipairs(actions) do
                if Playback.Token ~= token or not Playback.Running then break end
                
                UpdateUIStatus(nil, nil, GetCurrentWave(), math.floor(tick() - playbackStartTime), index - 1)
                
                if WaitForActionReady(action, playbackStartTime, token) then
                    local actionType = action.ActionType
                    local data = action.Data
                    
                    if actionType == "Summon" then
                        local cf = TableToCFrame(data.CFrameData or data.CFrame)
                        if cf then
                            pcall(function() InputRemote:FireServer("Summon", { Rotation = data.Rotation or 0, cframe = cf, Unit = data.Unit }) end)
                        end
                    elseif actionType == "Upgrade" then
                        local unit = FindUnitForAction(data)
                        if unit then pcall(function() ServerRemote:InvokeServer("Upgrade", unit) end) end
                    elseif actionType == "Sell" then
                        local unit = FindUnitForAction(data)
                        if unit then pcall(function() ServerRemote:InvokeServer("Sell", unit) end) end
                    end
                end
                
                UpdateUIStatus(nil, nil, GetCurrentWave(), math.floor(tick() - playbackStartTime), index)
                task.wait(0.1)
            end
            if loopPlayback and Playback.Token == token then task.wait(2) end
        until not loopPlayback or Playback.Token ~= token

        if Playback.Token == token then
            Playback.Running = false
            UpdateUIStatus("Idle ⚪")
        end
    end)
end

-- ==========================================
-- 🎮 6. CONTROLS BINDING
-- ==========================================
Tabs.Macro:AddSection("Controls")

Tabs.Macro:AddButton({ Title = "🔴 Start Recording", Callback = function()
    if MacroState.CurrentFile == "None" then Fluent:Notify({ Title = "Warning", Content = "เลือกไฟล์ก่อนอัด!", Duration = 3 }) return end
    RecordedActions = {}
    RecordingStartTime = tick()
    UpdateUIStatus("Recording 🔴", nil, 0, 0, 0)
    Fluent:Notify({ Title = "Recording...", Content = "เริ่มบันทึกมาโครแล้ว!", Duration = 2 })
end})

Tabs.Macro:AddButton({ Title = "⏹️ Stop Recording & Auto-Save", Callback = function()
    if MacroState.Status == "Recording 🔴" then
        UpdateUIStatus("Idle ⚪")
        local dataToSave = { Info = "Ultimate Macro System V4", TotalActions = #RecordedActions, Actions = RecordedActions }
        local path = MacroFS.FolderName .. "/" .. MacroState.CurrentFile .. MacroFS.Extension
        if writefile then
            local success = pcall(function() writefile(path, HttpService:JSONEncode(dataToSave)) end)
            if success then Fluent:Notify({ Title = "Saved!", Content = "เซฟมาโคร " .. #RecordedActions .. " แอคชั่น", Duration = 3 }) end
        end
    end
end})

local AutoPlayMacro = Tabs.Macro:AddToggle("AutoPlayMacro", { Title = "🟢 Auto Play Selected Macro (Looping)", Default = false })
AutoPlayMacro:OnChanged(function(Value)
    if Value then
        if MacroState.CurrentFile == "None" then AutoPlayMacro:SetValue(false) return end
        UpdateUIStatus("Playing (Loop) 🟢")
        PlayMacro(true)
    else
        StopMacroPlayback()
    end
end)

Tabs.Macro:AddButton({ Title = "▶️ Play Macro (Run Once)", Callback = function()
    if MacroState.CurrentFile == "None" then return end
    UpdateUIStatus("Playing (Once) ▶️")
    PlayMacro(false)
end})

Tabs.Macro:AddButton({ Title = "⏹️ Stop Macro", Callback = function()
    StopMacroPlayback()
    AutoPlayMacro:SetValue(false)
end})

-- ==========================================
-- 🪝 7. THE SAFE HOOK (ACTION QUEUE)
-- ==========================================
task.spawn(function()
    while task.wait(0.05) do
        if #ActionQueue > 0 then
            for _, action in ipairs(ActionQueue) do
                if action.Type == "Summon" then
                    action.Data.Cost = GetUnitCostFromName(action.Data.Unit)
                    RecordAction("Summon", action.Data)
                elseif action.Type == "Upgrade" then
                    local targetUnit = action.Data.UnitInstance
                    RecordAction("Upgrade", {
                        UnitName = targetUnit.Name,
                        Position = {targetUnit:GetPivot().Position.X, targetUnit:GetPivot().Position.Y, targetUnit:GetPivot().Position.Z},
                        Cost = GetUpgradeCostFromUI()
                    })
                elseif action.Type == "Sell" then
                    local targetUnit = action.Data.UnitInstance
                    RecordAction("Sell", {
                        UnitName = targetUnit.Name,
                        Position = {targetUnit:GetPivot().Position.X, targetUnit:GetPivot().Position.Y, targetUnit:GetPivot().Position.Z},
                        Cost = 0 
                    })
                end
            end
            ActionQueue = {}
        end
    end
end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if MacroState.Status == "Recording 🔴" and not checkcaller() then
        if method == "FireServer" and self == InputRemote then
            local commandType = args[1]
            if commandType == "Summon" and type(args[2]) == "table" and typeof(args[2].cframe) == "CFrame" then
                table.insert(ActionQueue, {
                    Type = "Summon",
                    Data = { Unit = tostring(args[2].Unit), Rotation = args[2].Rotation, CFrameData = CFrameToTable(args[2].cframe) }
                })
            end
        elseif method == "InvokeServer" and self == ServerRemote then
             local commandType = args[1]
             if (commandType == "Upgrade" or commandType == "Sell") and typeof(args[2]) == "Instance" then
                 table.insert(ActionQueue, { Type = commandType, Data = { UnitInstance = args[2] } })
             end
        end
    end
    return oldNamecall(self, ...)
end)

Fluent:Notify({ Title = "V4 Loaded", Content = "Ultimate Macro System ทำงานแล้ว!", Duration = 5 })
