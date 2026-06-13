-- ============================================================================
-- ULTIMATE MACRO SYSTEM (V5)
-- Architecture: Safe Action Queue + Smart Playback Engine + Automation QoL
-- Adds: Auto Vote, Auto Skip, End Match Automation, Auto Speed, Auto Upgrade,
--       Anti-AFK stubs/safety UI, Fluent SaveManager + InterfaceManager.
-- ============================================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

local InputRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Input")
local ServerRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Server")

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ============================================================================
-- 1. CORE STATE & VARIABLES
-- ============================================================================

local MacroState = {
    CurrentFile = "None",
    Status = "Idle",
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
    PositionTolerance = 4
}

local AutomationState = {
    LastClick = {},
    LastSpeedCheck = 0,
    LastUpgradeSweep = 0,
    AssumedSpeed = 1
}

-- ============================================================================
-- 2. FILE SYSTEM (MacroFS)
-- ============================================================================

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
        local success, result = pcall(function()
            return listfiles(MacroFS.FolderName)
        end)

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
    local emptyData = HttpService:JSONEncode({
        Info = "Ultimate Macro System V5",
        Actions = {}
    })

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

-- ============================================================================
-- 3. UTILITY & PARSING FUNCTIONS
-- ============================================================================

local function ParsePrice(value)
    if type(value) == "number" then
        return math.max(0, math.floor(value + 0.5))
    end

    if type(value) ~= "string" then
        return 0
    end

    local text = string.lower(value)
    text = text:gsub("[$,]", ""):gsub("%s+", "")

    local numberText, suffix = text:match("([%d%.]+)([kmbt]?)")
    local amount = tonumber(numberText)
    if not amount then return 0 end

    local multipliers = {
        k = 1000,
        m = 1000000,
        b = 1000000000,
        t = 1000000000000
    }

    return math.max(0, math.floor((amount * (multipliers[suffix] or 1)) + 0.5))
end

