-- ==========================================
-- 🟢 1. โหลด Services และ Libraries
-- ==========================================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ==========================================
-- ⚙️ 2. ตั้งค่าตัวละคร (Configuration)
-- ==========================================
local HillUnits = {
    ["AsNodt"] = true,
    -- ใส่ชื่อตัวละครที่ต้องวางบนเนินตรงนี้
}

local MoneyUnitLimits = {
    ["Hoshino"] = 1,
    -- ["ชื่อตัวละคร"] = จำนวนสูงสุดที่ให้วาง
}
local DEFAULT_MAX_LIMIT = 8
local OCCUPANCY_RADIUS = 7
local ZONE_FAIL_BLACKLIST_THRESHOLD = 3
local ZONE_BLACKLIST_SECONDS = 25
local PLACEMENT_VERIFY_DELAY = 0.75
local PLACE_ATTEMPTS_PER_TERRAIN = 3
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1514217542556586014/_rOFfVg0ISYghh63134NtwRmzTKKUjDbzqwDrpJNGQFbP_hlvojhySGMqPEOFPwYgT4J"

local FailedZones = {}
local ZoneFailCount = {}
local UnitTerrainFailCount = {}
local UnitPlacementPreference = {}

local EconomyPlaced = false
local DefenderPlaced = false
local DefenderReady = false
local DefenderUnit = nil
local DefenderUnitName = nil

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

local function GetPlacedUnitRefs(unitName)
    local refs = {}
    local count = 0
    local unitFolder = workspace:FindFirstChild("Unit")
    if not unitFolder then return refs, 0 end

    for _, unit in pairs(unitFolder:GetChildren()) do
        if unit.Name == unitName then
            refs[unit] = true
            count = count + 1
        end
    end

    return refs, count
end

local function FindPlacedUnitByName(unitName)
    local unitFolder = workspace:FindFirstChild("Unit")
    if not unitFolder then return nil end

    for _, unit in pairs(unitFolder:GetChildren()) do
        if unit.Name == unitName then
            return unit
        end
    end

    return nil
end

local function GetInstancePosition(instance)
    if not instance then return nil end

    local ok, pivot = pcall(function()
        return instance:GetPivot()
    end)
    if ok and pivot then return pivot.Position end

    if instance:IsA("BasePart") then
        return instance.Position
    end

    return nil
end

local function GetInstanceKey(instance)
    if not instance then return "Unknown" end

    local ok, fullName = pcall(function()
        return instance:GetFullName()
    end)

    return ok and fullName or tostring(instance)
end

local function IsMoneyUnit(unitName)
    return MoneyUnitLimits[unitName] ~= nil
end

local function GetMaxAllowedForUnit(unitName)
    if IsMoneyUnit(unitName) then
        return MoneyUnitLimits[unitName]
    end

    return DEFAULT_MAX_LIMIT
end

local function BuildOccupancyMap()
    local occupancy = { Positions = {} }
    local unitFolder = workspace:FindFirstChild("Unit")
    if not unitFolder then return occupancy end

    for _, unit in pairs(unitFolder:GetChildren()) do
        local position = GetInstancePosition(unit)
        if position then
            table.insert(occupancy.Positions, {
                Unit = unit,
                Position = position
            })
        end
    end

    return occupancy
end

local function IsZoneOccupied(zone, occupancy)
    local zonePos = GetInstancePosition(zone)
    if not zonePos then return true end

    for _, entry in ipairs(occupancy.Positions) do
        if (entry.Position - zonePos).Magnitude <= OCCUPANCY_RADIUS then
            return true
        end
    end

    return false
end

local function IsZoneBlacklisted(zone)
    local key = GetInstanceKey(zone)
    local expiresAt = FailedZones[key]

    if not expiresAt then return false end
    if os.clock() >= expiresAt then
        FailedZones[key] = nil
        return false
    end

    return true
end

local function RegisterPlacementFailure(zone, unitName, terrain)
    local zoneKey = GetInstanceKey(zone)
    ZoneFailCount[zoneKey] = (ZoneFailCount[zoneKey] or 0) + 1

    if ZoneFailCount[zoneKey] >= ZONE_FAIL_BLACKLIST_THRESHOLD then
        FailedZones[zoneKey] = os.clock() + ZONE_BLACKLIST_SECONDS
        print("[SmartPlacement] Zone blacklisted temporarily:", zoneKey)
    end

    UnitTerrainFailCount[unitName] = UnitTerrainFailCount[unitName] or { Ground = 0, Hill = 0 }
    UnitTerrainFailCount[unitName][terrain] = (UnitTerrainFailCount[unitName][terrain] or 0) + 1

    print("[SmartPlacement] Placement failed:", unitName, "| Terrain:", terrain, "| Zone Fail:", ZoneFailCount[zoneKey], "| Terrain Fail:", UnitTerrainFailCount[unitName][terrain])
