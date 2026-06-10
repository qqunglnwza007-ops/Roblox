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
    AutoPlace = Window:AddTab({ Title = "Auto Place", Icon = "map-pin" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- [ แท็บ Ingame ]
Tabs.Ingame:AddSection("Main Options")
local SpeedMode = Tabs.Ingame:AddDropdown("SpeedMode", { Title = "Speed Mode", Values = {"1x", "2x", "3x", "4x"}, Multi = false, Default = 2 })
local EnableAutoGameSpeed = Tabs.Ingame:AddToggle("EnableAutoGameSpeed", { Title = "Enable Auto GameSpeed", Default = false })
local EndMatchMode = Tabs.Ingame:AddDropdown("EndMatchMode", { Title = "End Match Mode", Values = {"Auto Next", "Return to Lobby", "Stay in Game"}, Multi = false, Default = 1 })

Tabs.Ingame:AddSection("Vote Mode")
local AutoVoteMode = Tabs.Ingame:AddDropdown("AutoVoteMode", { Title = "Auto Vote Mode", Values = {"Normal", "Hard", "Extreme"}, Multi = false, Default = 1 })
local EnableAutoVote = Tabs.Ingame:AddToggle("EnableAutoVote", { Title = "Enable Auto Vote", Default = false })

-- [ แท็บ AutoPlace ]
Tabs.AutoPlace:AddSection("Status")
local AutoPlaceStatus = Tabs.AutoPlace:AddParagraph({ Title = "Status", Content = "Status: Idle ⚪" })
local AutoPlayFull = Tabs.AutoPlace:AddToggle("AutoPlayFull", { Title = "⚡ Auto Play Full", Default = false })

Tabs.AutoPlace:AddSection("⬆️ Auto Upgrade")
local EnableAutoUpgrade = Tabs.AutoPlace:AddToggle("EnableAutoUpgrade", { Title = "✅ Enable Auto Upgrade", Default = false })

-- ==========================================
-- 🧠 4. ฟังก์ชันหลังบ้าน (Logic Core)
-- ==========================================

local function ClickUIButton(button)
    if not button then return end
    if getconnections then
        for _, connection in ipairs(getconnections(button.MouseButton1Click)) do connection:Fire() end
        for _, connection in ipairs(getconnections(button.Activated)) do connection:Fire() end
    elseif firesignal then
        firesignal(button.MouseButton1Click)
        firesignal(button.Activated)
    end
end

local function HandleAutoVote()
    local hud = LocalPlayer.PlayerGui:FindFirstChild("HUD")
    if not hud then return end
    local voteFrame = hud:FindFirstChild("ModeVoteFrame")
    if voteFrame and voteFrame.Visible then
        local modeFolder = voteFrame:FindFirstChild(AutoVoteMode.Value)
        if modeFolder then
            local voteButton = modeFolder:FindFirstChild("TextButton")
            if voteButton then ClickUIButton(voteButton) end
        end
    end
end

local function HandleAutoSpeed()
    local hud = LocalPlayer.PlayerGui:FindFirstChild("HUD")
    if not hud then return end
    local speedLabel = hud:FindFirstChild("FastForward") and hud.FastForward:FindFirstChild("TextLabel")
    if not speedLabel then return end
    
    local currentSpeed = tonumber(string.match(speedLabel.Text, "%d+")) or 1
    local targetSpeed = tonumber(string.match(SpeedMode.Value, "%d+")) or 1
    local inputRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Input")
    
    if not inputRemote then return end
    if currentSpeed < targetSpeed then
        inputRemote:FireServer("SpeedChange", true)
    elseif currentSpeed > targetSpeed then
        inputRemote:FireServer("SpeedChange", false)
    end
end

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
                table.insert(units, { Name = unitNameObj.Value, Cost = tonumber(costLabel.Text) or 0 })
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

-- 🎯 อัปเดตใหม่: ฟังก์ชันรองรับทั้ง Part และ Model 
local function GetValidPlacementCFrame(isHill, targetNode, offsetIndex)
    local folderName = isHill and "Hill" or "Base"
    local placeableFolder = workspace:FindFirstChild("Placeable") and workspace.Placeable:FindFirstChild(folderName)
    if not placeableFolder then return nil end

    local zones = placeableFolder:GetChildren()
    if #zones == 0 then return nil end

    -- ใช้ GetPivot().Position เพื่อดึงพิกัดให้ชัวร์ 100% ไม่ว่าจะเป็นกล่อง Model หรือ Part
    local targetPos = targetNode:GetPivot().Position

    table.sort(zones, function(a, b)
        local distA = (a:GetPivot().Position - targetPos).Magnitude
        local distB = (b:GetPivot().Position - targetPos).Magnitude
        return distA < distB
    end)

    local selectedZone = zones[(offsetIndex % #zones) + 1]
    local zonePos = selectedZone:GetPivot().Position
    
    -- หาความสูง Y อย่างปลอดภัย
    local zoneSizeY = 2 
    if selectedZone:IsA("Model") then
        zoneSizeY = selectedZone:GetExtentsSize().Y
    elseif selectedZone:IsA("BasePart") then
        zoneSizeY = selectedZone.Size.Y
    end

    local placeY = zonePos.Y + (zoneSizeY / 2) + 2
    return CFrame.new(zonePos.X, placeY, zonePos.Z)
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
            local isHillUnit = HillUnits[unit.Name] == true
            local placeCFrame = GetValidPlacementCFrame(isHillUnit, targetNode, currentCount)
            
            if placeCFrame then
                local args = { "Summon", { Rotation = 0, cframe = placeCFrame, Unit = unit.Name } }
                
                -- สั่งวาง!
                pcall(function() inputRemote:FireServer(unpack(args)) end)
                print("[✅ AutoPlace] สั่งวางตัวละคร:", unit.Name, "| ใช้เงิน:", unit.Cost)
                
                myMoney = myMoney - unit.Cost 
                task.wait(0.3) 
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
-- 🔄 5. Main Loop (ระบบรันลูปออโต้)
-- ==========================================
task.spawn(function()
    while task.wait(1) do
        local statusText = "Status: Idle ⚪"
        
        if EnableAutoVote.Value then
            pcall(HandleAutoVote)
        end
        
        if EnableAutoGameSpeed.Value then
            pcall(HandleAutoSpeed)
        end
        
        if AutoPlayFull.Value then
            statusText = "Status: Auto Placing... ⚡"
            pcall(SmartAutoPlace)
        end
        
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

Fluent:Notify({
    Title = "Fixed Bug!",
    Content = "อัปเดตรองรับพื้นที่แบบ Model แล้ว ลองเปิด F9 ดู Log ได้เลย",
    Duration = 5
})