local function ReadText(instance)
    if instance and (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then
        return instance.Text
    end

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
    local ok, result = pcall(function()
        return instance and instance.Visible == true
    end)

    return ok and result or false
end

local function GetHUD()
    return LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("HUD")
end

local function GetCurrentWave()
    local ok, wave = pcall(function()
        local waveLabel = SafeFind(LocalPlayer.PlayerGui, "HUD", "Wave")
        return tonumber(ReadText(waveLabel):match("(%d+)")) or 0
    end)

    return ok and wave or 0
end

local function GetCurrentCash()
    local ok, cash = pcall(function()
        local cashLabel = SafeFind(LocalPlayer.PlayerGui, "HUD", "BottomFrame", "CurrencyList", "Cash")
        return ParsePrice(ReadText(cashLabel))
    end)

    return ok and cash or 0
end

local function GetTimeSinceRecording()
    if RecordingStartTime == 0 then return 0 end
    return math.max(0, tick() - RecordingStartTime)
end

local function CFrameToTable(cf)
    if typeof(cf) ~= "CFrame" then return nil end
    return {cf.X, cf.Y, cf.Z}
end

local function TableToCFrame(values)
    if type(values) ~= "table" or #values < 3 then return nil end
    return CFrame.new(values[1], values[2], values[3])
end

local function GetUnitCostFromName(targetUnitName)
    local unitsFolder = SafeFind(LocalPlayer.PlayerGui, "HUD", "BottomFrame", "Unit")
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
    local upgradeUI = SafeFind(LocalPlayer.PlayerGui, "HUD", "UpgradeV2", "Actions", "Upgrade", "Amount")
    return upgradeUI and ParsePrice(ReadText(upgradeUI)) or 0
end

local function GetUnitPosition(unitInstance)
    if typeof(unitInstance) ~= "Instance" then return nil end

    local ok, pivot = pcall(function()
        return unitInstance:GetPivot()
    end)

    if ok and typeof(pivot) == "CFrame" then
        return pivot.Position
    end

    if unitInstance:IsA("BasePart") then
        return unitInstance.Position
    end

    return nil
end

local function VirtualClick(button)
    if not button then return end

    if getconnections then
        pcall(function()
            for _, conn in ipairs(getconnections(button.MouseButton1Click)) do
                pcall(function()
                    conn:Fire()
                end)
            end
        end)

        pcall(function()
            for _, conn in ipairs(getconnections(button.Activated)) do
                pcall(function()
                    conn:Fire()
                end)
            end
        end)
    elseif firesignal then
        pcall(function()
            firesignal(button.MouseButton1Click)
        end)
        pcall(function()
            firesignal(button.Activated)
        end)
    end

    pcall(function()
        button:Activate()
    end)
end

local function ClickWithCooldown(key, button, cooldown)
    if not button then return false end

    local now = os.clock()
    if AutomationState.LastClick[key] and now - AutomationState.LastClick[key] < cooldown then
        return false
    end

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
            local lowerName = string.lower(descendant.Name)
            local lowerText = string.lower(ReadText(descendant))

            for _, name in ipairs(names) do
                local target = string.lower(name)
                if lowerName:find(target, 1, true) or lowerText:find(target, 1, true) then
                    return descendant
                end
            end
        end
    end

    return nil
end

-- ============================================================================
-- 4. UI CREATION & LOGIC
-- ============================================================================

local Window = Fluent:CreateWindow({
    Title = "AutoPlay Hub Pro",
    SubTitle = "Ultimate Macro V5",
    TabWidth = 160,
    Size = UDim2.fromOffset(620, 540),
    Acrylic = true,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Macro = Window:AddTab({Title = "Macro Engine", Icon = "play"}),
    Ingame = Window:AddTab({Title = "Ingame", Icon = "gamepad-2"}),
    Settings = Window:AddTab({Title = "Settings", Icon = "settings"})
}

Window:SelectTab(1)

-- Status Section
Tabs.Macro:AddSection("Status")
local StatusDisplay = Tabs.Macro:AddParagraph({
    Title = "Current Status",
    Content = "Loading..."
})

local function UpdateUIStatus(newState, newFile, newWave, newTime, newActions)
    MacroState.Status = newState or MacroState.Status
    MacroState.CurrentFile = newFile or MacroState.CurrentFile
    MacroState.CurrentWave = newWave or MacroState.CurrentWave
    MacroState.InGameTime = newTime or MacroState.InGameTime
    MacroState.ActionCount = newActions or MacroState.ActionCount

    StatusDisplay:SetDesc(string.format(
        "File: %s\nStatus: %s\nWave: %d\nIn-Game Time: %ds\nActions: %d",
        MacroState.CurrentFile,
        MacroState.Status,
        MacroState.CurrentWave,
        MacroState.InGameTime,
        MacroState.ActionCount
    ))
end

UpdateUIStatus()

-- File Management Section
Tabs.Macro:AddSection("File Management")
local NewMacroInput = Tabs.Macro:AddInput("NewMacroName", {
    Title = "New Macro Name",
    Placeholder = "Enter Text...",
    Finished = false
})

local MacroDropdown

Tabs.Macro:AddButton({
    Title = "Create & Select File",
    Callback = function()
        local fileName = NewMacroInput.Value
        if fileName ~= "" and MacroFS.CreateEmptyMacro(fileName) then
            Fluent:Notify({
                Title = "Success",
                Content = "Created macro file.",
                Duration = 3
            })

            MacroDropdown:SetValues(MacroFS.GetMacroFiles())
            MacroDropdown:SetValue(fileName)
            UpdateUIStatus(nil, fileName, nil, nil, 0)
        end
    end
})

MacroDropdown = Tabs.Macro:AddDropdown("SelectMacroFile", {
    Title = "Select / Load Macro File",
    Values = MacroFS.GetMacroFiles(),
    Multi = false,
    Default = 1
})

MacroDropdown:OnChanged(function(value)
    UpdateUIStatus(nil, value, nil, nil, nil)
end)

Tabs.Macro:AddButton({
    Title = "Refresh List",
    Callback = function()
        MacroDropdown:SetValues(MacroFS.GetMacroFiles())
    end
})

Tabs.Macro:AddButton({
    Title = "Delete Selected File",
    Callback = function()
        local selectedFile = MacroDropdown.Value
        if selectedFile ~= "None" and MacroFS.DeleteMacro(selectedFile) then
            Fluent:Notify({
                Title = "Deleted",
                Content = "Deleted macro file.",
                Duration = 3
            })

            MacroDropdown:SetValues(MacroFS.GetMacroFiles())
            MacroDropdown:SetValue("None")
            UpdateUIStatus(nil, "None", nil, nil, 0)
        end
    end
})

-- Automation Section
Tabs.Macro:AddSection("Auto Upgrade")
local AutoUpgradeAll = Tabs.Macro:AddToggle("AutoUpgradeAll", {
    Title = "Auto Upgrade All",
    Description = "Only runs when macro playback is not running.",
    Default = false
})

local AutoUpgradeDelay = Tabs.Macro:AddSlider("AutoUpgradeDelay", {
    Title = "Upgrade Sweep Delay",
    Description = "Seconds between upgrade sweeps.",
    Default = 1.25,
    Min = 0.25,
    Max = 5,
    Rounding = 2
})

-- Ingame Tab
Tabs.Ingame:AddSection("Main Options")
local SpeedMode = Tabs.Ingame:AddDropdown("SpeedMode", {
    Title = "Speed Mode",
    Values = {"Disabled", "1x", "2x", "3x"},
    Multi = false,
    Default = 1
})

local EndMatchMode = Tabs.Ingame:AddDropdown("EndMatchMode", {
    Title = "End Match Mode",
    Values = {"Auto Next", "Auto Replay", "Return to Lobby"},
    Multi = false,
    Default = 1
})

Tabs.Ingame:AddSection("Fail-Safe Recovery")
local AutoRetryOnDefeat = Tabs.Ingame:AddToggle("AutoRetryOnDefeat", {
    Title = "Auto Retry on Defeat",
    Default = true
})

Tabs.Ingame:AddSection("Match Progression")
local AutoSkipWave = Tabs.Ingame:AddToggle("AutoSkipWave", {
    Title = "Auto Skip Wave",
    Default = true
})

Tabs.Ingame:AddSection("Vote Mode")
local AutoVoteMode = Tabs.Ingame:AddToggle("AutoVoteMode", {
    Title = "Auto Vote Mode",
    Default = true
})

local VoteMode = Tabs.Ingame:AddDropdown("VoteMode", {
    Title = "Vote Choice",
    Values = {"Normal", "Extreme"},
    Multi = false,
    Default = 1
})

-- Settings Tab
Tabs.Settings:AddSection("Performance")
local AntiAFK = Tabs.Settings:AddToggle("AntiAFK", {
    Title = "Anti-AFK",
    Default = true
})

Tabs.Settings:AddSection("Safety & Recovery")
local AutoRejoin = Tabs.Settings:AddToggle("AutoRejoin", {
    Title = "Auto Rejoin",
    Description = "Stub toggle reserved for your rejoin implementation.",
    Default = false
})

local AutoExecute = Tabs.Settings:AddToggle("AutoExecute", {
    Title = "Auto Execute",
    Description = "Stub toggle reserved for executor-specific auto execution.",
    Default = false
})

Tabs.Settings:AddParagraph({
    Title = "Recovery Notes",
    Content = "Auto Rejoin and Auto Execute are UI-ready stubs so SaveManager can persist them. Add your executor-specific functions behind these toggles when needed."
})

-- ============================================================================
-- 5. PLAYBACK ENGINE (Logic & Replay)
-- ============================================================================

local function RecordAction(actionType, data)
    if MacroState.Status ~= "Recording" then return end

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
    UpdateUIStatus("Idle")
end

local function FindUnitForAction(data)
    local wantedName = data.UnitName or data.Unit
    local wantedPosition = data.Position and Vector3.new(data.Position[1], data.Position[2], data.Position[3])
    local bestUnit, bestDistance = nil, math.huge

    local unitFolder = Workspace:FindFirstChild("Unit") or Workspace
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

local PlaybackMode = Tabs.Macro:AddDropdown("PlaybackMode", {
    Title = "Playback Mode",
    Values = {"Strict Time", "Money + Time", "Action Based"},
    Multi = false,
    Default = 2
})

local function WaitForActionReady(action, playbackStartTime, token)
    local mode = PlaybackMode.Value
    local targetTime = tonumber(action.Timestamp or action.TimeInWave) or 0
    local targetWave = tonumber(action.Wave) or 0
    local targetCost = ParsePrice(action.Cost)

    if mode == "Strict Time" or mode == "Money + Time" then
        while Playback.Running and Playback.Token == token and (tick() - playbackStartTime < targetTime) do
            task.wait(0.1)
        end
    end

    if targetWave > 0 then
        while Playback.Running and Playback.Token == token and (GetCurrentWave() < targetWave) do
            task.wait(0.5)
        end
    end

    if mode == "Money + Time" and targetCost > 0 then
        while Playback.Running and Playback.Token == token and (GetCurrentCash() < targetCost) do
            task.wait(0.2)
        end
    end

    return Playback.Running and Playback.Token == token
end

local function PlayMacro(loopPlayback)
    if Playback.Running then
        StopMacroPlayback()
        task.wait(0.2)
    end

    local path = MacroFS.FolderName .. "/" .. MacroState.CurrentFile .. MacroFS.Extension
    if not (isfile and isfile(path) and readfile) then
        Fluent:Notify({
            Title = "Error",
            Content = "Macro file not found.",
            Duration = 3
        })
        return
    end

    local ok, result = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)

    if not ok or not result.Actions then
        Fluent:Notify({
            Title = "Error",
            Content = "Could not read macro actions.",
            Duration = 3
        })
        return
    end

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
                            pcall(function()
                                InputRemote:FireServer("Summon", {
                                    Rotation = data.Rotation or 0,
                                    cframe = cf,
                                    Unit = data.Unit
                                })
                            end)
                        end
                    elseif actionType == "Upgrade" then
                        local unit = FindUnitForAction(data)
                        if unit then
                            pcall(function()
                                ServerRemote:InvokeServer("Upgrade", unit)
                            end)
                        end
                    elseif actionType == "Sell" then
                        local unit = FindUnitForAction(data)
                        if unit then
                            pcall(function()
                                ServerRemote:InvokeServer("Sell", unit)
                            end)
                        end
                    end
                end

                UpdateUIStatus(nil, nil, GetCurrentWave(), math.floor(tick() - playbackStartTime), index)
                task.wait(0.1)
            end

            if loopPlayback and Playback.Token == token then
                task.wait(2)
            end
        until not loopPlayback or Playback.Token ~= token

        if Playback.Token == token then
            Playback.Running = false
            UpdateUIStatus("Idle")
        end
    end)