end

local function RegisterPlacementSuccess(zone, unitName, terrain)
    local zoneKey = GetInstanceKey(zone)
    ZoneFailCount[zoneKey] = 0

    UnitTerrainFailCount[unitName] = UnitTerrainFailCount[unitName] or { Ground = 0, Hill = 0 }

    if terrain == "Ground" then
        UnitTerrainFailCount[unitName].Ground = 0
    elseif terrain == "Hill" then
        UnitTerrainFailCount[unitName].Hill = 0
    end
end

local function GetMapName()
    local attrName = workspace:GetAttribute("MapName") or workspace:GetAttribute("Map")
    if attrName then return tostring(attrName) end

    local mapObj = workspace:FindFirstChild("Map") or workspace:FindFirstChild("MapName")
    if mapObj and mapObj:IsA("ValueBase") then
        return tostring(mapObj.Value)
    end

    return workspace.Name
end

local function SendPlacementPreferenceWebhook(unitName, previousPreference, newPreference)
    local message = string.format(
        "[SmartPlacement]\nUnit: %s\nMap: %s\nTimestamp: %s\nPrevious Preference: %s\nNew Preference: %s\nGround Failed 3 Times\nSwitched To Hill Successfully",
        unitName,
        GetMapName(),
        os.date("!%Y-%m-%dT%H:%M:%SZ"),
        previousPreference,
        newPreference
    )

    local payload = HttpService:JSONEncode({ content = message })

    task.spawn(function()
        local requestFunction = (syn and syn.request) or http_request or request
        if requestFunction then
            pcall(function()
                requestFunction({
                    Url = DISCORD_WEBHOOK_URL,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = payload
                })
            end)
        else
            pcall(function()
                HttpService:PostAsync(DISCORD_WEBHOOK_URL, payload, Enum.HttpContentType.ApplicationJson)
            end)
        end
    end)
end

local function GetCurrentWave()
    local hud = LocalPlayer.PlayerGui:FindFirstChild("HUD")
    local waveLabel = hud and hud:FindFirstChild("Wave")
    if not waveLabel then return 0, false end

    local text = tostring(waveLabel.Text or "")
    local waveText = nil

    for matchedWave in string.gmatch(text, "[Ww]ave%s*(%d+)") do
        waveText = matchedWave
    end

    if not waveText then
        waveText = string.match(text, "(%d+)%s*/%s*%d+")
    end

    local wave = tonumber(waveText)

    if not wave or wave <= 0 then
        return 0, false
    end

    return wave, true
end

local function SortNodesByName(nodes)
    table.sort(nodes, function(a, b)
        local aNum = tonumber(string.match(a.Name, "%d+")) or 0
        local bNum = tonumber(string.match(b.Name, "%d+")) or 0
        if aNum == bNum then
            return a.Name < b.Name
        end
        return aNum < bNum
    end)
end

local function CollectPathNodes()
    local pathsFolder = workspace:FindFirstChild("Paths")
    if not pathsFolder then return {} end

    local pathLists = {}
    local directNodes = {}

    for _, child in ipairs(pathsFolder:GetChildren()) do
        local numericChildren = {}
        for _, node in ipairs(child:GetChildren()) do
            if tonumber(string.match(node.Name, "%d+")) and GetInstancePosition(node) then
                table.insert(numericChildren, node)
            end
        end

        if #numericChildren >= 2 and (not GetInstancePosition(child) or not tonumber(child.Name)) then
            SortNodesByName(numericChildren)
            table.insert(pathLists, {
                Name = child.Name,
                Nodes = numericChildren
            })
        elseif GetInstancePosition(child) then
            table.insert(directNodes, child)
        end
    end

    if #directNodes > 0 then
        SortNodesByName(directNodes)
        table.insert(pathLists, 1, {
            Name = "Direct",
            Nodes = directNodes
        })
    end

    table.sort(pathLists, function(a, b)
        local aNum = tonumber(string.match(a.Name, "%d+")) or 0
        local bNum = tonumber(string.match(b.Name, "%d+")) or 0
        return aNum < bNum
    end)

    return pathLists
end

local function GetPrimaryPathNodes()
    local pathLists = CollectPathNodes()
    if #pathLists == 0 then return {} end
    return pathLists[1].Nodes
end

