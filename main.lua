-- ============================================================================
-- 👑 ULTIMATE MACRO SYSTEM (V7) : GOD TIER EDITION
-- Architecture: Safe Action Queue + Smart Playback + QoL Automation
-- Updates: Auto-Execute, Smart Environment Check, Mobile Icon, Real-Time Save
-- ============================================================================

-- ============================================================================
-- 🚀 1. AUTO-EXECUTE ON TELEPORT (ฝังตัวข้ามแมพ)
-- ============================================================================
if queue_on_teleport then
    local autoExecCode = [[
        task.wait(2)
        loadstring(game:HttpGet("https://raw.githubusercontent.com/qqunglnwza007-ops/Roblox/refs/heads/main/main.lua"))()
    ]]
    queue_on_teleport(autoExecCode)
end

-- ============================================================================
-- 2. CORE SERVICES & INITIAL VARIABLES
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
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ============================================================================
-- 3. STATE MANAGEMENT & ENVIRONMENT CHECK
-- ============================================================================
local MacroState = {
    CurrentFile = "None",
    Status = "Loading...",
    CurrentWave = 0,
    InGameTime = 0,
    ActionCount = 0
}

local RecordedActions = {}
local RecordingStartTime = 0
local ActionQueue = {}

local Playback = { Running = false, Token = 0, PositionTolerance = 4 }
local AutomationState = { LastClick = {}, LastUpgradeSweep = 0, LastSpeedCheck = 0 }

local IsBooting = true -- ป้องกัน UI ทำงานทับซ้อนตอนโหลดเซฟ
local IsInGame = false -- เอาไว้เช็ค Lobby / แผนที่ต่อสู้

task.spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    local maxWaitTime = 15 
    local elapsed = 0
    
    while elapsed < maxWaitTime do
        local hud = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("HUD")
        if hud and hud:FindFirstChild("Wave") then
            IsInGame = true
            print("[System] บอสอยู่ในแมพต่อสู้! ปลดล็อกระบบ Macro...")
            break
        end
        task.wait(1)
        elapsed = elapsed + 1
    end

    if not IsInGame then
        print("[System] บอสอยู่ใน Lobby! ปิดระบบที่เกี่ยวกับการต่อสู้...")
        MacroState.Status = "Lobby 🏕️"
    end
end)

-- ============================================================================
-- 4. FILE SYSTEM (MacroFS) & BASE64
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
    local emptyData = HttpService:JSONEncode({ Info = "Ultimate Macro V7", Actions = {} })
    if writefile then writefile(path, emptyData) return true end
    return false
end

function MacroFS.DeleteMacro(name)
    if name == "" or name == "None" then return false end
    local path = MacroFS.FolderName .. "/" .. name .. MacroFS.Extension
    if isfile and isfile(path) and delfile then delfile(path) return true end
    return false
end

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
-- 5. UTILITY FUNCTIONS
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