end

-- ============================================================================
-- 6. CONTROLS BINDING
-- ============================================================================

Tabs.Macro:AddSection("Controls")

Tabs.Macro:AddButton({
    Title = "Start Recording",
    Callback = function()
        if MacroState.CurrentFile == "None" then
            Fluent:Notify({
                Title = "Warning",
                Content = "Select a macro file first.",
                Duration = 3
            })
            return
        end

        RecordedActions = {}
        RecordingStartTime = tick()
        UpdateUIStatus("Recording", nil, 0, 0, 0)

        Fluent:Notify({
            Title = "Recording",
            Content = "Macro recording started.",
            Duration = 2
        })
    end
})

Tabs.Macro:AddButton({
    Title = "Stop Recording & Auto-Save",
    Callback = function()
        if MacroState.Status == "Recording" then
            UpdateUIStatus("Idle")

            local dataToSave = {
                Info = "Ultimate Macro System V5",
                TotalActions = #RecordedActions,
                Actions = RecordedActions
            }

            local path = MacroFS.FolderName .. "/" .. MacroState.CurrentFile .. MacroFS.Extension
            if writefile then
                local success = pcall(function()
                    writefile(path, HttpService:JSONEncode(dataToSave))
                end)

                if success then
                    Fluent:Notify({
                        Title = "Saved",
                        Content = "Saved " .. #RecordedActions .. " macro actions.",
                        Duration = 3
                    })
                end
            end
        end
    end
})