local function GetPathStartAndEnd()
    local nodes = GetPrimaryPathNodes()
    if #nodes == 0 then return nil, nil end
    return nodes[1], nodes[#nodes]
end

local function GetPlacementCFrameForZone(zone)
    local zonePos = GetInstancePosition(zone)
    if not zonePos then return nil end

    local zoneSizeY = 2
    if zone:IsA("Model") then
        zoneSizeY = zone:GetExtentsSize().Y
    elseif zone:IsA("BasePart") then
        zoneSizeY = zone.Size.Y
    end

    local placeY = zonePos.Y + (zoneSizeY / 2) + 2
    return CFrame.new(zonePos.X, placeY, zonePos.Z)
end

local function SelectPlacementZone(terrain, targetNode, options)
    options = options or {}

    local folderName = terrain == "Hill" and "Hill" or "Base"
    local placeableFolder = workspace:FindFirstChild("Placeable") and workspace.Placeable:FindFirstChild(folderName)
    if not placeableFolder then return nil, nil end

    local targetPos = GetInstancePosition(targetNode)
    if not targetPos then return nil, nil end

    local sourcePos = GetInstancePosition(options.SourceNode)
    local occupancy = options.Occupancy or BuildOccupancyMap()
    local excludedZones = options.ExcludedZones or {}
    local candidates = {}

    for _, zone in ipairs(placeableFolder:GetChildren()) do
        local zoneKey = GetInstanceKey(zone)
        local zonePos = GetInstancePosition(zone)

        if zonePos and not excludedZones[zoneKey] and not IsZoneBlacklisted(zone) and not IsZoneOccupied(zone, occupancy) then
            local targetDistance = (zonePos - targetPos).Magnitude
            local score = targetDistance + ((ZoneFailCount[zoneKey] or 0) * 12)

            if options.Mode == "Economy" and sourcePos then
                local spawnDistance = (zonePos - sourcePos).Magnitude
                score = targetDistance - (spawnDistance * 0.2) + ((ZoneFailCount[zoneKey] or 0) * 12)
            end

            table.insert(candidates, {
                Zone = zone,
                Score = score,
                TargetDistance = targetDistance,
                FailCount = ZoneFailCount[zoneKey] or 0
            })
        end
    end

    table.sort(candidates, function(a, b)
        if a.Score == b.Score then
            if a.FailCount == b.FailCount then
                return a.TargetDistance < b.TargetDistance
            end
            return a.FailCount < b.FailCount
        end
        return a.Score < b.Score
    end)

    local selected = candidates[1]
    if not selected then return nil, nil end

    return GetPlacementCFrameForZone(selected.Zone), selected.Zone
end

local function GetPreferredTerrains(unitName)
    if IsMoneyUnit(unitName) then
        return { "Ground" }
    end

    local preference = UnitPlacementPreference[unitName]
    if preference == "Hill" then
        return { "Hill", "Ground" }
    end

    if HillUnits[unitName] == true then
        return { "Hill", "Ground" }
    end

    local terrainFails = UnitTerrainFailCount[unitName]
    if terrainFails and (terrainFails.Ground or 0) >= 3 then
        return { "Hill", "Ground" }
    end

    return { "Ground" }
end

local function TryPlaceUnit(unitName, cframe, zone, terrain)
    local inputRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Input")
    if not inputRemote then return false, nil end

    local existingRefs, beforeCount = GetPlacedUnitRefs(unitName)
    local args = { "Summon", { Rotation = 0, cframe = cframe, Unit = unitName } }

    pcall(function()
        inputRemote:FireServer(unpack(args))
    end)

    task.wait(PLACEMENT_VERIFY_DELAY)

    local afterRefs, afterCount = GetPlacedUnitRefs(unitName)
    if afterCount <= beforeCount then
        RegisterPlacementFailure(zone, unitName, terrain)
        return false, nil
    end

    local newUnit = nil
    for placedUnit in pairs(afterRefs) do
        if not existingRefs[placedUnit] then
            newUnit = placedUnit
            break
        end
    end

    local terrainFails = UnitTerrainFailCount[unitName]
    local groundFailCount = terrainFails and (terrainFails.Ground or 0) or 0
    local previousPreference = UnitPlacementPreference[unitName] or "Ground"

    RegisterPlacementSuccess(zone, unitName, terrain)

    if terrain == "Hill" and groundFailCount >= 3 then
        UnitPlacementPreference[unitName] = "Hill"
        UnitTerrainFailCount[unitName].Ground = 0
        SendPlacementPreferenceWebhook(unitName, previousPreference, "Hill")
    end

    print("[SmartPlacement] Placement success:", unitName, "| Terrain:", terrain)
    return true, newUnit
end

local function PlaceUnitSmart(unit, targetNode, options)
    options = options or {}

    local terrainOrder = GetPreferredTerrains(unit.Name)
    local terrainIndex = 1

    while terrainIndex <= #terrainOrder do
        local terrain = terrainOrder[terrainIndex]
        local excludedZones = {}

        for _ = 1, PLACE_ATTEMPTS_PER_TERRAIN do
            local placeCFrame, zone = SelectPlacementZone(terrain, targetNode, {
                SourceNode = options.SourceNode,
                Mode = options.Mode,
                ExcludedZones = excludedZones,
                Occupancy = BuildOccupancyMap()
            })

            if not placeCFrame or not zone then break end

            excludedZones[GetInstanceKey(zone)] = true

            local success, newUnit = TryPlaceUnit(unit.Name, placeCFrame, zone, terrain)
            if success then
                return true, newUnit
            end

            local terrainFails = UnitTerrainFailCount[unit.Name]
            if terrain == "Ground" and terrainFails and (terrainFails.Ground or 0) >= 3 and not table.find(terrainOrder, "Hill") then
                table.insert(terrainOrder, "Hill")
                break
            end
        end

        terrainIndex = terrainIndex + 1
    end

    return false, nil
end

local function CanAffordAndPlace(unit, money)
    if money < unit.Cost then return false end
    return GetPlacedUnitCount(unit.Name) < GetMaxAllowedForUnit(unit.Name)
end

local function FindFirstMoneyUnit(units, money)
    for _, unit in ipairs(units) do
        if IsMoneyUnit(unit.Name) and CanAffordAndPlace(unit, money) then
            return unit
        end
    end

    return nil
end

local function HasMoneyUnitInTeam(units)
    for _, unit in ipairs(units) do
        if IsMoneyUnit(unit.Name) then
            return true
        end
    end

    return false
end

local function FindFirstDefenderUnit(units, money)
    for _, unit in ipairs(units) do
        if not IsMoneyUnit(unit.Name) and CanAffordAndPlace(unit, money) then
            return unit
        end
    end

    return nil
end

local function UpdateDefenderReady()
    if DefenderReady then return true end
    if (not DefenderUnit or not DefenderUnit.Parent) and DefenderUnitName then
        DefenderUnit = FindPlacedUnitByName(DefenderUnitName)
    end

    if not DefenderUnit or not DefenderUnit.Parent then return false end

    local upgradeTag = DefenderUnit:FindFirstChild("UpgradeTag") or DefenderUnit:FindFirstChild("UpgradeTag", true)
    if upgradeTag and tonumber(upgradeTag.Value) and tonumber(upgradeTag.Value) >= 3 then
        DefenderReady = true
        print("[SmartPlacement] Defender upgrade lock released:", DefenderUnit.Name)
    end

    return DefenderReady
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

    do
    local startNode, endNode = GetPathStartAndEnd()
    if not startNode or not endNode then return end

    UpdateDefenderReady()

    local currentWave, waveStarted = GetCurrentWave()

    if not EconomyPlaced and (not waveStarted or currentWave == 0) then
        if HasMoneyUnitInTeam(myUnits) then
            local moneyUnit = FindFirstMoneyUnit(myUnits, myMoney)
            if moneyUnit then
                local success = PlaceUnitSmart(moneyUnit, endNode, {
                    SourceNode = startNode,
                    Mode = "Economy"
                })

                if success then
                    EconomyPlaced = true
                    print("[SmartPlacement] Early economy placed:", moneyUnit.Name)
                end
            end
            return
        else
            EconomyPlaced = true
        end
    elseif not EconomyPlaced and waveStarted then
        EconomyPlaced = true
    end

    if EconomyPlaced and not DefenderPlaced then
        local defenderUnit = FindFirstDefenderUnit(myUnits, myMoney)
        if defenderUnit then
            local success, newUnit = PlaceUnitSmart(defenderUnit, endNode, {
                Mode = "Defender"
            })

            if success then
                DefenderPlaced = true
                DefenderUnit = newUnit
                DefenderUnitName = defenderUnit.Name
                DefenderReady = false
                print("[SmartPlacement] Defender placed near base:", defenderUnit.Name)
            end
        end
        return
    end

    if DefenderPlaced and not UpdateDefenderReady() then
        print("[SmartPlacement] Waiting for defender UpgradeTag >= 3 before placing more units.")
        return
    end

    local pathNodes = GetPrimaryPathNodes()
    if #pathNodes == 0 then return end

    local currentProgress = GetFurthestEnemyProgress(pathNodes)
    local targetNode = (currentProgress >= 75) and pathNodes[#pathNodes] or pathNodes[1]

    for _, unit in ipairs(myUnits) do
        if CanAffordAndPlace(unit, myMoney) then
            local success = PlaceUnitSmart(unit, targetNode, {
                Mode = "Normal"
            })

            if success then
                myMoney = myMoney - unit.Cost
                task.wait(0.2)
            end
        end
    end

    return
    end
    
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
        local maxAllowed = GetMaxAllowedForUnit(unit.Name)
        
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
