-- ==========================================
-- 🟢 1. โหลด Services และ Libraries
-- ==========================================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ==========================================
-- ⚙️ 2. ตั้งค่าตัวละคร (Configuration)
-- ==========================================

local HillUnits = {
    ["Bulma"] = true,
    ["AsNodt"] = true,
    -- ใส่ชื่อตัวละครที่ต้องวางบนเนินตรงนี้
}
local MaxUnitLimits = {
    ["Bulma"] = 1,
    ["Hoshino"] = 1,
    -- ["ชื่อตัวละคร"] = จำนวนสูงสุดที่ให้วาง
}
local DEFAULT_MAX_LIMIT = 8

-- ==========================================
-- 🖥️ 3. สร้าง UI (Fluent UI)
-- ==========================================
local Window = Fluent:CreateWindow({
    Title = "AutoPlay Hub",
    SubTitle = "Tower Defense",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true, 
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

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

-- [ แท็บ Ingame ]
Tabs.Ingame:AddSection("Main Options")
local SpeedMode = Tabs.Ingame:AddDropdown("SpeedMode", { Title = "Speed Mode", Values = {"1x", "2x", "3x"}, Multi = false, Default = 1 })
local EnableAutoGameSpeed = Tabs.Ingame:AddToggle("EnableAutoGameSpeed", { Title = "Enable Auto GameSpeed", Default = false })
local EndMatchMode = Tabs.Ingame:AddDropdown("EndMatchMode", { Title = "End Match Mode", Values = {"Auto Next", "Auto Replay", "Reurn Lobby"}, Multi = false, Default = 2 })

Tabs.Ingame:AddSection("Auto Leave Match")
local EnablePullBackToLobby = Tabs.Ingame:AddToggle("EnablePullBackToLobby", { Title = "Enable Pull Back to Lobby", Default = false })
local AutoLeaveWave = Tabs.Ingame:AddInput("AutoLeaveWave", { Title = "Auto Leave Game at Wave", Default = "50", Numeric = true, Finished = false })

Tabs.Ingame:AddSection("Match Progression")
local AutoSkipWave = Tabs.Ingame:AddToggle("AutoSkipWave", { Title = "Auto Skip Wave (Vote Skip)", Default = false })
local EnableEndMatchAutomation = Tabs.Ingame:AddToggle("EnableEndMatchAutomation", { Title = "Enable End Match Automation", Default = false })

Tabs.Ingame:AddSection("Vote Mode")
local AutoVoteMode = Tabs.Ingame:AddDropdown("AutoVoteMode", { Title = "Auto Vote Mode", Values = {"Normal", "Hard", "Extreme"}, Multi = false, Default = 1 })
local EnableAutoVote = Tabs.Ingame:AddToggle("EnableAutoVote", { Title = "Enable Auto Vote", Default = false })

-- [ แท็บ Macro ]
Tabs.Macro:AddSection("Status")
local MacroStatus = Tabs.Macro:AddParagraph({ Title = "ℹ️ Current Status", Content = "File: None\nStatus: Idle ⚪\nActions: 0\nIn-Game Time: --" })

Tabs.Macro:AddSection("File Management")
local NewMacroName = Tabs.Macro:AddInput("NewMacroName", { Title = "New Macro Name", Placeholder = "Enter Text...", Finished = false })
Tabs.Macro:AddButton({ Title = "➕ Create & Select File", Callback = function() end })
local SelectMacroFile = Tabs.Macro:AddDropdown("SelectMacroFile", { Title = "📂 Select / Load Macro File", Values = {"None"}, Multi = false, Default = 1 })
Tabs.Macro:AddButton({ Title = "🔄 Refresh List", Callback = function() end })
Tabs.Macro:AddButton({ Title = "🗑️ Delete Selected File", Callback = function() end })

Tabs.Macro:AddSection("Controls")
local PlaybackMode = Tabs.Macro:AddDropdown("PlaybackMode", { Title = "⚙️ Playback Mode", Values = {"Money + Time", "Time Only", "Action Based"}, Multi = false, Default = 1 })
Tabs.Macro:AddButton({ Title = "🔴 Start Recording", Callback = function() end })
Tabs.Macro:AddButton({ Title = "⏹️ Stop Recording & Auto-Save", Callback = function() end })
local AutoPlayMacro = Tabs.Macro:AddToggle("AutoPlayMacro", { Title = "🟢 Auto Play Selected Macro (Looping)", Default = false })
Tabs.Macro:AddButton({ Title = "▶️ Play Macro (Run Once)", Callback = function() end })
Tabs.Macro:AddButton({ Title = "⏹️ Stop Macro", Callback = function() end })

-- [ แท็บ AutoPlace ]
Tabs.AutoPlace:AddSection("Status")
local AutoPlaceStatus = Tabs.AutoPlace:AddParagraph({ Title = "Status", Content = "Status: Idle ⚪" })
local AutoPlayFull = Tabs.AutoPlace:AddToggle("AutoPlayFull", { Title = "⚡ Auto Play Full", Default = false })

Tabs.AutoPlace:AddSection("⬆️ Auto Upgrade")
local EnableAutoUpgrade = Tabs.AutoPlace:AddToggle("EnableAutoUpgrade", { Title = "✅ Enable Auto Upgrade", Default = false })

-- ==========================================
-- 🧠 4. ฟังก์ชันหลังบ้าน (Logic Core)
-- ==========================================

local function GetCurrentMoney()
    local hudCash = LocalPlayer.PlayerGui:FindFirstChild("HUD") and LocalPlayer.PlayerGui.HUD:FindFirstChild("BottomFrame") and LocalPlayer.PlayerGui.HUD.BottomFrame:FindFirstChild("CurrencyList") and LocalPlayer.PlayerGui.HUD.BottomFrame.CurrencyList:FindFirstChild("Cash")
    if not hudCash then return 0 end
    
    local text = string.gsub(string.gsub(hudCash.Text, "%$", ""), ",", "")
    local multiplier = 1
    if string.find(string.lower(text), "k") then
        multiplier = 1000
        text = string.gsub(string.lower(text), "k", "")
    elseif string.find(string.lower(text), "m") then
        multiplier = 1000000
        text = string.gsub(string.lower(text), "m", "")
    end
    return (tonumber(text) or 0) * multiplier
end

local function GetAvailableUnits()
    local units = {}
    local hudUnitFolder = LocalPlayer.PlayerGui:FindFirstChild("HUD") and LocalPlayer.PlayerGui.HUD:FindFirstChild("BottomFrame") and LocalPlayer.PlayerGui.HUD.BottomFrame:FindFirstChild("Unit")
    if not hudUnitFolder then return units end
    
    for _, slot in pairs(hudUnitFolder:GetChildren()) do
        local idObj = slot:FindFirstChild("ID")
        if idObj and idObj:IsA("NumberValue") and idObj.Value ~= 0 then
            local unitNameObj = slot:FindFirstChild("Unit")
            local imageLabel = slot:FindFirstChild("ImageLabel")
            local costLabel = imageLabel and imageLabel:FindFirstChild("TextLabel")
            
            if unitNameObj and costLabel then
                table.insert(units, {
                    Name = unitNameObj.Value,
                    Cost = tonumber(costLabel.Text) or 0
                })
            end
        end
    end
    return units
end

local function GetFurthestEnemyProgress(waypoints)
    local totalNodes = #waypoints
    if totalNodes == 0 then return 0 end
    
    local maxNodeIndex = 1
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return 0 end
    
    for _, enemy in pairs(enemiesFolder:GetChildren()) do
        local currentNodeObj = enemy:FindFirstChild("Node") or enemy:FindFirstChild("Waypoint")
        if currentNodeObj and currentNodeObj:IsA("ValueBase") then
            local nodeIndex = tonumber(currentNodeObj.Value) or 1
            if nodeIndex > maxNodeIndex then maxNodeIndex = nodeIndex end
        end
    end
    return (maxNodeIndex / totalNodes) * 100
end

local function GetPlacedUnitCount(unitName)
    local count = 0
    local unitFolder = workspace:FindFirstChild("Unit")
    if not unitFolder then return 0 end
    
    for _, unit in pairs(unitFolder:GetChildren()) do
        if unit.Name == unitName then count = count + 1 end
    end
    return count
end

local function GetPlacementCFrame(waypointPart, offsetIndex)
    local baseOffset = 8
    local spacing = (offsetIndex - 1) * 3
    local targetPosition = waypointPart.Position + (waypointPart.CFrame.RightVector * (baseOffset + spacing))
    local finalY = waypointPart.Position.Y + 4.8 
    return CFrame.new(targetPosition.X, finalY, targetPosition.Z)
end

local function GetHillPlacementCFrame(offsetIndex)
    local hillFolder = workspace:FindFirstChild("Placeable") and workspace.Placeable:FindFirstChild("Hill")
    if not hillFolder then return nil end
    
    local hills = hillFolder:GetChildren()
    if #hills == 0 then return nil end
    
    local targetHill = hills[(offsetIndex % #hills) + 1]
    local hillTopPosition = targetHill.Position
    local finalY = hillTopPosition.Y + (targetHill.Size.Y / 2) + 2.5 
    return CFrame.new(hillTopPosition.X, finalY, hillTopPosition.Z)
end

local function SmartAutoPlace()
    local myMoney = GetCurrentMoney()
    local myUnits = GetAvailableUnits()
    
    local pathsFolder = workspace:FindFirstChild("Paths")
    if not pathsFolder then return end
    
    local waypoints = pathsFolder:GetChildren()
    table.sort(waypoints, function(a, b) return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0) end)
    if #waypoints == 0 then return end
    
    local currentProgress = GetFurthestEnemyProgress(waypoints)
    local targetNode = (currentProgress >= 75) and waypoints[#waypoints] or waypoints[1]
    local inputRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Input")
    
    if not inputRemote then return end

    for i, unit in ipairs(myUnits) do
        local currentCount = GetPlacedUnitCount(unit.Name)
        local maxAllowed = MaxUnitLimits[unit.Name] or DEFAULT_MAX_LIMIT
        
        if currentCount < maxAllowed and myMoney >= unit.Cost then
            local placeCFrame = HillUnits[unit.Name] and GetHillPlacementCFrame(currentCount) or GetPlacementCFrame(targetNode, currentCount)
            
            if placeCFrame then
                local args = { "Summon", { Rotation = 0, cframe = placeCFrame, Unit = unit.Name } }
                pcall(function() inputRemote:FireServer(unpack(args)) end)
                myMoney = myMoney - unit.Cost 
                task.wait(0.2) 
            end
        end
    end
end

local function AutoUpgradeAll()
    local serverRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Server")
    local unitFolder = workspace:FindFirstChild("Unit")
    if not serverRemote or not unitFolder then return end
    
    for _, unit in pairs(unitFolder:GetChildren()) do
        pcall(function() serverRemote:InvokeServer("Upgrade", unit) end)
    end
end

-- ==========================================
-- ฟังก์ชันจำลองการคลิกปุ่ม (รองรับทั้งมือถือและ PC)
-- ==========================================
local function ClickUIButton(button)
    if not button then return end
    
    -- วิธีที่ 1: ใช้ getconnections (เสถียรที่สุดสำหรับตัวรันส่วนใหญ่)
    if getconnections then
        for _, connection in ipairs(getconnections(button.MouseButton1Click)) do
            connection:Fire()
        end
        for _, connection in ipairs(getconnections(button.Activated)) do
            connection:Fire()
        end
    -- วิธีที่ 2: ใช้ firesignal (เป็นวิธีสำรอง)
    elseif firesignal then
        firesignal(button.MouseButton1Click)
        firesignal(button.Activated)
    end
end

-- ==========================================
-- ลอจิก Auto Vote
-- ==========================================
local function HandleAutoVote()
    local hud = LocalPlayer.PlayerGui:FindFirstChild("HUD")
    if not hud then return end
    
    local voteFrame = hud:FindFirstChild("ModeVoteFrame")
    -- เช็คว่าหน้าต่างโหวตแสดงอยู่บนหน้าจอหรือไม่
    if voteFrame and voteFrame.Visible then
        -- ดึงชื่อโหมดที่คุณเลือกไว้จาก Dropdown (เช่น "Normal" หรือ "Extreme")
        local selectedMode = AutoVoteMode.Value 
        
        -- หาโฟลเดอร์โหมดนั้น แล้วเข้าไปหา TextButton
        local modeFolder = voteFrame:FindFirstChild(selectedMode)
        if modeFolder then
            local voteButton = modeFolder:FindFirstChild("TextButton")
            if voteButton then
                ClickUIButton(voteButton)
                print("Auto Voted for: " .. selectedMode)
                task.wait(1) -- หน่วงเวลาไว้กันคลิกรัวเกินไป
            end
        end
    end
end

-- ==========================================
-- ลอจิก Auto Speed
-- ==========================================
local function HandleAutoSpeed()
    local hud = LocalPlayer.PlayerGui:FindFirstChild("HUD")
    if not hud then return end
    
    -- ดึงข้อความความเร็วปัจจุบัน (เช่น "1X")
    local speedLabel = hud:FindFirstChild("FastForward") and hud.FastForward:FindFirstChild("TextLabel")
    if not speedLabel then return end
    
    -- ตัดเอาเฉพาะตัวเลขจากหน้าจอ (1X -> 1)
    local currentSpeedText = speedLabel.Text
    local currentSpeed = tonumber(string.match(currentSpeedText, "%d+")) or 1
    
    -- ดึงตัวเลขเป้าหมายจาก Dropdown UI ของเรา (เช่น "2x" -> 2)
    local targetSpeedText = SpeedMode.Value
    local targetSpeed = tonumber(string.match(targetSpeedText, "%d+")) or 1
    
    local inputRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Input")
    if not inputRemote then return end
    
    -- ปรับความเร็วให้ตรงกับที่ตั้งไว้
    if currentSpeed < targetSpeed then
        inputRemote:FireServer("SpeedChange", true)
        task.wait(0.5) -- หน่วงเวลารอ UI เกมเปลี่ยนแปปนึง
    elseif currentSpeed > targetSpeed then
        inputRemote:FireServer("SpeedChange", false)
        task.wait(0.5)
    end
end

-- ==========================================
-- 🔄 5. Main Loop (อัปเดตใหม่)
-- ==========================================
task.spawn(function()
    while task.wait(1) do
        local statusText = "Status: Idle ⚪"
        
        -- ⚡ 1. ระบบ Auto Vote
        if EnableAutoVote.Value then
            pcall(HandleAutoVote)
        end
        
        -- ⚡ 2. ระบบ Auto Speed
        if EnableAutoGameSpeed.Value then
            pcall(HandleAutoSpeed)
        end
        
        -- ⚡ 3. ระบบ Auto Place
        if AutoPlayFull.Value then
            statusText = "Status: Auto Placing... ⚡"
            pcall(SmartAutoPlace)
        end
        
        -- ⚡ 4. ระบบ Auto Upgrade
        if EnableAutoUpgrade.Value then
            statusText = statusText == "Status: Idle ⚪" and "Status: Upgrading... ⬆️" or "Status: Placing & Upgrading 🔥"
            pcall(AutoUpgradeAll)
        end
        
        if AutoPlaceStatus then
            AutoPlaceStatus:SetDesc(statusText)
        end
    end
end)

-- ==========================================
-- 💾 6. โหลดตั้งค่า SaveManager (Settings)
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
-- ปิด AutoLoad ไว้ก่อนเพื่อความปลอดภัย ให้คนเปิดเอง
-- SaveManager:LoadAutoloadConfig() 

Fluent:Notify({
    Title = "Hub Loaded!",
    Content = "โหลดสคริปต์เรียบร้อย (ปุ่มทั้งหมดถูกตั้งให้ปิดเป็นค่าเริ่มต้น)",
    Duration = 5
})