local AutoPlayMacro = Tabs.Macro:AddToggle("AutoPlayMacro", {
    Title = "Auto Play Selected Macro (Looping)",
    Default = false
})

AutoPlayMacro:OnChanged(function(value)
    if value then
        if MacroState.CurrentFile == "None" then
            AutoPlayMacro:SetValue(false)
            return
        end

        UpdateUIStatus("Playing (Loop)")
        PlayMacro(true)
    else
        StopMacroPlayback()
    end
end)

Tabs.Macro:AddButton({
    Title = "Play Macro (Run Once)",
    Callback = function()
        if MacroState.CurrentFile == "None" then return end
        UpdateUIStatus("Playing (Once)")
        PlayMacro(false)
    end
})

Tabs.Macro:AddButton({
    Title = "Stop Macro",
    Callback = function()
        StopMacroPlayback()
        AutoPlayMacro:SetValue(false)
    end
})

-- ============================================================================
-- 7. V5 AUTOMATION FEATURES
-- ============================================================================

local function RunAutoVote()
    if not AutoVoteMode.Value then return end

    local hud = GetHUD()
    local voteFrame = hud and hud:FindFirstChild("ModeVoteFrame")
    if not IsVisible(voteFrame) then return end

    local choice = VoteMode.Value == "Extreme" and "Extreme" or "Normal"
    local button = SafeFind(voteFrame, choice, "TextButton") or FindActionButton(voteFrame:FindFirstChild(choice), {"TextButton", choice})
    ClickWithCooldown("ModeVote_" .. choice, button, 0.6)
