-- ============================================================================
-- 👑 ULTIMATE MACRO SYSTEM (V6.1) : MASTER EDITION
-- Architecture: Safe Action Queue + Smart Playback + QoL Automation
-- Updates: User's Custom AutoSpeed, Silent Auto-Save, Clean UI (No Config Tab)
-- ============================================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")

local InputRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Input")
local ServerRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Server")

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()

-- ============================================================================
-- 1. CORE STATE & VARIABLES
-- ============================================================================
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
    PositionTolerance = 4
}

local AutomationState = {
    LastClick = {},
    LastUpgradeSweep = 0,
    LastSpeedCheck = 0
}

-- ============================================================================
-- 2. FILE SYSTEM (MacroFS)
-- ============================================================================
local MacroFS = { FolderName = "TD_MasterMacros", Extension = ".json" }
if isfolder and not isfolder(MacroFS.FolderName) then makefolder(MacroFS.FolderName) end

function MacroFS.GetMacroFiles()
    local files = {"None"}
    if listfiles then
        pcall(function()
            for _, path in ipairs(listfiles(MacroFS.FolderName)) do
                local fileName = string.match(path, "([^/\\]+)%.json$")
                if fileName then table.insert(files, fileName) end
            end
        end)
    end
    return #files > 1 and files or {"None"}
end

function MacroFS.CreateEmptyMacro(name)
    if name == "" or name == "None" then return false end
    local path = MacroFS.FolderName .. "/" .. name .. MacroFS.Extension
    local emptyData = HttpService:JSONEncode({ Info = "Ultimate Macro V5.1", Actions = {} })
    if writefile then writefile(path, emptyData) return true end
    return false
end

function MacroFS.DeleteMacro(name)
    if name == "" or name == "None" then return false end
    local path = MacroFS.FolderName .. "/" .. name .. MacroFS.Extension
    if isfile and isfile(path) and delfile then delfile(path) return true end
    return false
end

-- ============================================================================
-- 3. UTILITY & PARSING FUNCTIONS (Core Logic)
-- ============================================================================
local function ParsePrice(value)
    if type(value) == "number" then return math.max(0, math.floor(value + 0.5)) end
    if type(value) ~= "string" then return 0 end
    local text = string.lower(value):gsub("[$,]", ""):gsub("%s+", "")
    local numberText, suffix = text:match("([%d%.]+)([kmbt]?)")
    local amount = tonumber(numberText)
    if not amount then return 0 end
    local multipliers = { k = 1000, m = 1000000, b = 1000000000, t = 1000000000000 }
    return math.max(0, math.floor((amount * (multipliers[suffix] or 1)) + 0.5))
end