local function ReadText(inst) return (inst and (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox"))) and inst.Text or "" end
local function SafeFind(root, ...)
    local curr = root
    for _, name in ipairs({...}) do
        if not curr then return nil end
        curr = curr:FindFirstChild(name)
    end
    return curr
end
local function IsVisible(inst) pcall(function() return inst and inst.Visible == true end) return false end
local function GetHUD() return LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("HUD") end
local function GetCurrentWave() return tonumber(ReadText(SafeFind(LocalPlayer.PlayerGui, "HUD", "Wave")):match("(%d+)")) or 0 end
local function GetCurrentCash() return ParsePrice(ReadText(SafeFind(LocalPlayer.PlayerGui, "HUD", "BottomFrame", "CurrencyList", "Cash"))) end
local function GetTimeSinceRecording() return RecordingStartTime == 0 and 0 or math.max(0, tick() - RecordingStartTime) end
local function CFrameToTable(cf) return typeof(cf) == "CFrame" and {cf.X, cf.Y, cf.Z} or nil end
local function TableToCFrame(v) return (type(v) == "table" and #v >= 3) and CFrame.new(v[1], v[2], v[3]) or nil end

local function GetUnitCostFromName(name)
    local units = SafeFind(LocalPlayer.PlayerGui, "HUD", "BottomFrame", "Unit")
    if not units then return 0 end
    for _, slot in ipairs(units:GetChildren()) do
        local u = slot:FindFirstChild("Unit")
        if u and u:IsA("StringValue") and u.Value == name then
            return ParsePrice(ReadText(slot:FindFirstChild("ImageLabel") and slot.ImageLabel:FindFirstChild("TextLabel")))
        end
    end
    return 0
end

local function GetUpgradeCostFromUI()
    local amt = SafeFind(LocalPlayer.PlayerGui, "HUD", "UpgradeV2", "Actions", "Upgrade", "Amount")
    return amt and ParsePrice(ReadText(amt)) or 0
end

local function GetUnitPosition(unit)
    if typeof(unit) ~= "Instance" then return nil end
    local ok, pivot = pcall(function() return unit:GetPivot() end)
    if ok and typeof(pivot) == "CFrame" then return pivot.Position end
    if unit:IsA("BasePart") then return unit.Position end
    return nil
end

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

local function ClickWithCooldown(key, button, cd)
    if not button then return false end
    local now = os.clock()
    if AutomationState.LastClick[key] and now - AutomationState.LastClick[key] < cd then return false end
    AutomationState.LastClick[key] = now
    VirtualClick(button)
    return true
end

local function FindActionButton(frame, names)
    if not frame then return nil end
    for _, name in ipairs(names) do if frame:FindFirstChild(name) then return frame[name] end end
    for _, desc in ipairs(frame:GetDescendants()) do
        if desc:IsA("TextButton") or desc:IsA("ImageButton") then
            local ln, lt = string.lower(desc.Name), string.lower(ReadText(desc))
            for _, name in ipairs(names) do
                local target = string.lower(name)
                if ln:find(target, 1, true) or lt:find(target, 1, true) then return desc end
            end
        end
    end
    return nil
end

-- ============================================================================
-- 6. REAL-TIME SAVE HELPER
-- ============================================================================
local function TriggerSave()
    if IsBooting then return end
    pcall(function() SaveManager:Save("SilentAutoSaveConfig") end)
end

-- ============================================================================
-- 7. BUILDING THE UI (V7)
-- ============================================================================
local Window = Fluent:CreateWindow({
    Title = "AutoPlay Hub Pro",
    SubTitle = "God Tier Macro V7",
    TabWidth = 160, Size = UDim2.fromOffset(620, 500),
    Acrylic = true, Theme = "Darker", MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Macro = Window:AddTab({Title = "Macro Engine", Icon = "play"}),
    Ingame = Window:AddTab({Title = "Ingame", Icon = "gamepad-2"}),
    Settings = Window:AddTab({Title = "Settings", Icon = "settings"})
}

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

Tabs.Macro:AddSection("File Management")
local NewMacroInput = Tabs.Macro:AddInput("NewMacroName", { Title = "New Macro Name", Placeholder = "Enter Text...", Finished = false })
local MacroDropdown = Tabs.Macro:AddDropdown("SelectMacroFile", { Title = "📂 Select / Load Macro File", Values = MacroFS.GetMacroFiles(), Multi = false, Default = 1 })

Tabs.Macro:AddButton({ Title = "➕ Create & Select File", Callback = function()
    local fName = NewMacroInput.Value
    if fName ~= "" and MacroFS.CreateEmptyMacro(fName) then
        Fluent:Notify({ Title = "Success", Content = "สร้างไฟล์สำเร็จ!", Duration = 3 })
        MacroDropdown:SetValues(MacroFS.GetMacroFiles())
        MacroDropdown:SetValue(fName)
        UpdateUIStatus(nil, fName, nil, nil, 0)
    end
end})

MacroDropdown:OnChanged(function(value) UpdateUIStatus(nil, value, nil, nil, nil); TriggerSave() end)
Tabs.Macro:AddButton({ Title = "🔄 Refresh List", Callback = function() MacroDropdown:SetValues(MacroFS.GetMacroFiles()) end})

Tabs.Macro:AddButton({ Title = "🗑️ Delete Selected File", Callback = function()
    local sel = MacroDropdown.Value
    if sel ~= "None" and MacroFS.DeleteMacro(sel) then
        Fluent:Notify({ Title = "Deleted", Content = "ลบไฟล์มาโครสำเร็จ!", Duration = 3 })
        MacroDropdown:SetValues(MacroFS.GetMacroFiles())
        MacroDropdown:SetValue("None")
        UpdateUIStatus(nil, "None", nil, nil, 0)
    end
end})

Tabs.Macro:AddButton({ Title = "📤 Export Selected Macro (Copy)", Callback = function()
    local sel = MacroDropdown.Value
    if sel == "None" then return Fluent:Notify({ Title = "Error", Content = "เลือกไฟล์ก่อน Export!", Duration = 3 }) end
    local path = MacroFS.FolderName .. "/" .. sel .. MacroFS.Extension
    if isfile(path) then
        local rawData = readfile(path)
        if setclipboard then
            setclipboard("TDMACRO_" .. Base64Encode(rawData))
            Fluent:Notify({ Title = "Exported!", Content = "ก๊อปปี้โค้ดมาโครแล้ว!", Duration = 5 })
        else
            Fluent:Notify({ Title = "Error", Content = "Executor ไม่รองรับการก๊อปปี้", Duration = 3 })
        end
    end
end})

local ImportCodeInput = Tabs.Macro:AddInput("ImportCodeInput", { Title = "📥 Paste Macro Code", Placeholder = "TDMACRO_...", Finished = false })
local ImportNameInput = Tabs.Macro:AddInput("ImportNameInput", { Title = "✏️ New Macro Name", Placeholder = "ชื่อไฟล์ใหม่...", Finished = false })
Tabs.Macro:AddButton({ Title = "💾 Import & Save Macro", Callback = function()
    local code, newName = ImportCodeInput.Value, ImportNameInput.Value
    if code == "" or newName == "" then return end
    local cleanCode = string.gsub(code, "TDMACRO_", "")
    local ok, decoded = pcall(function() return Base64Decode(cleanCode) end)
    if ok and decoded and string.find(decoded, "Actions") then
        local path = MacroFS.FolderName .. "/" .. newName .. MacroFS.Extension
        if writefile then
            writefile(path, decoded)
            Fluent:Notify({ Title = "Success", Content = "นำเข้าไฟล์สำเร็จ!", Duration = 4 })
            MacroDropdown:SetValues(MacroFS.GetMacroFiles())
            MacroDropdown:SetValue(newName)
        end
    end
end})

Tabs.Macro:AddSection("Controls")
local PlaybackMode = Tabs.Macro:AddDropdown("PlaybackMode", { Title = "⚙️ Playback Mode", Values = {"Strict Time", "Money + Time", "Action Based"}, Multi = false, Default = 2 })
PlaybackMode:OnChanged(function() TriggerSave() end)

local AutoUpgradeAll = Tabs.Macro:AddToggle("AutoUpgradeAll", { Title = "⬆️ Auto Upgrade All", Default = false })
AutoUpgradeAll:OnChanged(function() TriggerSave() end)

-- ---------------- [ TAB 2: INGAME ] ----------------
Tabs.Ingame:AddSection("🕹️ Main Options")
local SpeedMode = Tabs.Ingame:AddDropdown("SpeedMode", { Title = "⏩ Speed Mode", Values = {"1x", "2x", "3x"}, Multi = false, Default = 1 })
SpeedMode:OnChanged(function() TriggerSave() end)

local EnableAutoGameSpeed = Tabs.Ingame:AddToggle("EnableAutoGameSpeed", { Title = "✅ Enable Auto GameSpeed", Default = false })
EnableAutoGameSpeed:OnChanged(function() TriggerSave() end)

local EndMatchMode = Tabs.Ingame:AddDropdown("EndMatchMode", { Title = "🔚 End Match Mode", Values = {"Auto Next", "Auto Replay", "Return to Lobby"}, Multi = false, Default = 1 })
EndMatchMode:OnChanged(function() TriggerSave() end)

local AutoRetryOnDefeat = Tabs.Ingame:AddToggle("AutoRetryOnDefeat", { Title = "💔 Auto Retry on Defeat", Default = true })
AutoRetryOnDefeat:OnChanged(function() TriggerSave() end)

local AutoSkipWave = Tabs.Ingame:AddToggle("AutoSkipWave", { Title = "⏭️ Auto Skip Wave (Vote Skip)", Default = false })
AutoSkipWave:OnChanged(function() TriggerSave() end)

local EnableEndMatchAutomation = Tabs.Ingame:AddToggle("EnableEndMatchAutomation", { Title = "🤖 Enable End Match Automation", Default = false })
EnableEndMatchAutomation:OnChanged(function() TriggerSave() end)

local AutoVoteModeDropdown = Tabs.Ingame:AddDropdown("AutoVoteModeDropdown", { Title = "🎯 Auto Vote Mode", Values = {"Normal", "Extreme"}, Multi = false, Default = 1 })
AutoVoteModeDropdown:OnChanged(function() TriggerSave() end)

local EnableAutoVote = Tabs.Ingame:AddToggle("EnableAutoVote", { Title = "✅ Enable Auto Vote", Default = false })
EnableAutoVote:OnChanged(function() TriggerSave() end)

-- ---------------- [ TAB 3: SETTINGS ] ----------------
Tabs.Settings:AddSection("⚡ Performance")
local AntiAFK = Tabs.Settings:AddToggle("AntiAFK", { Title = "🏃‍♂️ Anti-AFK", Default = true })
AntiAFK:OnChanged(function() TriggerSave() end)

local AutoRejoin = Tabs.Settings:AddToggle("AutoRejoin", { Title = "🔄 Auto Rejoin on Disconnect", Default = false })
AutoRejoin:OnChanged(function() TriggerSave() end)

-- ============================================================================
-- 8. PLAYBACK ENGINE (Logic & Replay)
-- ============================================================================
local function RecordAction(actionType, data)
    if not IsInGame or MacroState.Status ~= "Recording 🔴" then return end
    local cw, ts = GetCurrentWave(), GetTimeSinceRecording()
    local entry = { ActionType = actionType, Wave = cw, TimeInWave = ts, Timestamp = ts, Cost = ParsePrice(data.Cost or 0), Data = data }
    table.insert(RecordedActions, entry)
    UpdateUIStatus(nil, nil, cw, math.floor(ts), #RecordedActions)
end

local function StopMacroPlayback()
    Playback.Token += 1
    Playback.Running = false
    UpdateUIStatus(not IsInGame and "Lobby 🏕️" or "Idle ⚪")
end

local function PlayMacro(loop)
    if not IsInGame then return end
    if Playback.Running then StopMacroPlayback() task.wait(0.2) end
    local path = MacroFS.FolderName .. "/" .. MacroState.CurrentFile .. MacroFS.Extension
    if not isfile(path) then return end
    
    local ok, res = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or not res.Actions then return end

    Playback.Running = true
    Playback.Token += 1
    local token = Playback.Token

    task.spawn(function()
        local start = tick()
        for idx, act in ipairs(res.Actions) do
            if Playback.Token ~= token or not Playback.Running or not IsInGame then break end
            UpdateUIStatus(nil, nil, GetCurrentWave(), math.floor(tick() - start), idx - 1)
            
            -- Wait Logic
            local mode, targetTime, targetWave, targetCost = PlaybackMode.Value, tonumber(act.Timestamp or act.TimeInWave) or 0, tonumber(act.Wave) or 0, ParsePrice(act.Cost)
            if mode == "Strict Time" or mode == "Money + Time" then
                while Playback.Running and Playback.Token == token and IsInGame and (tick() - start < targetTime) do task.wait(0.1) end
            end
            if targetWave > 0 then
                while Playback.Running and Playback.Token == token and IsInGame and (GetCurrentWave() < targetWave) do task.wait(0.5) end
            end
            if mode == "Money + Time" and targetCost > 0 then
                while Playback.Running and Playback.Token == token and IsInGame and (GetCurrentCash() < targetCost) do task.wait(0.2) end
            end

            -- Execute Logic
            if Playback.Running and Playback.Token == token and IsInGame then
                local aType, d = act.ActionType, act.Data
                if aType == "Summon" then
                    local cf = TableToCFrame(d.CFrameData or d.CFrame)
                    if cf then pcall(function() InputRemote:FireServer("Summon", { Rotation = d.Rotation or 0, cframe = cf, Unit = d.Unit }) end) end
                elseif aType == "Upgrade" or aType == "Sell" then
                    local unit
                    for _, c in ipairs((Workspace:FindFirstChild("Unit") or Workspace):GetDescendants()) do
                        if (c:IsA("Model") or c:IsA("BasePart")) and c.Name == (d.UnitName or d.Unit) then
                            if d.Position then
                                local pos = GetUnitPosition(c)
                                if pos and (pos - Vector3.new(d.Position[1], d.Position[2], d.Position[3])).Magnitude <= Playback.PositionTolerance then unit = c break end
                            else unit = c break end
                        end
                    end
                    if unit then pcall(function() ServerRemote:InvokeServer(aType, unit) end) end
                end
            end
            UpdateUIStatus(nil, nil, GetCurrentWave(), math.floor(tick() - start), idx)
            task.wait(0.1)
        end
        if loop and Playback.Token == token and IsInGame then task.wait(2) PlayMacro(true) end
        if Playback.Token == token then StopMacroPlayback() end
    end)
end

-- ============================================================================
-- 9. MACRO CONTROLS BINDING
-- ============================================================================
Tabs.Macro:AddButton({ Title = "🔴 Start Recording", Callback = function()
    if MacroState.CurrentFile == "None" or not IsInGame then return end
    RecordedActions, RecordingStartTime = {}, tick()
    UpdateUIStatus("Recording 🔴", nil, 0, 0, 0)
end})

Tabs.Macro:AddButton({ Title = "⏹️ Stop Recording & Auto-Save", Callback = function()
    if MacroState.Status == "Recording 🔴" then
        UpdateUIStatus("Idle ⚪")
        local path = MacroFS.FolderName .. "/" .. MacroState.CurrentFile .. MacroFS.Extension
        if writefile then
            pcall(function() writefile(path, HttpService:JSONEncode({ Info = "Ultimate V7", Actions = RecordedActions })) end)
        end
    end
end})

local AutoPlayMacro = Tabs.Macro:AddToggle("AutoPlayMacro", { Title = "🟢 Auto Play Selected Macro", Default = false })
AutoPlayMacro:OnChanged(function(value)
    if IsBooting then return end
    if value then
        if MacroState.CurrentFile == "None" or not IsInGame then AutoPlayMacro:SetValue(false) return end
        UpdateUIStatus("Playing (Loop) 🟢")
        PlayMacro(true)
    else StopMacroPlayback() end
    TriggerSave()
end)

Tabs.Macro:AddButton({ Title = "▶️ Play Macro (Run Once)", Callback = function() if MacroState.CurrentFile ~= "None" and IsInGame then UpdateUIStatus("Playing (Once) ▶️") PlayMacro(false) end end})
Tabs.Macro:AddButton({ Title = "⏹️ Stop Macro", Callback = function() StopMacroPlayback() AutoPlayMacro:SetValue(false) end})

-- ============================================================================
-- 10. INGAME AUTOMATION
-- ============================================================================
task.spawn(function()
    while task.wait(0.2) do
        if IsInGame then
            if EnableAutoVote.Value then
                local vFrame = SafeFind(GetHUD(), "ModeVoteFrame")
                if IsVisible(vFrame) then ClickWithCooldown("Vote", SafeFind(vFrame, AutoVoteModeDropdown.Value, "TextButton"), 0.6) end
            end
            if AutoSkipWave.Value then
                local nVote = SafeFind(GetHUD(), "NextWaveVote")
                if IsVisible(nVote) then ClickWithCooldown("Skip", SafeFind(nVote, "YesButton") or FindActionButton(nVote, {"Yes"}), 0.35) end
            end
            if EnableEndMatchAutomation.Value then
                local mEnd = SafeFind(GetHUD(), "MissionEnd")
                if IsVisible(mEnd) then
                    local stat = ReadText(SafeFind(mEnd, "BG", "Status", "Status"))
                    local acts = SafeFind(mEnd, "BG", "Actions")
                    if acts then
                        if stat == "Failed!" and AutoRetryOnDefeat.Value then ClickWithCooldown("FailReplay", FindActionButton(acts, {"Replay"}), 0.15)
                        else
                            local btn = (EndMatchMode.Value == "Auto Next" and FindActionButton(acts, {"Next"})) or (EndMatchMode.Value == "Auto Replay" and FindActionButton(acts, {"Replay"})) or FindActionButton(acts, {"Return"})
                            ClickWithCooldown("EndMatch", btn, 0.45)
                        end
                    end
                end
            end
            local now = os.clock()
            if now - AutomationState.LastSpeedCheck > 2 and EnableAutoGameSpeed.Value then
                AutomationState.LastSpeedCheck = now
                task.spawn(function()
                    local speedLbl = SafeFind(GetHUD(), "FastForward", "TextLabel")
                    if speedLbl then
                        local cur, tar = tonumber(speedLbl.Text:match("%d+")) or 1, tonumber(SpeedMode.Value:match("%d+")) or 1
                        if cur ~= tar then pcall(function() InputRemote:FireServer("SpeedChange", cur < tar) end) end
                    end
                end)
            end
            if now - AutomationState.LastUpgradeSweep >= 1.5 and AutoUpgradeAll.Value and not Playback.Running then
                AutomationState.LastUpgradeSweep = now
                local folder = Workspace:FindFirstChild("Unit")
                if folder then for _, u in ipairs(folder:GetChildren()) do if not Playback.Running and AutoUpgradeAll.Value then pcall(function() ServerRemote:InvokeServer("Upgrade", u) end) task.wait(0.05) end end end
            end
        end
    end
end)

-- ============================================================================
-- 11. RECOVERY & HOOK
-- ============================================================================
LocalPlayer.Idled:Connect(function() if AntiAFK.Value then pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end) end end)

task.spawn(function()
    local prompt = CoreGui:WaitForChild("RobloxPromptGui"):WaitForChild("promptOverlay")
    prompt.ChildAdded:Connect(function(c) if AutoRejoin.Value and c.Name == "ErrorPrompt" then task.wait(2) pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end) end end)
end)

task.spawn(function()
    while task.wait(0.05) do
        if #ActionQueue > 0 and IsInGame then
            for _, a in ipairs(ActionQueue) do
                local cash = GetCurrentCash()
                if a.Type == "Summon" then
                    local cost = GetUnitCostFromName(a.Data.Unit)
                    if cash >= cost then a.Data.Cost = cost RecordAction("Summon", a.Data) end
                elseif a.Type == "Upgrade" then
                    local cost = GetUpgradeCostFromUI()
                    if cash >= cost and cost > 0 then RecordAction("Upgrade", { UnitName = a.Data.UnitInstance.Name, Position = {a.Data.UnitInstance:GetPivot().Position.X, a.Data.UnitInstance:GetPivot().Position.Y, a.Data.UnitInstance:GetPivot().Position.Z}, Cost = cost }) end
                elseif a.Type == "Sell" then RecordAction("Sell", { UnitName = a.Data.UnitInstance.Name, Position = {a.Data.UnitInstance:GetPivot().Position.X, a.Data.UnitInstance:GetPivot().Position.Y, a.Data.UnitInstance:GetPivot().Position.Z}, Cost = 0 }) end
            end
            ActionQueue = {}
        end
    end
end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    if MacroState.Status == "Recording 🔴" and not checkcaller() and IsInGame then
        local m, args = getnamecallmethod(), {...}
        if m == "FireServer" and self == InputRemote and args[1] == "Summon" and type(args[2]) == "table" and typeof(args[2].cframe) == "CFrame" then
            table.insert(ActionQueue, { Type = "Summon", Data = { Unit = tostring(args[2].Unit), Rotation = args[2].Rotation, CFrameData = CFrameToTable(args[2].cframe) } })
        elseif m == "InvokeServer" and self == ServerRemote and (args[1] == "Upgrade" or args[1] == "Sell") and typeof(args[2]) == "Instance" then
            table.insert(ActionQueue, { Type = args[1], Data = { UnitInstance = args[2] } })
        end
    end
    return oldNamecall(self, ...)
end)

-- ============================================================================
-- 12. MANAGERS, MOBILE UI & SMART TRIGGER
-- ============================================================================
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "NewMacroName", "ImportCodeInput", "ImportNameInput" })
SaveManager:SetFolder("AutoPlayHubPro/UltimateMacroV7")

InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder("AutoPlayHubPro")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FluentMobileIcon"
ScreenGui.Parent = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local ToggleBtn = Instance.new("ImageButton", ScreenGui)
ToggleBtn.Size, ToggleBtn.Position = UDim2.new(0, 50, 0, 50), UDim2.new(0.5, -25, 0, 10)
ToggleBtn.BackgroundColor3, ToggleBtn.Image = Color3.fromRGB(30, 30, 30), "rbxassetid://10886311090"
ToggleBtn.Active, ToggleBtn.Draggable = true, true
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
ToggleBtn.MouseButton1Click:Connect(function() Window:Minimize() end)

Window:SelectTab(1)
pcall(function() SaveManager:Load("SilentAutoSaveConfig") end)
Fluent:Notify({ Title = "V7 Master Loaded", Content = "Ultimate Hub V7 พร้อมใช้งาน!", Duration = 5 })

task.spawn(function()
    local t, e, inv = 10, 0, 0.5
    while e < t do
        if MacroState.CurrentFile ~= "None" and MacroState.CurrentFile ~= "" then break end
        task.wait(inv) e += inv
    end
    
    IsBooting = false 
    
    if AutoPlayMacro and AutoPlayMacro.Value == true then
        if MacroState.CurrentFile ~= "None" then
            if IsInGame then
                Fluent:Notify({ Title = "Auto Play Triggered", Content = "เริ่มลุยมาโคร...", Duration = 3 })
                UpdateUIStatus("Playing (Loop) 🟢")
                PlayMacro(true)
            else
                Fluent:Notify({ Title = "Lobby Mode", Content = "รันออโต้โหมดล็อบบี้ข้ามเวฟ", Duration = 3 })
            end
        else
            AutoPlayMacro:SetValue(false) 
        end
    end
end)