end

local function RunAutoSkipWave()
    if not AutoSkipWave.Value then return end

    local hud = GetHUD()
    local nextWaveVote = hud and hud:FindFirstChild("NextWaveVote")
    if not IsVisible(nextWaveVote) then return end

    local yesButton = nextWaveVote:FindFirstChild("YesButton") or FindActionButton(nextWaveVote, {"Yes", "YesButton"})
    ClickWithCooldown("NextWaveYes", yesButton, 0.35)
end

local function RunEndMatchAutomation()
    local hud = GetHUD()
    local missionEnd = hud and hud:FindFirstChild("MissionEnd")
    if not IsVisible(missionEnd) then return end

    local statusLabel = SafeFind(missionEnd, "BG", "Status", "Status")
    local statusText = ReadText(statusLabel)
    local actions = SafeFind(missionEnd, "BG", "Actions")

    if statusText == "Failed!" and AutoRetryOnDefeat.Value then
        local replayButton = FindActionButton(actions, {"Replay"})
        ClickWithCooldown("MissionEndReplayAggressive", replayButton, 0.15)
        return
    end

    local mode = EndMatchMode.Value
    local button

    if mode == "Auto Next" then
        button = FindActionButton(actions, {"Next", "AutoNext", "Continue"})
    elseif mode == "Auto Replay" then
        button = FindActionButton(actions, {"Replay"})
    elseif mode == "Return to Lobby" then
        button = FindActionButton(actions, {"Lobby", "Return", "ReturnToLobby"})
    end

    ClickWithCooldown("MissionEnd_" .. tostring(mode), button, 0.45)
end

local function ParseSpeedText(text)
    if type(text) ~= "string" then return nil end

    local direct = text:lower():match("([%d%.]+)%s*x")
    if direct then return tonumber(direct) end

    local afterWord = text:lower():match("speed[^%d]*([%d%.]+)")
    if afterWord then return tonumber(afterWord) end

    return nil
end

local function ReadGameSpeed()
    local attributeRoots = {ReplicatedStorage, Workspace, LocalPlayer}
    for _, root in ipairs(attributeRoots) do
        for _, attrName in ipairs({"GameSpeed", "Speed", "CurrentSpeed"}) do
            local value = root:GetAttribute(attrName)
            if tonumber(value) then
                return tonumber(value)
            end
        end
    end

    local hud = GetHUD()
    if hud then
        for _, descendant in ipairs(hud:GetDescendants()) do
            if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                local speed = ParseSpeedText(descendant.Text)
                if speed then
                    return speed
                end
            elseif (descendant:IsA("NumberValue") or descendant:IsA("IntValue")) and descendant.Name:lower():find("speed") then
                return tonumber(descendant.Value)
            end
        end
    end

    return nil
end

local function DesiredSpeed()
    local speed = tostring(SpeedMode.Value or ""):match("([%d%.]+)x")
    return tonumber(speed)
end

local function RunAutoGameSpeed()
    local desired = DesiredSpeed()
    if not desired then return end

    local current = ReadGameSpeed()
    if current then
        AutomationState.AssumedSpeed = current
    else
        current = AutomationState.AssumedSpeed or 1
    end

    if current + 0.05 < desired then
        pcall(function()
            InputRemote:FireServer("SpeedChange", true)
        end)
        AutomationState.AssumedSpeed = math.min(desired, current + 1)
    elseif current - 0.05 > desired then
        pcall(function()
            InputRemote:FireServer("SpeedChange", false)
        end)
        AutomationState.AssumedSpeed = math.max(desired, current - 1)
    end
