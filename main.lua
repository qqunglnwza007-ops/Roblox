-- ============================================================================
-- 👑 ULTIMATE MACRO SYSTEM (V7.1.1) : MASTER EDITION
-- Architecture: Safe Action Queue + Smart Playback + QoL Automation
-- Updates: Auto-Execute, Smart Env Check, Mobile Icon, Real-Time Event Save
-- ============================================================================

-- 🚀 1. AUTO-EXECUTE ON TELEPORT (ฝังตัวข้ามแมพตั้งแต่เริ่ม)
if queue_on_teleport then
	local autoExecCode = [[
        task.wait(2)
        loadstring(game:HttpGet("https://raw.githubusercontent.com/qqunglnwza007-ops/Roblox/refs/heads/main/main.lua"))()
    ]]
	queue_on_teleport(autoExecCode)
end

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
local SaveManager =
	loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(
	game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua")
)()

-- ============================================================================
-- 2. CORE STATE & SMART ENVIRONMENT DETECTOR
-- ============================================================================
local MacroState = {
	CurrentFile = "None",
	Status = "Idle ⚪",
	CurrentWave = 0,
	InGameTime = 0,
	ActionCount = 0,
}

local RecordedActions = {}
local RecordingStartTime = 0

local ActionQueue = {}
local PendingSummons = {}
local PendingUpgrades = {}
local IsBooting = true -- [บล็อกระบบ] คุมการทำงานตอนรันสคริปต์ครั้งแรก
local IsInGame = false -- [ระบบแยก Lobby]

local Playback = { Running = false, Token = 0, PositionTolerance = 4 }
local AutomationState = {
	LastClick = {},
	LastUpgradeSweep = 0,
	LastSpeedCheck = 0,
}

local AutoBuffState = {
	HoshinoBuffed = false,
}

-- 🧭 กางโดเมนเช็คสภาพแวดล้อม (รอเช็ค UI Wave สูงสุด 15 วิ)
task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local maxWaitTime, elapsed = 15, 0
	while elapsed < maxWaitTime do
		local hud = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("HUD")
		if hud and hud:FindFirstChild("Wave").Visible then
			IsInGame = true
			print(
				"[System] บอสอยู่ในแมพต่อสู้! ปลดล็อกระบบ Macro..."
			)
			break
		end
		task.wait(1)
		elapsed = elapsed + 1
	end
	if not IsInGame then
		print(
			"[System] บอสอยู่ใน Lobby! ปิดระบบที่เกี่ยวกับการต่อสู้..."
		)
		MacroState.Status = "Lobby 🏕️"
	end
end)

-- 🛠️ ฟังก์ชัน Helper สำหรับ Real-Time Save
local function BindSave(uiElement)
	uiElement:OnChanged(function()
		if IsBooting then
			return
		end -- ป้องกันการเซฟมั่วตอนโหลดเข้าเกม
		pcall(function()
			SaveManager:Save("SilentAutoSaveConfig")
		end)
	end)
end

-- ============================================================================
-- 3. FILE SYSTEM (MacroFS) & UTILITIES
-- ============================================================================
local MacroFS = { FolderName = "TD_MasterMacros", Extension = ".json" }
if isfolder and not isfolder(MacroFS.FolderName) then
	makefolder(MacroFS.FolderName)
end

function MacroFS.GetMacroFiles()
	local files = { "None" }
	if listfiles then
		pcall(function()
			for _, path in ipairs(listfiles(MacroFS.FolderName)) do
				local fileName = string.match(path, "([^/\\]+)%.json$")
				if fileName then
					table.insert(files, fileName)
				end
			end
		end)
	end
	return #files > 1 and files or { "None" }
end

function MacroFS.CreateEmptyMacro(name)
	if name == "" or name == "None" then
		return false
	end
	if writefile then
		writefile(
			MacroFS.FolderName .. "/" .. name .. MacroFS.Extension,
			HttpService:JSONEncode({ Info = "Ultimate Macro V7.0", Actions = {} })
		)
		return true
	end
	return false
end

function MacroFS.DeleteMacro(name)
	if name == "" or name == "None" then
		return false
	end
	local path = MacroFS.FolderName .. "/" .. name .. MacroFS.Extension
	if isfile and isfile(path) and delfile then
		delfile(path)
		return true
	end
	return false
end

local function ParsePrice(value)
	if type(value) == "number" then
		return math.max(0, math.floor(value + 0.5))
	end
	if type(value) ~= "string" then
		return 0
	end
	local numberText, suffix = string.lower(value):gsub("[$,]", ""):gsub("%s+", ""):match("([%d%.]+)([kmbt]?)")
	local amount = tonumber(numberText)
	if not amount then
		return 0
	end
	local multipliers = { k = 1000, m = 1000000, b = 1000000000, t = 1000000000000 }
	return math.max(0, math.floor((amount * (multipliers[suffix] or 1)) + 0.5))
