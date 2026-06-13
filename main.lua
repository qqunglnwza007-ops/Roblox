-- ==============================================================================
-- 👑 MACRO SYSTEM ARCHITECTURE (PHASE 1.1: UI & FILE SYSTEM ENGINE FIXED)
-- ==============================================================================

local HttpService = game:GetService("HttpService")
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

-- 🛠️ [FIXED] ฟังก์ชันดึงรายชื่อไฟล์ (ตัด Path และนามสกุลออกเด็ดขาด)
function MacroFS.GetMacroFiles()
    local files = {"None"}
    if listfiles then
        local success, result = pcall(function() return listfiles(MacroFS.FolderName) end)
        if success and result then
            for _, path in ipairs(result) do
                -- ใช้ Regex ดึงเฉพาะข้อความที่อยู่หลัง / หรือ \ และอยู่หน้า .json
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

-- 🛠️ [FIXED] ฟังก์ชันลบไฟล์ (รับชื่อเพียวๆ มาต่อ Path ให้ถูกต้อง)
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

Tabs.Macro:AddButton({ Title = "🔴 Start Recording", Callback = function()
    if MacroState.CurrentFile == "None" then Fluent:Notify({ Title = "Warning", Content = "โปรดเลือกไฟล์ก่อน!", Duration = 3 }) return end
    UpdateUIStatus("Recording 🔴")
end})

Tabs.Macro:AddButton({ Title = "⏹️ Stop Recording & Auto-Save", Callback = function()
    if MacroState.Status == "Recording 🔴" then
        UpdateUIStatus("Idle ⚪")
        Fluent:Notify({ Title = "Saved", Content = "บันทึกเรียบร้อย!", Duration = 3 })
    end
end})

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
