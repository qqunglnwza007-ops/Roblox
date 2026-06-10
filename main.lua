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
-- ⚙️ 2. ระบบตั้งค่าและหน่วยความจำ (Configuration & Memory Cache)
-- ==========================================
local WebhookURL = "https://discord.com/api/webhooks/1514217542556586014/_rOFfVg0ISYghh63134NtwRmzTKKUjDbzqwDrpJNGQFbP_hlvojhySGMqPEOFPwYgT4J" -- ใส่ URL Webhook ของคุณที่นี่

-- [ข้อ 1] เปลี่ยนชื่อเป็น MoneyUnitLimits สำหรับตัวเงินเท่านั้น
local MoneyUnitLimits = {
    ["Bulma"] = 1,
    ["Hoshino"] = 1,
}
local DEFAULT_MAX_LIMIT = 8
local MIN_DISTANCE_OCCUPIED = 3 -- [ข้อ 3] ระยะห่างห้ามวางใกล้กันเกินไป

-- [ข้อ 10] Placement Memory Cache
local FailedZones = {}             -- [ZoneInstance] = true (โซนที่โดน Blacklist)
local ZoneFailCount = {}           -- [ZoneInstance] = จำนวนครั้งที่ล้มเหลว
local UnitPlacementPreference = {} -- [UnitName] = "Base" หรือ "Hill" (ระบบเรียนรู้ประเภทพื้นผิว)
local GroundFailCount = {}         -- [UnitName] = จำนวนครั้งที่พื้นดินล้มเหลวติดต่อกัน

-- ตารางตรวจสอบสถานะการวางภายในเกม
local EarlyDefenderInstance = nil  -- เก็บ Object ของตัวกันบ้านต้นเกม

-- ==========================================
-- 📡 ฟังก์ชันส่งข้อมูลเข้า Discord Webhook [ข้อ 9]
-- ==========================================
local function SendDiscordNotification(unitName)
    if WebhookURL == "" or string.find(WebhookURL, "YOUR_DISCORD") then return end
    task.spawn(function()
        pcall(function()
            local req = syn and syn.request or http and http.request or http_request or request
            if req then
                req({
                    Url = WebhookURL,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode({
                        content = "⚠️ [Smart Recovery] ตรวจพบการเรียนรู้ใหม่: ยูนิต **" .. unitName .. "** พยายามวางบนพื้นล้มเหลวบ่อยครั้ง และได้รับการปรับสลับไปลงพื้นที่เนิน (**Hill**) สำเร็จแล้วในรอบนี้!"
                    })
                })
            end
        end)
    end)
end