end

local function ReadText(instance)
	return (instance and (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")))
			and instance.Text
		or ""
end
local function SafeFind(root, ...)
	local current = root
	for _, name in ipairs({ ... }) do
		if not current then
			return nil
		end
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
		return tonumber(ReadText(SafeFind(LocalPlayer.PlayerGui, "HUD", "Wave")):match("(%d+)")) or 0
	end)
	return ok and wave or 0
end
local function GetCurrentCash()
	local ok, cash = pcall(function()
		return ParsePrice(ReadText(SafeFind(LocalPlayer.PlayerGui, "HUD", "BottomFrame", "CurrencyList", "Cash")))
	end)
	return ok and cash or 0
end
local function GetTimeSinceRecording()
	return RecordingStartTime == 0 and 0 or math.max(0, tick() - RecordingStartTime)
end
local function CFrameToTable(cf)
	return typeof(cf) == "CFrame" and { cf.X, cf.Y, cf.Z } or nil
end
local function TableToCFrame(values)
	return (type(values) == "table" and #values >= 3) and CFrame.new(values[1], values[2], values[3]) or nil
end

local function GetUnitCostFromName(targetUnitName)
	local unitsFolder = SafeFind(LocalPlayer.PlayerGui, "HUD", "BottomFrame", "Unit")
	if not unitsFolder then
		return 0
	end
	for _, slot in ipairs(unitsFolder:GetChildren()) do
		local unitObj = slot:FindFirstChild("Unit")
		if unitObj and unitObj:IsA("StringValue") and unitObj.Value == targetUnitName then
			return ParsePrice(
				ReadText(slot:FindFirstChild("ImageLabel") and slot.ImageLabel:FindFirstChild("TextLabel"))
			)
		end
	end
	return 0
end

local function GetUpgradeCostFromUI()
	local amount = SafeFind(LocalPlayer.PlayerGui, "HUD", "UpgradeV2", "Actions", "Upgrade", "Amount")
	return amount and ParsePrice(ReadText(amount)) or 0
end

local function GetUnitCount()
	local unitFolder = Workspace:FindFirstChild("Unit")

	if not unitFolder then
		return 0
	end

	return #unitFolder:GetChildren()
end

local function WaitForSummonSuccess(beforeCount, timeout)
	local startTime = tick()

	while tick() - startTime < timeout do
		if GetUnitCount() > beforeCount then
			return true
		end

		task.wait(0.1)
	end

	return false
end

local function WaitForUpgradeSuccess(unit, oldTag, timeout)
	local startTime = tick()

	while tick() - startTime < timeout do
		if not unit or not unit.Parent then
			return false
		end

		local tagObj = unit:FindFirstChild("UpgradeTag")

		if tagObj and tagObj.Value > oldTag then
			return true
		end

		task.wait(0.1)
	end

	return false
end

local function GetUnitPosition(unitInstance)
	if typeof(unitInstance) ~= "Instance" then
		return nil
	end
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
	if not button then
		return
	end
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
	if not button then
		return false
	end
	local now = os.clock()
	if AutomationState.LastClick[key] and now - AutomationState.LastClick[key] < cooldown then
		return false
	end
	AutomationState.LastClick[key] = now
	VirtualClick(button)
	return true
end

local function FindActionButton(actionsFrame, names)
	if not actionsFrame then
		return nil
	end
	for _, name in ipairs(names) do
		local button = actionsFrame:FindFirstChild(name)
		if button then
			return button
		end
	end
	for _, descendant in ipairs(actionsFrame:GetDescendants()) do
		if descendant:IsA("TextButton") or descendant:IsA("ImageButton") then
			local lowerName, lowerText = string.lower(descendant.Name), string.lower(ReadText(descendant))
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

local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function Base64Encode(data)
	return (
		(data:gsub(".", function(x)
			local r, b = "", x:byte()
			for i = 8, 1, -1 do
				r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0")
			end
			return r
		end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
			if #x < 6 then
				return ""
			end
			local c = 0
			for i = 1, 6 do
				c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0)
			end
			return b:sub(c + 1, c + 1)
		end) .. ({ "", "==", "=" })[#data % 3 + 1]
	)
end
local function Base64Decode(data)
	data = string.gsub(data, "[^" .. b .. "=]", "")
	return (
		data:gsub(".", function(x)
			if x == "=" then
				return ""
			end
			local r, f = "", (b:find(x) - 1)
			for i = 6, 1, -1 do
				r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
			end
			return r
		end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
			if #x ~= 8 then
				return ""
			end
			local c = 0
			for i = 1, 8 do
				c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
			end
			return string.char(c)
		end)
	)
end

-- ============================================================================
-- 4. BUILDING THE UI (V7.0 Clean Architecture + Real-Time Events)
-- ============================================================================
local Window = Fluent:CreateWindow({
	Title = "AutoPlay Hub Pro",
	SubTitle = "Ultimate Macro V7.0",
	TabWidth = 160,
	Size = UDim2.fromOffset(620, 500),
	Acrylic = true,
	Theme = "Darker",
	MinimizeKey = Enum.KeyCode.LeftControl,
})

local Tabs = {
	Ingame = Window:AddTab({ Title = "Ingame", Icon = "gamepad-2" }),
	Macro = Window:AddTab({ Title = "Macro Engine", Icon = "play" }),
	AutoBuff = Window:AddTab({ Title = "Auto Buff", Icon = "sparkles" }),
	Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
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
	StatusDisplay:SetDesc(
		string.format(
			"File: %s\nStatus: %s\nWave: %d\nIn-Game Time: %ds\nActions: %d",
			MacroState.CurrentFile,
			MacroState.Status,
			MacroState.CurrentWave,
			MacroState.InGameTime,
			MacroState.ActionCount
		)
	)
end
UpdateUIStatus()

Tabs.Macro:AddSection("File Management")
local NewMacroInput =
	Tabs.Macro:AddInput("NewMacroName", { Title = "New Macro Name", Placeholder = "Enter Text...", Finished = false })
local MacroDropdown

Tabs.Macro:AddButton({
	Title = "➕ Create & Select File",
	Callback = function()
		local fileName = NewMacroInput.Value
		if fileName ~= "" and MacroFS.CreateEmptyMacro(fileName) then
			Fluent:Notify({
				Title = "Success",
				Content = "สร้างไฟล์สำเร็จ!",
				Duration = 3,
			})
			MacroDropdown:SetValues(MacroFS.GetMacroFiles())
			MacroDropdown:SetValue(fileName)
			UpdateUIStatus(nil, fileName, nil, nil, 0)
		end
	end,
})
MacroDropdown = Tabs.Macro:AddDropdown(
	"SelectMacroFile",
	{ Title = "📂 Select / Load Macro File", Values = MacroFS.GetMacroFiles(), Multi = false, Default = 1 }
)
MacroDropdown:OnChanged(function(value)
	UpdateUIStatus(nil, value, nil, nil, nil)
end)
Tabs.Macro:AddButton({
	Title = "🔄 Refresh List",
	Callback = function()
		MacroDropdown:SetValues(MacroFS.GetMacroFiles())
	end,
})
Tabs.Macro:AddButton({
	Title = "🗑️ Delete Selected File",
	Callback = function()
		if MacroDropdown.Value ~= "None" and MacroFS.DeleteMacro(MacroDropdown.Value) then
			Fluent:Notify({
				Title = "Deleted",
				Content = "ลบไฟล์มาโครสำเร็จ!",
				Duration = 3,
			})
			MacroDropdown:SetValues(MacroFS.GetMacroFiles())
			MacroDropdown:SetValue("None")
			UpdateUIStatus(nil, "None", nil, nil, 0)
		end
	end,
})
Tabs.Macro:AddButton({
	Title = "📤 Export Selected Macro",
	Callback = function()
		if MacroDropdown.Value == "None" then
			return Fluent:Notify({
				Title = "Error",
				Content = "เลือกไฟล์ก่อน Export!",
				Duration = 3,
			})
		end
		local path = MacroFS.FolderName .. "/" .. MacroDropdown.Value .. MacroFS.Extension
		if isfile(path) then
			if setclipboard then
				setclipboard("TDMACRO_" .. Base64Encode(readfile(path)))
				Fluent:Notify({
					Title = "Exported!",
					Content = "ก๊อปปี้โค้ดมาโครแล้ว!",
					Duration = 5,
				})
			else
				Fluent:Notify({
					Title = "Error",
					Content = "ตัวรันไม่รองรับก๊อปปี้",
					Duration = 3,
				})
			end
		end
	end,
})

local ImportCodeInput = Tabs.Macro:AddInput(
	"ImportCodeInput",
	{
		Title = "📥 Paste Macro Code",
		Placeholder = "วางโค้ด TDMACRO_ ที่นี่...",
		Finished = false,
	}
)
local ImportNameInput = Tabs.Macro:AddInput(
	"ImportNameInput",
	{
		Title = "✏️ New Macro Name",
		Placeholder = "ตั้งชื่อไฟล์ใหม่...",
		Finished = false,
	}
)
Tabs.Macro:AddButton({
	Title = "💾 Import & Save Macro",
	Callback = function()
		local code, newName = ImportCodeInput.Value, ImportNameInput.Value
		if code == "" or newName == "" then
			return Fluent:Notify({
				Title = "Error",
				Content = "กรอกข้อมูลให้ครบ!",
				Duration = 3,
			})
		end
		if not string.find(code, "^TDMACRO_") then
			return Fluent:Notify({
				Title = "Error",
				Content = "โค้ดมาโครไม่ถูกต้อง!",
				Duration = 3,
			})
		end
		local success, decodedData = pcall(function()
			return Base64Decode(string.gsub(code, "TDMACRO_", ""))
		end)
		if success and decodedData and string.find(decodedData, "Actions") then
			if writefile then
				writefile(MacroFS.FolderName .. "/" .. newName .. MacroFS.Extension, decodedData)
				Fluent:Notify({
					Title = "Success!",
					Content = "นำเข้าไฟล์สำเร็จ!",
					Duration = 4,
				})
				MacroDropdown:SetValues(MacroFS.GetMacroFiles())
				MacroDropdown:SetValue(newName)
				UpdateUIStatus(nil, newName, nil, nil, 0)
			end
		end
	end,
})

Tabs.Macro:AddSection("Controls")
local PlaybackMode = Tabs.Macro:AddDropdown(
	"PlaybackMode",
	{
		Title = "⚙️ Playback Mode",
		Values = { "Strict Time", "Money + Time", "Action Based" },
		Multi = false,
		Default = 2,
	}
)
BindSave(PlaybackMode)
local AutoUpgradeAll = Tabs.Macro:AddToggle("AutoUpgradeAll", { Title = "⬆️ Auto Upgrade All", Default = false })
BindSave(AutoUpgradeAll)

-- ---------------- [ TAB 2: INGAME ] ----------------
Tabs.Ingame:AddSection("🕹️ Main Options")
local SpeedMode = Tabs.Ingame:AddDropdown(
	"SpeedMode",
	{ Title = "⏩ Speed Mode", Values = { "1x", "2x", "3x" }, Multi = false, Default = 1 }
)
BindSave(SpeedMode)
local EnableAutoGameSpeed =
	Tabs.Ingame:AddToggle("EnableAutoGameSpeed", { Title = "✅ Enable Auto GameSpeed", Default = false })
BindSave(EnableAutoGameSpeed)
local EndMatchMode = Tabs.Ingame:AddDropdown(
	"EndMatchMode",
	{
		Title = "🔚 End Match Mode",
		Values = { "Auto Next", "Auto Replay", "Return to Lobby" },
		Multi = false,
		Default = 1,
	}
)
BindSave(EndMatchMode)

Tabs.Ingame:AddSection("♻️ Fail-Safe Recovery")
local AutoRetryOnDefeat =
	Tabs.Ingame:AddToggle("AutoRetryOnDefeat", { Title = "💔 Auto Retry on Defeat", Default = true })
BindSave(AutoRetryOnDefeat)

Tabs.Ingame:AddSection("📈 Match Progression")
local AutoSkipWave = Tabs.Ingame:AddToggle("AutoSkipWave", { Title = "⏭️ Auto Skip Wave", Default = false })
BindSave(AutoSkipWave)
local EnableEndMatchAutomation =
	Tabs.Ingame:AddToggle("EnableEndMatchAutomation", { Title = "🤖 Enable End Match Automation", Default = false })
BindSave(EnableEndMatchAutomation)

Tabs.Ingame:AddSection("🗳️ Vote Mode")
local AutoVoteModeDropdown = Tabs.Ingame:AddDropdown(
	"AutoVoteModeDropdown",
	{ Title = "🎯 Auto Vote Mode", Values = { "Normal", "Extreme" }, Multi = false, Default = 1 }
)
BindSave(AutoVoteModeDropdown)
local EnableAutoVote = Tabs.Ingame:AddToggle("EnableAutoVote", { Title = "✅ Enable Auto Vote", Default = false })
BindSave(EnableAutoVote)

-- ---------------- [ TAB 3: AUTO BUFF ] ----------------

Tabs.AutoBuff:AddSection("📣 Hoshino")

local AutoBuffHoshino = Tabs.AutoBuff:AddToggle("AutoBuffHoshino", {
	Title = "💫 Auto Buff Hoshino",
	Default = false,
})

BindSave(AutoBuffHoshino)

-- ---------------- [ TAB 4: SETTINGS ] ----------------

Tabs.Settings:AddSection("⚡ Performance")
local AntiAFK = Tabs.Settings:AddToggle("AntiAFK", { Title = "🏃‍♂️ Anti-AFK", Default = true })
BindSave(AntiAFK)
local AutoRejoin = Tabs.Settings:AddToggle("AutoRejoin", { Title = "🔄 Auto Rejoin on Kick", Default = false })
BindSave(AutoRejoin)

-- ============================================================================
-- 5. PLAYBACK ENGINE
-- ============================================================================
local function RecordAction(actionType, data)
	if MacroState.Status ~= "Recording 🔴" or not IsInGame then
		return
	end
	local currentWave, timestamp = GetCurrentWave(), GetTimeSinceRecording()
	local actionEntry = {
		ActionType = actionType,
		Wave = currentWave,
		TimeInWave = timestamp,
		Timestamp = timestamp,
		Cost = ParsePrice(data.Cost or 0),
		Data = data,
	}
	table.insert(RecordedActions, actionEntry)
	UpdateUIStatus(nil, nil, currentWave, math.floor(timestamp), #RecordedActions)
end

local function StopMacroPlayback()
	Playback.Token += 1
	Playback.Running = false
	if IsInGame then
		UpdateUIStatus("Idle ⚪")
	end
end

local function FindUnitForAction(data)
	local wantedName = data.UnitName or data.Unit

	local wantedPosition = data.Position and Vector3.new(data.Position[1], data.Position[2], data.Position[3])

	local wantedUpgradeTag = tonumber(data.UpgradeTag)

	local bestUnit = nil
	local bestDistance = math.huge

	local unitFolder = Workspace:FindFirstChild("Unit")

	if not unitFolder then
		return nil
	end

	for _, candidate in ipairs(unitFolder:GetChildren()) do
		if candidate.Name == wantedName then
			if wantedUpgradeTag ~= nil then
				local tagObj = candidate:FindFirstChild("UpgradeTag")

				local candidateTag = tagObj and tagObj.Value or nil

				if candidateTag ~= wantedUpgradeTag then
					continue
				end
			end

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

	if bestUnit then
		return bestUnit
	end

	for _, candidate in ipairs(unitFolder:GetChildren()) do
		if candidate.Name == wantedName then
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

local function WaitForActionReady(action, playbackStartTime, token)
	local mode, targetTime, targetWave, targetCost =
		PlaybackMode.Value,
		tonumber(action.Timestamp or action.TimeInWave) or 0,
		tonumber(action.Wave) or 0,
		ParsePrice(action.Cost)
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
	if not IsInGame then
		return
	end
	if Playback.Running then
		StopMacroPlayback()
		task.wait(0.2)
	end
	local path = MacroFS.FolderName .. "/" .. MacroState.CurrentFile .. MacroFS.Extension
	if not isfile(path) then
		Fluent:Notify({ Title = "Error", Content = "หาไฟล์ไม่เจอ!", Duration = 3 })
		return
	end
	local ok, result = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok or not result.Actions then
		return
	end

	local actions = result.Actions
	Playback.Running = true
	Playback.Token += 1
	local token = Playback.Token

	task.spawn(function()
		local playbackStartTime = tick()
		for index, action in ipairs(actions) do
			if Playback.Token ~= token or not Playback.Running then
				break
			end
			UpdateUIStatus(nil, nil, GetCurrentWave(), math.floor(tick() - playbackStartTime), index - 1)
			if WaitForActionReady(action, playbackStartTime, token) then
				local actionType, data = action.ActionType, action.Data
				if actionType == "Summon" then
					local cf = TableToCFrame(data.CFrameData or data.CFrame)

					if cf then
						local success = false

						for retry = 1, 3 do
							local beforeCount = GetUnitCount()

							pcall(function()
								InputRemote:FireServer("Summon", {
									Rotation = data.Rotation or 0,

									cframe = cf,

									Unit = data.Unit,
								})
							end)

							if WaitForSummonSuccess(beforeCount, 2) then
								success = true
								break
							end
						end

						if not success then
							warn("[Macro] Summon Failed:", tostring(data.Unit))
						end
					end
					local cf = TableToCFrame(data.CFrameData or data.CFrame)
					if cf then
						pcall(function()
							InputRemote:FireServer(
								"Summon",
								{ Rotation = data.Rotation or 0, cframe = cf, Unit = data.Unit }
							)
						end)
					end
				elseif actionType == "Upgrade" then
					local unit = FindUnitForAction(data)

					if unit then
						local success = false

						for retry = 1, 3 do
							local tagObj = unit:FindFirstChild("UpgradeTag")

							local oldTag = tagObj and tagObj.Value or 0

							pcall(function()
								ServerRemote:InvokeServer("Upgrade", unit)
							end)

							if WaitForUpgradeSuccess(unit, oldTag, 2) then
								success = true
								break
							end
						end

						if not success then
							warn("[Macro] Upgrade Failed:", unit.Name)
						end
					end
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
		if Playback.Token == token then
			Playback.Running = false
			UpdateUIStatus("Idle ⚪")
		end
	end)
end

-- ============================================================================
-- 6. CONTROLS BINDING
-- ============================================================================
Tabs.Macro:AddButton({
	Title = "🔴 Start Recording",
	Callback = function()
		if not IsInGame then
			Fluent:Notify({
				Title = "Warning",
				Content = "อัดมาโครได้เฉพาะในเกมเท่านั้น!",
				Duration = 3,
			})
			return
		end
		if MacroState.CurrentFile == "None" then
			Fluent:Notify({
				Title = "Warning",
				Content = "เลือกไฟล์ก่อนอัด!",
				Duration = 3,
			})
			return
		end
		RecordedActions, RecordingStartTime = {}, tick()
		UpdateUIStatus("Recording 🔴", nil, 0, 0, 0)
		Fluent:Notify({
			Title = "Recording...",
			Content = "เริ่มบันทึกมาโครแล้ว!",
			Duration = 2,
		})
	end,
})

Tabs.Macro:AddButton({
	Title = "⏹️ Stop Recording & Auto-Save",
	Callback = function()
		if MacroState.Status == "Recording 🔴" then
			UpdateUIStatus("Idle ⚪")
			if writefile then
				pcall(function()
					writefile(
						MacroFS.FolderName .. "/" .. MacroState.CurrentFile .. MacroFS.Extension,
						HttpService:JSONEncode({
							Info = "Ultimate Macro System V7.0",
							TotalActions = #RecordedActions,
							Actions = RecordedActions,
						})
					)
				end)
				Fluent:Notify({
					Title = "Saved",
					Content = "เซฟมาโคร " .. #RecordedActions .. " แอคชั่น",
					Duration = 3,
				})
			end
		end
	end,
})

local AutoPlayMacro =
	Tabs.Macro:AddToggle("AutoPlayMacro", { Title = "🟢 Auto Play Selected Macro (Looping)", Default = false })
BindSave(AutoPlayMacro)

AutoPlayMacro:OnChanged(function(value)
	if IsBooting then
		return
	end
	if value then
		if not IsInGame or MacroState.CurrentFile == "None" then
			warn("WHO TURNED OFF AUTOPLAY?")
warn(debug.traceback())
			return
		end
		UpdateUIStatus("Playing (Loop) 🟢")
		PlayMacro(true)
	else
		StopMacroPlayback()
	end
end)

Tabs.Macro:AddButton({
	Title = "▶️ Play Macro (Run Once)",
	Callback = function()
		if MacroState.CurrentFile ~= "None" and IsInGame then
			UpdateUIStatus("Playing (Once) ▶️")
			PlayMacro(false)
		end
	end,
})

Tabs.Macro:AddButton({
	Title = "⏹️ Stop Macro",
	Callback = function()
		StopMacroPlayback()
		AutoPlayMacro:SetValue(false)
	end,
})

-- ============================================================================
-- 7. INGAME AUTOMATION FEATURES
-- ============================================================================
local function RunAutoVote()
	if EnableAutoVote.Value and IsVisible(SafeFind(GetHUD(), "ModeVoteFrame")) then
		ClickWithCooldown(
			"ModeVote_" .. AutoVoteModeDropdown.Value,
			SafeFind(GetHUD(), "ModeVoteFrame", AutoVoteModeDropdown.Value, "TextButton"),
			0.6
		)
	end
end
local function RunAutoSkipWave()
	if AutoSkipWave.Value and IsVisible(SafeFind(GetHUD(), "NextWaveVote")) then
		ClickWithCooldown(
			"NextWaveYes",
			SafeFind(GetHUD(), "NextWaveVote", "YesButton")
				or FindActionButton(SafeFind(GetHUD(), "NextWaveVote"), { "Yes", "YesButton" }),
			0.35
		)
	end
end
local function RunEndMatchAutomation()
	if not EnableEndMatchAutomation.Value then
		return
	end
	local missionEnd = SafeFind(GetHUD(), "MissionEnd")
	if not IsVisible(missionEnd) then
		return
	end
	local actions = SafeFind(missionEnd, "BG", "Actions")
	if not actions then
		return
	end
	if ReadText(SafeFind(missionEnd, "BG", "Status", "Status")) == "Failed!" and AutoRetryOnDefeat.Value then
		ClickWithCooldown("MissionEndReplayAggressive", FindActionButton(actions, { "Replay" }), 0.15)
		return
	end
	local mode = EndMatchMode.Value
	ClickWithCooldown(
		"MissionEnd_" .. tostring(mode),
		(mode == "Auto Next" and FindActionButton(actions, { "Next" }))
			or (mode == "Auto Replay" and FindActionButton(actions, { "Replay" }))
			or (mode == "Return to Lobby" and FindActionButton(actions, { "Return" })),
		0.45
	)
end

local function HandleAutoSpeed()
	if not EnableAutoGameSpeed.Value then
		return
	end
	local speedLabel = SafeFind(GetHUD(), "FastForward", "TextLabel")
	local inputRemote = SafeFind(ReplicatedStorage, "Remotes", "Input")
	if speedLabel and inputRemote then
		task.spawn(function()
			local currentSpeed, targetSpeed =
				tonumber(string.match(speedLabel.Text, "%d+")) or 1, tonumber(string.match(SpeedMode.Value, "%d+")) or 1
			if currentSpeed < targetSpeed then
				inputRemote:FireServer("SpeedChange", true)
				task.wait(0.5)
			elseif currentSpeed > targetSpeed then
				inputRemote:FireServer("SpeedChange", false)
				task.wait(0.5)
			end
		end)
	end
end

local function RunAutoBuffHoshino()
	if not AutoBuffHoshino.Value then
		AutoBuffState.HoshinoBuffed = false
		return
	end

	local unitFolder = Workspace:FindFirstChild("Unit")
	if not unitFolder then
		return
	end

	local hoshino = unitFolder:FindFirstChild("Hoshino")

	if not hoshino then
		AutoBuffState.HoshinoBuffed = false
		return
	end

	local autoState = hoshino:GetAttribute("Auto")

	if autoState == true then
		AutoBuffState.HoshinoBuffed = true
		return
	end

	if AutoBuffState.HoshinoBuffed then
		return
	end

	AutoBuffState.HoshinoBuffed = true

	task.spawn(function()
		pcall(function()
			InputRemote:FireServer("AutoToggle", hoshino, true)
		end)
	end)
end

local function RunAutoUpgradeAll()
	if not AutoUpgradeAll.Value or Playback.Running == true then
		return
	end
	local unitFolder = Workspace:FindFirstChild("Unit")
	if unitFolder then
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
end

task.spawn(function()
	while task.wait(0.2) do
		if IsInGame then -- ดักลอจิกให้ทำงานแค่ตอนอยู่ในด่าน
			pcall(RunAutoVote)
			pcall(RunAutoSkipWave)
			pcall(RunEndMatchAutomation)
			pcall(RunAutoBuffHoshino)
			local now = os.clock()
			if now - AutomationState.LastSpeedCheck > 2 then
				AutomationState.LastSpeedCheck = now
				pcall(HandleAutoSpeed)
			end
			if now - AutomationState.LastUpgradeSweep >= 1.5 then
				AutomationState.LastUpgradeSweep = now
				pcall(RunAutoUpgradeAll)
			end
		end
	end
end)

-- ============================================================================
-- 8. SAFETY & HOOKS
-- ============================================================================
LocalPlayer.Idled:Connect(function()
	if AntiAFK.Value then
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end
end)
task.spawn(function()
	CoreGui:WaitForChild("RobloxPromptGui"):WaitForChild("promptOverlay").ChildAdded:Connect(function(child)
		if AutoRejoin.Value and child.Name == "ErrorPrompt" then
			task.wait(2)
			pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
			end)
		end
	end)
end)

local function ProcessPendingUpgrades()
	if #PendingUpgrades == 0 then
		return
	end

	for i = #PendingUpgrades, 1, -1 do
		local entry = PendingUpgrades[i]

		local unit = entry.UnitInstance

		if not unit or not unit.Parent then
			table.remove(PendingUpgrades, i)

			continue
		end

		local tagObj = unit:FindFirstChild("UpgradeTag")

		local currentTag = tagObj and tagObj.Value or 0

		if currentTag > entry.OldTag then
			table.insert(ActionQueue, {
				Type = "Upgrade",

				Data = {
					UnitInstance = unit,
				},
			})

			table.remove(PendingUpgrades, i)
		elseif tick() - entry.CreatedAt >= 3 then
			table.remove(PendingUpgrades, i)
		end
	end
end

local function ProcessPendingSummons()
	if #PendingSummons == 0 then
		return
	end

	local currentCount = GetUnitCount()

	for i = #PendingSummons, 1, -1 do
		local summon = PendingSummons[i]

		if currentCount > summon.BeforeCount then
			RecordAction("Summon", {
				Unit = summon.Unit,
				Rotation = summon.Rotation,
				CFrameData = summon.CFrameData,
				UpgradeTag = 0,
			})

			table.remove(PendingSummons, i)
		elseif tick() - summon.CreatedAt >= 3 then
			table.remove(PendingSummons, i)
		end
	end
end

task.spawn(function()
	while task.wait(0.05) do
		pcall(ProcessPendingSummons)
		pcall(ProcessPendingUpgrades)

		if #ActionQueue > 0 then
			for _, action in ipairs(ActionQueue) do
				local currentCash = GetCurrentCash()
				if action.Type == "Summon" then
					local cost = GetUnitCostFromName(action.Data.Unit)
					if currentCash >= cost then
						action.Data.Cost = cost
						RecordAction("Summon", action.Data)
					else
						Fluent:Notify({
							Title = "Skipped",
							Content = "เงินไม่พอวาง!",
							Duration = 2,
						})
					end
				elseif action.Type == "Upgrade" then
					local targetUnit, cost = action.Data.UnitInstance, GetUpgradeCostFromUI()
					if currentCash >= cost and cost > 0 then
						RecordAction("Upgrade", {
							UnitName = targetUnit.Name,

							Position = {
								targetUnit:GetPivot().Position.X,
								targetUnit:GetPivot().Position.Y,
								targetUnit:GetPivot().Position.Z,
							},

							UpgradeTag = targetUnit:FindFirstChild("UpgradeTag") and targetUnit.UpgradeTag.Value or 0,

							Cost = cost,
						})
					end
				elseif action.Type == "Sell" then
					RecordAction("Sell", {
						UnitName = action.Data.UnitInstance.Name,

						Position = {
							action.Data.UnitInstance:GetPivot().Position.X,
							action.Data.UnitInstance:GetPivot().Position.Y,
							action.Data.UnitInstance:GetPivot().Position.Z,
						},

						UpgradeTag = action.Data.UnitInstance:FindFirstChild("UpgradeTag")
								and action.Data.UnitInstance.UpgradeTag.Value
							or 0,

						Cost = 0,
					})
				end
			end
			ActionQueue = {}
		end
	end
end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
	local method, args = getnamecallmethod(), { ... }
	if MacroState.Status == "Recording 🔴" and IsInGame and not checkcaller() then
		if
			method == "FireServer"
			and self == InputRemote
			and args[1] == "Summon"
			and type(args[2]) == "table"
			and typeof(args[2].cframe) == "CFrame"
		then
			table.insert(
				ActionQueue,
				{
					Type = "Summon",
					Data = {
						Unit = tostring(args[2].Unit),
						Rotation = args[2].Rotation,
						CFrameData = CFrameToTable(args[2].cframe),
					},
				}
			)
		elseif
			method == "InvokeServer"
			and self == ServerRemote
			and args[1] == "Upgrade"
			and typeof(args[2]) == "Instance"
		then
			local targetUnit = args[2]

			local upgradeTag = targetUnit:FindFirstChild("UpgradeTag")

			table.insert(PendingUpgrades, {
				UnitInstance = targetUnit,

				OldTag = upgradeTag and upgradeTag.Value or 0,

				CreatedAt = tick(),
			})
		elseif
			method == "InvokeServer"
			and self == ServerRemote
			and args[1] == "Sell"
			and typeof(args[2]) == "Instance"
		then
			table.insert(ActionQueue, {
				Type = "Sell",
				Data = {
					UnitInstance = args[2],
				},
			})
		end
	end
	return oldNamecall(self, ...)
end)

-- ============================================================================
-- 9. MOBILE ICON & INTERFACE MANAGER
-- ============================================================================
InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder("AutoPlayHubPro")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FluentMobileIcon"
ScreenGui.Parent = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local ToggleButton = Instance.new("ImageButton")
ToggleButton.Parent = ScreenGui
ToggleButton.Size = UDim2.new(0, 50, 0, 50)
ToggleButton.Position = UDim2.new(0.5, -25, 0, 10)
ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ToggleButton.Image = "rbxassetid://10886311090"
ToggleButton.Active = true
ToggleButton.Draggable = true
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(1, 0)
UICorner.Parent = ToggleButton

ToggleButton.MouseButton1Click:Connect(function()
	Window:Minimize()
end)

-- ============================================================================
-- 10. REAL-TIME SAVE SYSTEM & BOOTSTRAP
-- ============================================================================
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "NewMacroName" })
SaveManager:SetFolder("AutoPlayHubPro/UltimateMacroV5")

pcall(function()
	SaveManager:Load("SilentAutoSaveConfig")
end)
Window:SelectTab(1)

-- Smart Trigger ปลดล็อกระบบ Boot
task.spawn(function()
	local timeout, elapsed, checkInterval = 10, 0, 0.5
	while elapsed < timeout do
		if MacroState.CurrentFile ~= "None" and MacroState.CurrentFile ~= "" then
			break
		end
		task.wait(checkInterval)
		elapsed = elapsed + checkInterval
	end

	IsBooting = false -- ปลดล็อกระบบเซฟและ UI

	if AutoPlayMacro and AutoPlayMacro.Value == true then
		if MacroState.CurrentFile ~= "None" and IsInGame then
			Fluent:Notify({
				Title = "Auto Play Triggered",
				Content = "เริ่มลุยมาโคร...",
				Duration = 3,
			})
			UpdateUIStatus("Playing (Loop) 🟢")
			PlayMacro(true)
		else
			warn("WHO TURNED OFF AUTOPLAY?")
warn(debug.traceback())
		end
	end
end)

Fluent:Notify({
	Title = "V7.0 Loaded",
	Content = "ระบบรันเสร็จสมบูรณ์!",
	Duration = 5,
})