end

local function RunAutoUpgradeAll()
    if not AutoUpgradeAll.Value then return end
    if Playback.Running == true then return end

    local unitFolder = Workspace:FindFirstChild("Unit")
    if not unitFolder then return end

    for _, unitInstance in ipairs(unitFolder:GetChildren()) do
        if Playback.Running == true or not AutoUpgradeAll.Value then
            break
        end

        pcall(function()
            ServerRemote:InvokeServer("Upgrade", unitInstance)
        end)

        task.wait(0.05)
    end
end

task.spawn(function()
    while task.wait(0.15) do
        pcall(RunAutoVote)
        pcall(RunAutoSkipWave)
        pcall(RunEndMatchAutomation)

        local now = os.clock()
        if now - AutomationState.LastSpeedCheck >= 1 then
            AutomationState.LastSpeedCheck = now
            pcall(RunAutoGameSpeed)
        end

        local upgradeDelay = tonumber(AutoUpgradeDelay.Value) or 1.25
        if now - AutomationState.LastUpgradeSweep >= upgradeDelay then
            AutomationState.LastUpgradeSweep = now
            pcall(RunAutoUpgradeAll)
        end
    end
end)

LocalPlayer.Idled:Connect(function()
    if not AntiAFK.Value then return end

    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- ============================================================================
-- 8. THE SAFE HOOK (ACTION QUEUE)
-- ============================================================================

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
                        Position = {
                            targetUnit:GetPivot().Position.X,
                            targetUnit:GetPivot().Position.Y,
                            targetUnit:GetPivot().Position.Z
                        },
                        Cost = GetUpgradeCostFromUI()
                    })
                elseif action.Type == "Sell" then
                    local targetUnit = action.Data.UnitInstance
                    RecordAction("Sell", {
                        UnitName = targetUnit.Name,
                        Position = {
                            targetUnit:GetPivot().Position.X,
                            targetUnit:GetPivot().Position.Y,
                            targetUnit:GetPivot().Position.Z
                        },
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

    if MacroState.Status == "Recording" and not checkcaller() then
        if method == "FireServer" and self == InputRemote then
            local commandType = args[1]
            if commandType == "Summon" and type(args[2]) == "table" and typeof(args[2].cframe) == "CFrame" then
                table.insert(ActionQueue, {
                    Type = "Summon",
                    Data = {
                        Unit = tostring(args[2].Unit),
                        Rotation = args[2].Rotation,
                        CFrameData = CFrameToTable(args[2].cframe)
                    }
                })
            end
        elseif method == "InvokeServer" and self == ServerRemote then
            local commandType = args[1]
            if (commandType == "Upgrade" or commandType == "Sell") and typeof(args[2]) == "Instance" then
                table.insert(ActionQueue, {
                    Type = commandType,
                    Data = {
                        UnitInstance = args[2]
                    }
                })
            end
        end
    end

    return oldNamecall(self, ...)
end)

-- ============================================================================
-- 9. FLUENT SAVE / INTERFACE MANAGERS
-- ============================================================================

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({
    "NewMacroName"
})

InterfaceManager:SetFolder("AutoPlayHubPro")
SaveManager:SetFolder("AutoPlayHubPro/UltimateMacroV5")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

Window:SelectTab(1)

Fluent:Notify({
    Title = "V5 Loaded",
    Content = "Ultimate Macro System V5 is running.",
    Duration = 5
})

-- ============================================================================
-- 10. AUTO EXECUTE (CROSS-SERVER PERSISTENCE)
-- ============================================================================
if AutoExecute and AutoExecute.Value then
    pcall(function()
        local queue_on_teleport = queue_on_teleport or syn.queue_on_teleport or queue_on_teleport
        if queue_on_teleport then
            -- สั่งให้ตัวรัน ดึงสคริปต์ URL นี้ไปรันซ้ำเมื่อมีการวาร์ปข้ามเซิร์ฟเวอร์
            queue_on_teleport('loadstring(game:HttpGet("https://raw.githubusercontent.com/qqunglnwza007-ops/Roblox/refs/heads/main/main.lua"))()')
        end
    end)
end