-- ==========================================
-- 🖥️ 3. สร้าง UI (Fluent UI)
-- ==========================================
local Window = Fluent:CreateWindow({
    Title = "AutoPlay Hub Pro",
    SubTitle = "Tower Defense v3",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true, 
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Ingame = Window:AddTab({ Title = "Ingame", Icon = "gamepad-2" }),
    AutoPlace = Window:AddTab({ Title = "Auto Place", Icon = "map-pin" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

Tabs.Ingame:AddSection("Main Options")
local SpeedMode = Tabs.Ingame:AddDropdown("SpeedMode", { Title = "Speed Mode", Values = {"1x", "2x", "3x", "4x"}, Multi = false, Default = 2 })
local EnableAutoGameSpeed = Tabs.Ingame:AddToggle("EnableAutoGameSpeed", { Title = "Enable Auto GameSpeed", Default = false })
local AutoVoteMode = Tabs.Ingame:AddDropdown("AutoVoteMode", { Title = "Auto Vote Mode", Values = {"Normal", "Hard", "Extreme"}, Multi = false, Default = 1 })
local EnableAutoVote = Tabs.Ingame:AddToggle("EnableAutoVote", { Title = "Enable Auto Vote", Default = false })

Tabs.AutoPlace:AddSection("Status")
local AutoPlaceStatus = Tabs.AutoPlace:AddParagraph({ Title = "Status", Content = "Status: Idle ⚪" })
local AutoPlayFull = Tabs.AutoPlace:AddToggle("AutoPlayFull", { Title = "⚡ Auto Play Full", Default = false })
Tabs.AutoPlace:AddSection("⬆️ Auto Upgrade")
local EnableAutoUpgrade = Tabs.AutoPlace:AddToggle("EnableAutoUpgrade", { Title = "✅ Enable Auto Upgrade", Default = false })

-- ==========================================
-- 🧠 4. ฟังก์ชันจัดการข้อมูล (Logic Core & Scraping)
-- ==========================================

-- [ข้อ 4] อ่านค่า Wave และแยกเลขเวฟปัจจุบันออกมา
local function GetCurrentWave()
    pcall(function()
        local waveTextObj = LocalPlayer.PlayerGui.HUD.Wave
        local waveText = waveTextObj.Text -- "Wave 2/10" หรือ "2/10"
        local currentWave = string.match(waveText, "(%d+)")
        return tonumber(currentWave) or 0
    end)
    return 0
end

local function GetCurrentMoney()
    local hudCash = LocalPlayer.PlayerGui:FindFirstChild("HUD") and LocalPlayer.PlayerGui.HUD:FindFirstChild("BottomFrame") and LocalPlayer.PlayerGui.HUD.BottomFrame:FindFirstChild("CurrencyList") and LocalPlayer.PlayerGui.HUD.BottomFrame.CurrencyList:FindFirstChild("Cash")
    if not hudCash then return 0 end
    local text = string.gsub(string.gsub(hudCash.Text, "%$", ""), ",", "")
    local multiplier = 1
    if string.find(string.lower(text), "k") then multiplier = 1000 text = string.gsub(string.lower(text), "k", "")
    elseif string.find(string.lower(text), "m") then multiplier = 1000000 text = string.gsub(string.lower(text), "m", "") end
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

local function GetPlacedUnitCount(unitName)
    local count = 0
    local unitFolder = workspace:FindFirstChild("Unit")
    if not unitFolder then return 0 end
    for _, unit in pairs(unitFolder:GetChildren()) do
        if unit.Name == unitName then count = count + 1 end
    end
    return count
end

-- [ข้อ 3] Occupancy Map: ตรวจสอบตำแหน่งว่ามีตัวละครอื่นวางใกล้เกินไปไหม
local function IsZoneOccupied(zonePosition)
    local unitFolder = workspace:FindFirstChild("Unit")
    if not unitFolder then return false end
    for _, unit in pairs(unitFolder:GetChildren()) do
        if unit:IsA("Model") then
            if (unit:GetPivot().Position - zonePosition).Magnitude < MIN_DISTANCE_OCCUPIED then
                return true
            end
        end
    end
    return false
end

-- [ข้อ 10] ดึงตำแหน่งการวางที่ปลอดภัยและผ่านการคัดกรอง Memory Cache
local function GetSmartPlacementCFrame(unitName, targetNode, offsetIndex, forceBaseOnly)
    -- [ข้อ 9] ตรวจสอบระบบเรียนรู้ Preference (เริ่มต้นให้เป็น Base ทุกตัว)
    if not UnitPlacementPreference[unitName] then
        UnitPlacementPreference[unitName] = "Base"
    end
    
    local currentPref = forceBaseOnly and "Base" or UnitPlacementPreference[unitName]
    local placeableFolder = workspace:FindFirstChild("Placeable") and workspace.Placeable:FindFirstChild(currentPref)
    if not placeableFolder then return nil, nil end

    local zones = placeableFolder:GetChildren()
    local validZones = {}

    -- คัดกรองเอาเฉพาะโซนที่ไม่ติด Blacklist และไม่มีตัววางทับอยู่
    for _, zone in pairs(zones) do
        if not FailedZones[zone] and not IsZoneOccupied(zone:GetPivot().Position) then
            table.insert(validZones, zone)
        end
    end

    if #validZones == 0 then return nil, nil end

    -- ทำการเรียงลำดับพิกัดระยะทาง
    local targetPos = targetNode:GetPivot().Position
    table.sort(validZones, function(a, b)
        local distA = (a:GetPivot().Position - targetPos).Magnitude
        local distB = (b:GetPivot().Position - targetPos).Magnitude
        return distA < distB -- ลงจุดที่ใกล้เป้าหมายที่สุดก่อน
    end)

    local selectedZone = validZones[(offsetIndex % #validZones) + 1]
    local zonePos = selectedZone:GetPivot().Position
    
    local zoneSizeY = selectedZone:IsA("Model") and selectedZone:GetExtentsSize().Y or selectedZone.Size.Y
    local placeY = zonePos.Y + (zoneSizeY / 2) + 2
    
    return CFrame.new(zonePos.X, placeY, zonePos.Z), selectedZone
end

-- [ข้อ 2] Verify Placement: ส่งคำสั่งวางและรอตรวจสอบความสำเร็จเพื่อเรียนรู้ลอจิก
local function SummonWithVerification(unitName, placeCFrame, zoneInstance)
    if not placeCFrame then return false end
    local inputRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Input")
    if not inputRemote then return false end

    -- บันทึกจำนวนก่อนวาง
    local countBefore = GetPlacedUnitCount(unitName)

    -- ส่งสัญญาณรันสคริปต์
    local args = { "Summon", { Rotation = 0, cframe = placeCFrame, Unit = unitName } }
    pcall(function() inputRemote:FireServer(unpack(args)) end)

    -- รอเซิร์ฟเวอร์ตอบกลับอนุมัติ (0.5 - 1 วินาทีตามข้อกำหนด)
    task.wait(0.7)

    -- ตรวจสอบจำนวนหลังวาง
    local countAfter = GetPlacedUnitCount(unitName)

    if countAfter > countBefore then
        -- [Placement Success] วางสำเร็จ
        if ZoneFailCount[zoneInstance] then ZoneFailCount[zoneInstance] = 0 end
        
        -- [ข้อ 9] หากย้ายมาลง Hill แล้วทำสำเร็จ ให้ยิง Webhook แจ้งเตือน
        if UnitPlacementPreference[unitName] == "Hill" and GroundFailCount[unitName] and GroundFailCount[unitName] >= 3 then
            SendDiscordNotification(unitName)
            GroundFailCount[unitName] = 0 -- รีเซ็ตค่าหลังส่ง Webhook
        end
        return true
    else
        -- [Placement Failed] วางไม่สำเร็จ!
        print("[⚠️ Verification] วางยูนิตล้มเหลว: " .. unitName)
        
        if zoneInstance then
            ZoneFailCount[zoneInstance] = (ZoneFailCount[zoneInstance] or 0) + 1
            if ZoneFailCount[zoneInstance] >= 3 then
                FailedZones[zoneInstance] = true -- สั่งติด Blacklist ชั่วคราว [ข้อ 2]
                print("[🚫 Blacklist] บล็อกการใช้พิกัดโซน: " .. tostring(zoneInstance))
            end
        end

        -- [ข้อ 9] บันทึกความล้มเหลวของ Ground เพื่อเตรียมสลับไป Hill
        if UnitPlacementPreference[unitName] == "Base" then
            GroundFailCount[unitName] = (GroundFailCount[unitName] or 0) + 1
            if GroundFailCount[unitName] >= 3 then
                UnitPlacementPreference[unitName] = "Hill"
                print("[🧠 Learning] ยูนิต " .. unitName .. " ทำงานบนดินพลาดครบ 3 ครั้ง! เปลี่ยนแผนสลับไปลงเนิน (Hill)")
            end
        end
        return false
    end
end

-- ดึงค่าระดับการอัปเกรดจาก Object ภายในเกม [ข้อ 6]
local function GetUpgradeTagValue(unitModel)
    if unitModel and unitModel:FindFirstChild("UpgradeTag") and unitModel.UpgradeTag:IsA("IntValue") then
        return unitModel.UpgradeTag.Value
    end
    return 0
end

-- ==========================================
-- 🚀 5. ระบบออโต้เพลย์อัจฉริยะ (Smart Auto Place Mechanism)
-- ==========================================
local function MasterAutoPlaceLogic()
    local currentWave = GetCurrentWave()
    local myMoney = GetCurrentMoney()
    local myUnits = GetAvailableUnits()
    
    local pathsFolder = workspace:FindFirstChild("Paths")
    if not pathsFolder then return end
    local waypoints = pathsFolder:GetChildren()
    table.sort(waypoints, function(a, b) return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0) end)
    if #waypoints == 0 then return end

    -- ------------------------------------------
    -- 🛑 [ข้อ 5] Early Game Logic: จัดการเวฟ 0 ถึงเวฟ 1
    -- ------------------------------------------
    if currentWave <= 1 then
        -- หาตัวเงิน (Money Unit) ตัวแรกที่มีในกระเป๋าเรา
        local targetMoneyUnit = nil
        for _, unit in ipairs(myUnits) do
            if MoneyUnitLimits[unit.Name] then
                targetMoneyUnit = unit
                break
            end
        end

        if targetMoneyUnit then
            local currentPlacedMoneyCount = GetPlacedUnitCount(targetMoneyUnit.Name)
            
            -- [ข้อ 5] เงื่อนไข: วางตัวเงินแค่ตัวเดียวพอ ในพิกัด Base ที่ไกลมอนออกที่สุด
            if currentPlacedMoneyCount == 0 then
                if myMoney >= targetMoneyUnit.Cost then
                    -- สั่งดึง CFrame พื้นดิน (Base เท่านั้น) ที่อยู่ห่างจากจุดเกิดมอนสเตอร์มากที่สุด (โหนดสุดท้าย)
                    local spawnNode = waypoints[1]
                    local placeCFrame, zoneInst = GetSmartPlacementCFrame(targetMoneyUnit.Name, waypoints[#waypoints], 0, true)
                    
                    if placeCFrame then
                        SummonWithVerification(targetMoneyUnit.Name, placeCFrame, zoneInst)
                    end
                end
                return -- ล็อคระบบไม่ให้ขยับไปลอจิกอื่นจนกว่าตัวเงินตัวแรกจะลงสำเร็จ
            end
        end

        -- ------------------------------------------
        -- 🛡️ [ข้อ 6] Defender Logic: วางตัวป้องกันต้นเกมใกล้ฐาน
        -- ------------------------------------------
        -- ค้นหาตัวดีเฟนเดอร์ (ตัวโจมตีตัวแรกที่ไม่ใช่ตัวเงิน)
        local targetDefenderUnit = nil
        for _, unit in ipairs(myUnits) do
            if not MoneyUnitLimits[unit.Name] then
                targetDefenderUnit = unit
                break
            end
        end

        if targetDefenderUnit then
            local unitFolder = workspace:FindFirstChild("Unit")
            
            -- ค้นหาว่าตัวละคร Defender ของเราถูกวางลงไปในสนามหรือยัง
            if not EarlyDefenderInstance or not EarlyDefenderInstance:IsDescendantOf(unitFolder) then
                -- ถ้ายังไม่มี ให้จับพิกัดพื้นที่ใกล้โหนดสุดท้าย (เช่น Node 9)
                local lastNode = waypoints[#waypoints]
                if myMoney >= targetDefenderUnit.Cost then
                    local currentCount = GetPlacedUnitCount(targetDefenderUnit.Name)
                    local placeCFrame, zoneInst = GetSmartPlacementCFrame(targetDefenderUnit.Name, lastNode, currentCount, false)
                    
                    if placeCFrame then
                        local success = SummonWithVerification(targetDefenderUnit.Name, placeCFrame, zoneInst)
                        if success then
                            -- ล็อคตัวละครนี้ไว้เป็นตัวหลักสำหรับภารกิจอัปเกรด
                            task.wait(0.2)
                            for _, u in pairs(unitFolder:GetChildren()) do
                                if u.Name == targetDefenderUnit.Name then
                                    EarlyDefenderInstance = u
                                end
                            end
                        end
                    end
                end
                return -- ห้ามวางตัวอื่นเพิ่มเด็ดขาดจนกว่าดีเฟนเดอร์จะลงสนาม
            else
                -- [ข้อ 6] ดีเฟนเดอร์ลงสนามแล้ว -> ห้ามวางตัวอื่นเพิ่ม! บังคับอัปเกรดให้ถึงขั้น 3 เท่านั้น
                local currentTier = GetUpgradeTagValue(EarlyDefenderInstance)
                if currentTier < 3 then
                    local serverRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Server")
                    if serverRemote then
                        pcall(function()
                            serverRemote:InvokeServer("Upgrade", EarlyDefenderInstance)
                        end)
                    end
                    return -- ล็อคคิวสคริปต์ทั้งหมด ห้ามวางตัวเพิ่มเด็ดขาดจนกว่าดีเฟนเดอร์จะขั้น 3!
                end
            end
        end
    end

    -- ------------------------------------------
    -- ⚔️ 6. Mid/Late Game Loop (โหมดทำงานปกติเมื่อพ้นเงื่อนไขต้นเกม)
    -- ------------------------------------------
    local GetFurthestEnemyProgress = function()
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
        return (maxNodeIndex / #waypoints) * 100
    end

    local currentProgress = GetFurthestEnemyProgress()
    local targetNode = (currentProgress >= 75) and waypoints[#waypoints] or waypoints[1]

    for i, unit in ipairs(myUnits) do
        local currentCount = GetPlacedUnitCount(unit.Name)
        
        -- คัดกรองตัวแปรจำกัดจำนวนระหว่างตัวเงินกับตัวโจมตีทั่วไป
        local maxAllowed = MoneyUnitLimits[unit.Name] or DEFAULT_MAX_LIMIT
        
        if currentCount < maxAllowed and myMoney >= unit.Cost then
            local isHillUnit = UnitPlacementPreference[unit.Name] == "Hill"
            local placeCFrame, zoneInst = GetSmartPlacementCFrame(unit.Name, targetNode, currentCount, false)
            
            if placeCFrame then
                SummonWithVerification(unit.Name, placeCFrame, zoneInst)
            end
        end
    end
end

local function AutoUpgradeAll()
    local serverRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Server")
    local unitFolder = workspace:FindFirstChild("Unit")
    if not serverRemote or not unitFolder then return end
    
    -- อ่านค่าเวฟปัจจุบัน
    local currentWave = GetCurrentWave()
    
    for _, unit in pairs(unitFolder:GetChildren()) do
        -- [ข้อ 6] ป้องกันข้ามคำสั่ง: หากเป็นช่วงต้นเกมและเป็นตัวดีเฟนเดอร์ ระบบหลักจะควบคุมการอัปเกรดแบบเดี่ยวเอง
        if currentWave <= 1 and EarlyDefenderInstance and unit == EarlyDefenderInstance then
            continue
        end
        pcall(function() serverRemote:InvokeServer("Upgrade", unit) end)
    end
end

-- ==========================================
-- 🔄 5. Main Loop (ระบบคิวรันลูปอัตโนมัติ)
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
            pcall(MasterAutoPlaceLogic)
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
-- 💾 6. โหลดตั้งค่าระบบเมนูเบื้องหลัง
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
    Title = "Upgrade Complete!",
    Content = "สคริปต์ถูกยกเครื่องสู่ระบบอัตโนมัติ V3 เรียบร้อยแล้ว",
    Duration = 5
})