local function ReadText(instance)
    if instance and (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then return instance.Text end
    return ""
end

local function SafeFind(root, ...)
    local current = root
    for _, name in ipairs({...}) do
        if not current then return nil end
        current = current:FindFirstChild(name)
    end
    return current
end

local function IsVisible(instance)
    local ok, result = pcall(function() return instance and instance.Visible == true end)
    return ok and result or false
end

local function GetHUD() return LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("HUD") end
local function GetCurrentWave()
    local ok, wave = pcall(function() return tonumber(ReadText(SafeFind(LocalPlayer.PlayerGui, "HUD", "Wave")):match("(%d+)")) or 0 end)
    return ok and wave or 0
end
local function GetCurrentCash()
    local ok, cash = pcall(function() return ParsePrice(ReadText(SafeFind(LocalPlayer.PlayerGui, "HUD", "BottomFrame", "CurrencyList", "Cash"))) end)
    return ok and cash or 0
end
local function GetTimeSinceRecording() return RecordingStartTime == 0 and 0 or math.max(0, tick() - RecordingStartTime) end
local function CFrameToTable(cf) return typeof(cf) == "CFrame" and {cf.X, cf.Y, cf.Z} or nil end
local function TableToCFrame(values) return (type(values) == "table" and #values >= 3) and CFrame.new(values[1], values[2], values[3]) or nil end

local function GetUnitCostFromName(targetUnitName)
    local unitsFolder = SafeFind(LocalPlayer.PlayerGui, "HUD", "BottomFrame", "Unit")
    if not unitsFolder then return 0 end
    for _, slot in ipairs(unitsFolder:GetChildren()) do
        local unitObj = slot:FindFirstChild("Unit")
        if unitObj and unitObj:IsA("StringValue") and unitObj.Value == targetUnitName then
            return ParsePrice(ReadText(slot:FindFirstChild("ImageLabel") and slot.ImageLabel:FindFirstChild("TextLabel")))
        end
    end
    return 0
end

local function GetUpgradeCostFromUI()
    local amount = SafeFind(LocalPlayer.PlayerGui, "HUD", "UpgradeV2", "Actions", "Upgrade", "Amount")
    return amount and ParsePrice(ReadText(amount)) or 0
end

local function GetUnitPosition(unitInstance)
    if typeof(unitInstance) ~= "Instance" then return nil end
    local ok, pivot = pcall(function() return unitInstance:GetPivot() end)
    if ok and typeof(pivot) == "CFrame" then return pivot.Position end
    if unitInstance:IsA("BasePart") then return unitInstance.Position end
    return nil
end

-- ระบบทะลวง UI โคตรโกง (Bypass UI Blocking)
local function VirtualClick(button)
    if not button then return end
    if getconnections then
        pcall(function() for _, conn in ipairs(getconnections(button.MouseButton1Click)) do pcall(function() conn:Fire() end) end end)
        pcall(function() for _, conn in ipairs(getconnections(button.Activated)) do pcall(function() conn:Fire() end) end end)
    elseif firesignal then
        pcall(function() firesignal(button.MouseButton1Click) end)
        pcall(function() firesignal(button.Activated) end)
    end
    pcall(function() button:Activate() end)
end

local function ClickWithCooldown(key, button, cooldown)
    if not button then return false end
    local now = os.clock()
    if AutomationState.LastClick[key] and now - AutomationState.LastClick[key] < cooldown then return false end
    AutomationState.LastClick[key] = now
    VirtualClick(button)
    return true
end

local function FindActionButton(actionsFrame, names)
    if not actionsFrame then return nil end
    for _, name in ipairs(names) do
        local button = actionsFrame:FindFirstChild(name)
        if button then return button end
    end
    for _, descendant in ipairs(actionsFrame:GetDescendants()) do
        if descendant:IsA("TextButton") or descendant:IsA("ImageButton") then
            local lowerName, lowerText = string.lower(descendant.Name), string.lower(ReadText(descendant))
            for _, name in ipairs(names) do
                local target = string.lower(name)
                if lowerName:find(target, 1, true) or lowerText:find(target, 1, true) then return descendant end
            end
        end
    end
    return nil
end

-- ==========================================
-- [เพิ่มใหม่] ฟังก์ชัน Base64 สำหรับ Export/Import
-- ==========================================
local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function Base64Encode(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function Base64Decode(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

-- ============================================================================
-- 4. BUILDING THE UI (V5.1 Clean Architecture)
-- ============================================================================
local Window = Fluent:CreateWindow({
    Title = "AutoPlay Hub Pro",
    SubTitle = "Ultimate Macro V5.1",
    TabWidth = 160, Size = UDim2.fromOffset(620, 500),
    Acrylic = true, Theme = "Darker", MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Ingame = Window:AddTab({Title = "Ingame", Icon = "gamepad-2"}),
    Macro = Window:AddTab({Title = "Macro Engine", Icon = "play"}),
    Settings = Window:AddTab({Title = "Settings", Icon = "settings"})
}
Window:SelectTab(1)

-- ---------------- [ TAB 1: MACRO ENGINE ] ----------------
Tabs.Macro:AddSection("Status")
local StatusDisplay = Tabs.Macro:AddParagraph({ Title = "ℹ️ Current Status", Content = "Loading..." })
local function UpdateUIStatus(newState, newFile, newWave, newTime, newActions)
    MacroState.Status = newState or MacroState.Status
    MacroState.CurrentFile = newFile or MacroState.CurrentFile
    MacroState.CurrentWave = newWave or MacroState.CurrentWave
    MacroState.InGameTime = newTime or MacroState.InGameTime
    MacroState.ActionCount = newActions or MacroState.ActionCount
    StatusDisplay:SetDesc(string.format("File: %s\nStatus: %s\nWave: %d\nIn-Game Time: %ds\nActions: %d", MacroState.CurrentFile, MacroState.Status, MacroState.CurrentWave, MacroState.InGameTime, MacroState.ActionCount))
end
UpdateUIStatus()

Tabs.Macro:AddSection("File Management")
local NewMacroInput = Tabs.Macro:AddInput("NewMacroName", { Title = "New Macro Name", Placeholder = "Enter Text...", Finished = false })
local MacroDropdown

Tabs.Macro:AddButton({ Title = "➕ Create & Select File", Callback = function()
    local fileName = NewMacroInput.Value
    if fileName ~= "" and MacroFS.CreateEmptyMacro(fileName) then
        Fluent:Notify({ Title = "Success", Content = "สร้างไฟล์สำเร็จ!", Duration = 3 })
        MacroDropdown:SetValues(MacroFS.GetMacroFiles())
        MacroDropdown:SetValue(fileName)
        UpdateUIStatus(nil, fileName, nil, nil, 0)
    end
end})
MacroDropdown = Tabs.Macro:AddDropdown("SelectMacroFile", { Title = "📂 Select / Load Macro File", Values = MacroFS.GetMacroFiles(), Multi = false, Default = 1 })
MacroDropdown:OnChanged(function(value) UpdateUIStatus(nil, value, nil, nil, nil) end)
Tabs.Macro:AddButton({ Title = "🔄 Refresh List", Callback = function() MacroDropdown:SetValues(MacroFS.GetMacroFiles()) end})
Tabs.Macro:AddButton({ Title = "🗑️ Delete Selected File", Callback = function()
    local selectedFile = MacroDropdown.Value
    if selectedFile ~= "None" and MacroFS.DeleteMacro(selectedFile) then
        Fluent:Notify({ Title = "Deleted", Content = "ลบไฟล์มาโครสำเร็จ!", Duration = 3 })
        MacroDropdown:SetValues(MacroFS.GetMacroFiles())
        MacroDropdown:SetValue("None")
        UpdateUIStatus(nil, "None", nil, nil, 0)
    end
end})
Tabs.Macro:AddButton({ Title = "📤 Export Selected Macro (Copy to Clipboard)", Callback = function()
    local selectedFile = MacroDropdown.Value
    if selectedFile == "None" then return Fluent:Notify({ Title = "Error", Content = "เลือกไฟล์ก่อน Export!", Duration = 3 }) end
    
    local path = MacroFS.FolderName .. "/" .. selectedFile .. MacroFS.Extension
    if isfile(path) then
        local rawData = readfile(path)
        local encodedData = "TDMACRO_" .. Base64Encode(rawData)
        if setclipboard then
            setclipboard(encodedData)
            Fluent:Notify({ Title = "Exported!", Content = "ก๊อปปี้โค้ดมาโครแล้ว เอาไปแจกได้เลย!", Duration = 5 })
        else
            Fluent:Notify({ Title = "Error", Content = "ตัวรันนี้ไม่รองรับระบบก๊อปปี้ (setclipboard)", Duration = 3 })
        end
    end
end})

local ImportCodeInput = Tabs.Macro:AddInput("ImportCodeInput", { Title = "📥 Paste Macro Code", Placeholder = "วางโค้ด TDMACRO_ ที่นี่...", Finished = false })
local ImportNameInput = Tabs.Macro:AddInput("ImportNameInput", { Title = "✏️ New Macro Name", Placeholder = "ตั้งชื่อไฟล์ใหม่...", Finished = false })

Tabs.Macro:AddButton({ Title = "💾 Import & Save Macro", Callback = function()
    local code = ImportCodeInput.Value
    local newName = ImportNameInput.Value
    
    if code == "" or newName == "" then return Fluent:Notify({ Title = "Error", Content = "กรอกโค้ดและชื่อไฟล์ให้ครบ!", Duration = 3 }) end
    if not string.find(code, "^TDMACRO_") then return Fluent:Notify({ Title = "Error", Content = "โค้ดมาโครไม่ถูกต้อง!", Duration = 3 }) end
    
    local cleanCode = string.gsub(code, "TDMACRO_", "")
    local success, decodedData = pcall(function() return Base64Decode(cleanCode) end)
    
    if success and decodedData and string.find(decodedData, "Actions") then
        local path = MacroFS.FolderName .. "/" .. newName .. MacroFS.Extension
        if writefile then
            writefile(path, decodedData)
            Fluent:Notify({ Title = "Import Success!", Content = "นำเข้าไฟล์ " .. newName .. " สำเร็จ!", Duration = 4 })
            MacroDropdown:SetValues(MacroFS.GetMacroFiles())
            MacroDropdown:SetValue(newName)
            UpdateUIStatus(nil, newName, nil, nil, 0)
        end
    else
        Fluent:Notify({ Title = "Error", Content = "ไฟล์เสียหรือถอดรหัสไม่ได้!", Duration = 3 })
    end
end})

-- Controls Section + Auto Upgrade All
Tabs.Macro:AddSection("Controls")
local PlaybackMode = Tabs.Macro:AddDropdown("PlaybackMode", { Title = "⚙️ Playback Mode", Values = {"Strict Time", "Money + Time", "Action Based"}, Multi = false, Default = 2 })
local AutoUpgradeAll = Tabs.Macro:AddToggle("AutoUpgradeAll", { Title = "⬆️ Auto Upgrade All", Description = "อัพเกรดทุกตัวอัตโนมัติ (จะหยุดทำงานเมื่อ Macro กำลังเล่น)", Default = false })

-- ---------------- [ TAB 2: INGAME ] ----------------
Tabs.Ingame:AddSection("🕹️ Main Options")
local SpeedMode = Tabs.Ingame:AddDropdown("SpeedMode", { Title = "⏩ Speed Mode", Values = {"1x", "2x", "3x"}, Multi = false, Default = 1 })
local EnableAutoGameSpeed = Tabs.Ingame:AddToggle("EnableAutoGameSpeed", { Title = "✅ Enable Auto GameSpeed", Default = false })
local EndMatchMode = Tabs.Ingame:AddDropdown("EndMatchMode", { Title = "🔚 End Match Mode", Values = {"Auto Next", "Auto Replay", "Return to Lobby"}, Multi = false, Default = 1 })

Tabs.Ingame:AddSection("♻️ Fail-Safe Recovery")
local AutoRetryOnDefeat = Tabs.Ingame:AddToggle("AutoRetryOnDefeat", { Title = "💔 Auto Retry on Defeat", Default = true })

Tabs.Ingame:AddSection("📈 Match Progression")
local AutoSkipWave = Tabs.Ingame:AddToggle("AutoSkipWave", { Title = "⏭️ Auto Skip Wave (Vote Skip)", Default = false })
local EnableEndMatchAutomation = Tabs.Ingame:AddToggle("EnableEndMatchAutomation", { Title = "🤖 Enable End Match Automation", Default = false })

Tabs.Ingame:AddSection("🗳️ Vote Mode")
local AutoVoteModeDropdown = Tabs.Ingame:AddDropdown("AutoVoteModeDropdown", { Title = "🎯 Auto Vote Mode", Values = {"Normal", "Extreme"}, Multi = false, Default = 1 })
local EnableAutoVote = Tabs.Ingame:AddToggle("EnableAutoVote", { Title = "✅ Enable Auto Vote", Default = false })

-- ---------------- [ TAB 3: SETTINGS ] ----------------
Tabs.Settings:AddSection("⚡ Performance")
local AntiAFK = Tabs.Settings:AddToggle("AntiAFK", { Title = "🏃‍♂️ Anti-AFK", Default = true })

Tabs.Settings:AddSection("🚑 Safety & Recovery")
local AutoRejoin = Tabs.Settings:AddToggle("AutoRejoin", { Title = "🔄 Auto Rejoin on Kick/Disconnect", Default = false })

-- ============================================================================
-- 5. PLAYBACK ENGINE (Logic & Replay)
-- ============================================================================
local function RecordAction(actionType, data)
    if MacroState.Status ~= "Recording 🔴" then return end
    local currentWave, timestamp = GetCurrentWave(), GetTimeSinceRecording()
    local actionEntry = { ActionType = actionType, Wave = currentWave, TimeInWave = timestamp, Timestamp = timestamp, Cost = ParsePrice(data.Cost or 0), Data = data }
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

    for _, candidate in ipairs((Workspace:FindFirstChild("Unit") or Workspace):GetDescendants()) do
        if (candidate:IsA("Model") or candidate:IsA("BasePart")) and candidate.Name == wantedName then
            if wantedPosition then
                local pos = GetUnitPosition(candidate)
                if pos then
                    local distance = (pos - wantedPosition).Magnitude
                    if distance < bestDistance and distance <= Playback.PositionTolerance then bestDistance, bestUnit = distance, candidate end
                end
            else return candidate end
        end
    end
    return bestUnit
end

local function WaitForActionReady(action, playbackStartTime, token)
    local mode = PlaybackMode.Value
    local targetTime, targetWave, targetCost = tonumber(action.Timestamp or action.TimeInWave) or 0, tonumber(action.Wave) or 0, ParsePrice(action.Cost)

    if mode == "Strict Time" or mode == "Money + Time" then
        while Playback.Running and Playback.Token == token and (tick() - playbackStartTime < targetTime) do task.wait(0.1) end
    end
    if targetWave > 0 then
        while Playback.Running and Playback.Token == token and (GetCurrentWave() < targetWave) do task.wait(0.5) end
    end
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
            local playbackStartTime = tick()
            for index, action in ipairs(actions) do
                if Playback.Token ~= token or not Playback.Running then break end
                UpdateUIStatus(nil, nil, GetCurrentWave(), math.floor(tick() - playbackStartTime), index - 1)

                if WaitForActionReady(action, playbackStartTime, token) then
                    local actionType, data = action.ActionType, action.Data
                    if actionType == "Summon" then
                        local cf = TableToCFrame(data.CFrameData or data.CFrame)
                        if cf then pcall(function() InputRemote:FireServer("Summon", { Rotation = data.Rotation or 0, cframe = cf, Unit = data.Unit }) end) end
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

        if Playback.Token == token then Playback.Running = false UpdateUIStatus("Idle ⚪") end
    end)
end

-- ============================================================================
-- 6. CONTROLS BINDING (Macro Engine UI Logic)
-- ============================================================================
Tabs.Macro:AddButton({ Title = "🔴 Start Recording", Callback = function()
    if MacroState.CurrentFile == "None" then Fluent:Notify({ Title = "Warning", Content = "เลือกไฟล์ก่อนอัด!", Duration = 3 }) return end
    RecordedActions, RecordingStartTime = {}, tick()
    UpdateUIStatus("Recording 🔴", nil, 0, 0, 0)
    Fluent:Notify({ Title = "Recording...", Content = "เริ่มบันทึกมาโครแล้ว!", Duration = 2 })
end})

Tabs.Macro:AddButton({ Title = "⏹️ Stop Recording & Auto-Save", Callback = function()
    if MacroState.Status == "Recording 🔴" then
        UpdateUIStatus("Idle ⚪")
        local dataToSave = { Info = "Ultimate Macro System V5.1", TotalActions = #RecordedActions, Actions = RecordedActions }
        local path = MacroFS.FolderName .. "/" .. MacroState.CurrentFile .. MacroFS.Extension
        if writefile then
            pcall(function() writefile(path, HttpService:JSONEncode(dataToSave)) end)
            Fluent:Notify({ Title = "Saved", Content = "เซฟมาโคร " .. #RecordedActions .. " แอคชั่น", Duration = 3 })
        end
    end
end})

-- สร้างตัวแปรล็อกระบบไว้ก่อน ป้องกัน UI ตีกันตอนโหลดเซฟ
local IsBooting = true 

local AutoPlayMacro = Tabs.Macro:AddToggle("AutoPlayMacro", { Title = "🟢 Auto Play Selected Macro (Looping)", Default = false })
AutoPlayMacro:OnChanged(function(value)
    if IsBooting then return end -- ถ้ากำลัง Boot เซฟอยู่ ห้ามเสร่อทำงาน! ปล่อยผ่านไปเลย
    
    if value then
        if MacroState.CurrentFile == "None" then 
            AutoPlayMacro:SetValue(false) 
            return 
        end
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

-- ============================================================================
-- 7. V5.1 INGAME AUTOMATION FEATURES (With User's AutoSpeed)
-- ============================================================================
local function RunAutoVote()
    if not EnableAutoVote.Value then return end
    local voteFrame = SafeFind(GetHUD(), "ModeVoteFrame")
    if not IsVisible(voteFrame) then return end
    local choice = AutoVoteModeDropdown.Value
    local button = SafeFind(voteFrame, choice, "TextButton")
    ClickWithCooldown("ModeVote_" .. choice, button, 0.6)
end

local function RunAutoSkipWave()
    if not AutoSkipWave.Value then return end
    local nextWaveVote = SafeFind(GetHUD(), "NextWaveVote")
    if not IsVisible(nextWaveVote) then return end
    local yesButton = SafeFind(nextWaveVote, "YesButton") or FindActionButton(nextWaveVote, {"Yes", "YesButton"})
    ClickWithCooldown("NextWaveYes", yesButton, 0.35)
end

local function RunEndMatchAutomation()
    if not EnableEndMatchAutomation.Value then return end
    local missionEnd = SafeFind(GetHUD(), "MissionEnd")
    if not IsVisible(missionEnd) then return end

    local statusText = ReadText(SafeFind(missionEnd, "BG", "Status", "Status"))
    local actions = SafeFind(missionEnd, "BG", "Actions")
    if not actions then return end

    -- กรณีแพ้
    if statusText == "Failed!" and AutoRetryOnDefeat.Value then
        ClickWithCooldown("MissionEndReplayAggressive", FindActionButton(actions, {"Replay"}), 0.15)
        return
    end

    -- ตามโหมดที่เลือก
    local mode = EndMatchMode.Value
    local button = (mode == "Auto Next" and FindActionButton(actions, {"Next"})) or
                   (mode == "Auto Replay" and FindActionButton(actions, {"Replay"})) or
                   (mode == "Return to Lobby" and FindActionButton(actions, {"Return"}))
    
    ClickWithCooldown("MissionEnd_" .. tostring(mode), button, 0.45)
end

-- 🛠️ โค้ด AutoSpeed ฉบับของบอสเป๊ะๆ
local function HandleAutoSpeed()
    if not EnableAutoGameSpeed.Value then return end
    local hud = LocalPlayer.PlayerGui:FindFirstChild("HUD")
    if not hud then return end
    local speedLabel = hud:FindFirstChild("FastForward") and hud.FastForward:FindFirstChild("TextLabel")
    if not speedLabel then return end
    
    local currentSpeed = tonumber(string.match(speedLabel.Text, "%d+")) or 1
    local targetSpeed = tonumber(string.match(SpeedMode.Value, "%d+")) or 1
    local inputRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Input")
    
    if not inputRemote then return end
    
    -- ใส่ task.spawn ครอบไว้ เพื่อไม่ให้ task.wait(0.5) ไปหน่วงการข้ามเวฟ
    task.spawn(function()
        if currentSpeed < targetSpeed then
            inputRemote:FireServer("SpeedChange", true)
            task.wait(0.5)
        elseif currentSpeed > targetSpeed then
            inputRemote:FireServer("SpeedChange", false)
            task.wait(0.5)
        end
    end)
end

local function RunAutoUpgradeAll()
    if not AutoUpgradeAll.Value or Playback.Running == true then return end
    local unitFolder = Workspace:FindFirstChild("Unit")
    if not unitFolder then return end

    for _, unitInstance in ipairs(unitFolder:GetChildren()) do
        if Playback.Running == true or not AutoUpgradeAll.Value then break end
        pcall(function() ServerRemote:InvokeServer("Upgrade", unitInstance) end)
        task.wait(0.05)
    end
end

-- ลูปการทำงานของระบบอัตโนมัติเบื้องหลัง
task.spawn(function()
    while task.wait(0.2) do
        pcall(RunAutoVote)
        pcall(RunAutoSkipWave)
        pcall(RunEndMatchAutomation)
        
        local now = os.clock()
        -- เช็คความเร็วเกมทุกๆ 2 วินาที
        if now - AutomationState.LastSpeedCheck > 2 then
            AutomationState.LastSpeedCheck = now
            pcall(HandleAutoSpeed)
        end
        
        -- วนอัพเกรดทุก 1.5 วินาทีถ้าว่าง
        if now - AutomationState.LastUpgradeSweep >= 1.5 then 
            AutomationState.LastUpgradeSweep = now
            pcall(RunAutoUpgradeAll)
        end
    end
end)

-- ============================================================================
-- 8. SAFETY & ANTI-AFK RECOVERY
-- ============================================================================
LocalPlayer.Idled:Connect(function()
    if AntiAFK.Value then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

-- Auto Rejoin
task.spawn(function()
    local promptOverlay = CoreGui:WaitForChild("RobloxPromptGui"):WaitForChild("promptOverlay")
    promptOverlay.ChildAdded:Connect(function(child)
        if AutoRejoin.Value and child.Name == "ErrorPrompt" then
            task.wait(2)
            pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
        end
    end)
end)

-- ============================================================================
-- 9. THE SAFE HOOK (ACTION QUEUE)
-- ============================================================================

task.spawn(function()
    while task.wait(0.05) do
        if #ActionQueue > 0 then
            for _, action in ipairs(ActionQueue) do
                local currentCash = GetCurrentCash() -- เช็คเงินในกระเป๋าปัจจุบัน
                
                if action.Type == "Summon" then
                    local cost = GetUnitCostFromName(action.Data.Unit)
                    if currentCash >= cost then -- ตรวจสอบก่อนจดจำ
                        action.Data.Cost = cost
                        RecordAction("Summon", action.Data)
                    else
                        Fluent:Notify({ Title = "Macro Skipped", Content = "เงินไม่พอวางตัวละคร! (ไม่บันทึกลงคิว)", Duration = 2 })
                    end
                    
                elseif action.Type == "Upgrade" then
                    local targetUnit = action.Data.UnitInstance
                    local cost = GetUpgradeCostFromUI()
                    if currentCash >= cost and cost > 0 then -- ตรวจสอบก่อนจดจำ
                        RecordAction("Upgrade", { UnitName = targetUnit.Name, Position = {targetUnit:GetPivot().Position.X, targetUnit:GetPivot().Position.Y, targetUnit:GetPivot().Position.Z}, Cost = cost })
                    else
                        Fluent:Notify({ Title = "Macro Skipped", Content = "เงินไม่พออัพเกรด หรือตันแล้ว!", Duration = 2 })
                    end
                    
                elseif action.Type == "Sell" then
                    local targetUnit = action.Data.UnitInstance
                    RecordAction("Sell", { UnitName = targetUnit.Name, Position = {targetUnit:GetPivot().Position.X, targetUnit:GetPivot().Position.Y, targetUnit:GetPivot().Position.Z}, Cost = 0 })
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
                table.insert(ActionQueue, { Type = "Summon", Data = { Unit = tostring(args[2].Unit), Rotation = args[2].Rotation, CFrameData = CFrameToTable(args[2].cframe) } })
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

-- ============================================================================
-- 10. SILENT AUTO-SAVE SYSTEM & AUTO PLAY TRIGGER
-- ============================================================================
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "NewMacroName" }) 
SaveManager:SetFolder("AutoPlayHubPro/UltimateMacroV5")

-- 1. ตอนโหลดสคริปต์ ให้แอบโหลดการตั้งค่าเดิมขึ้นมาก่อน
pcall(function()
    SaveManager:Load("SilentAutoSaveConfig")
end)

Window:SelectTab(1)
Fluent:Notify({ Title = "V5.1 Master Loaded", Content = "Ultimate Hub V5.1 พร้อมใช้งาน!", Duration = 5 })

-- ==========================================
-- [ชิ้นส่วน 4.2 Master] Smart Trigger เช็คสถานะไฟล์และปลดล็อกระบบ
-- ==========================================
task.spawn(function()
    local timeout = 10 -- ให้เวลารอไฟล์สูงสุด 10 วินาที
    local elapsed = 0
    local checkInterval = 0.5

    -- ลูปเช็คว่า SaveManager โหลดชื่อไฟล์มาทับคำว่า "None" หรือยัง
    while elapsed < timeout do
        if MacroState.CurrentFile ~= "None" and MacroState.CurrentFile ~= "" then
            break -- ไฟล์มาแล้ว หลุดลูปได้เลย ไม่ต้องรอครบ 10 วิ
        end
        task.wait(checkInterval)
        elapsed = elapsed + checkInterval
    end
    
    -- โหลดเสร็จแล้ว ปลดล็อกระบบ Boot ให้ปุ่มกลับมาทำงานได้ปกติ
    IsBooting = false 

    -- ค่อยมาเช็คว่าปุ่ม Auto Play ถูกเปิดค้างไว้จากเซฟไหม
    if AutoPlayMacro and AutoPlayMacro.Value == true then
        if MacroState.CurrentFile ~= "None" then
            Fluent:Notify({ Title = "Auto Play Triggered", Content = "โหลดเซฟเสร็จสิ้น! เริ่มลุยมาโคร...", Duration = 3 })
            UpdateUIStatus("Playing (Loop) 🟢")
            PlayMacro(true) -- สั่งลุยแบบลูปต่อเนื่อง
        else
            -- ถ้าหมดเวลา 10 วิแล้วไฟล์ยังพังอยู่ ค่อยสับสวิตช์ปิดตัวเอง
            AutoPlayMacro:SetValue(false) 
            Fluent:Notify({ Title = "Auto Play Failed", Content = "ไม่พบไฟล์มาโคร ยกเลิกออโต้รัน!", Duration = 3 })
        end
    end
end)

-- 2. สร้างลูปซุ่มเซฟ ทำงานเบื้องหลังทุกๆ 3 วินาที
task.spawn(function()
    while task.wait(3) do
        pcall(function()
            SaveManager:Save("SilentAutoSaveConfig")
        end)
    end
end)
