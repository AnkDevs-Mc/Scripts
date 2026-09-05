-- Simple Auto Level Farm
-- Rebuilt from the supplied script's Auto Farm Level logic.
-- Only the Start / Stop GUI is included.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

_G.AutoFarmLevelReal = false
_G.StartFarm = false
_G.StopTween = false

local PosMon
local BringMobFarm = false
local tween
local SetCFarme = 1
local FastAttack = false
local Speed = 300

-- The original script needs these settings inside toTarget/attack.
_G.Settings = {
    Configs = {
        ["Bypass TP"] = false,
        ["Fast Attack"] = true,
    }
}

-- CombatFramework / fast attack from the supplied script.
local CombatFramework = require(LocalPlayer.PlayerScripts:WaitForChild("CombatFramework"))
local CombatFrameworkR = getupvalues(CombatFramework)[2]
local cooldownfastattack = tick()

local function getAllBladeHits(size)
    local hits = {}
    local enemies = workspace:FindFirstChild("Enemies")
    local character = LocalPlayer.Character
    if not enemies or not character then return hits end

    for _, v in ipairs(enemies:GetChildren()) do
        local hum = v:FindFirstChildOfClass("Humanoid")
        local root = hum and hum.RootPart
        if root and hum.Health > 0 and LocalPlayer:DistanceFromCharacter(root.Position) < size + 5 then
            table.insert(hits, root)
        end
    end
    return hits
end

local function currentWeapon()
    local ac = CombatFrameworkR.activeController
    if not ac then return nil end

    local ret = ac.blades and ac.blades[1]
    if ret then
        pcall(function()
            while ret.Parent ~= LocalPlayer.Character and ret.Parent do
                ret = ret.Parent
            end
        end)
    end

    if typeof(ret) == "Instance" then
        return ret
    end

    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    return tool and tool.Name
end

local function attackFunction()
    local ac = CombatFrameworkR.activeController
    if not ac or not ac.equipped then return end

    local bladehit = getAllBladeHits(60)
    if #bladehit == 0 then return end

    local ok = pcall(function()
        local a8 = debug.getupvalue(ac.attack, 5)
        local a9 = debug.getupvalue(ac.attack, 6)
        local a7 = debug.getupvalue(ac.attack, 4)
        local a10 = debug.getupvalue(ac.attack, 7)

        if not a8 or not a9 or not a7 or not a10 then
            ac:attack()
            return
        end

        local n12 = (a8 * 798405 + a7 * 727595) % a9
        local n13 = a7 * 798405

        n12 = (n12 * a9 + n13) % 1099511627776
        a8 = math.floor(n12 / a9)
        a7 = n12 - a8 * a9
        a10 = a10 + 1

        debug.setupvalue(ac.attack, 5, a8)
        debug.setupvalue(ac.attack, 6, a9)
        debug.setupvalue(ac.attack, 4, a7)
        debug.setupvalue(ac.attack, 7, a10)

        if ac.animator and ac.animator.anims and ac.animator.anims.basic then
            for _, anim in pairs(ac.animator.anims.basic) do
                pcall(function() anim:Play(0.01, 0.01, 0.01) end)
            end
        end

        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool and ac.blades and ac.blades[1] then
            ReplicatedStorage.RigControllerEvent:FireServer("weaponChange", tostring(currentWeapon()))
            ReplicatedStorage.Remotes.Validator:FireServer(
                math.floor(n12 / 1099511627776 * 16777215),
                a10
            )
            ReplicatedStorage.RigControllerEvent:FireServer("hit", bladehit, 2, "")
        end
    end)

    if not ok then
        pcall(function() ac:attack() end)
    end
end

task.spawn(function()
    while task.wait(0.1) do
        if _G.AutoFarmLevelReal then
            FastAttack = true
            local ac = CombatFrameworkR.activeController
            if ac and ac.equipped and FastAttack then
                attackFunction()
                if tick() - cooldownfastattack > 0.08 then
                    cooldownfastattack = tick()
                end
            end
        else
            FastAttack = false
        end
    end
end)

-- Recreate the spawn-name folder used by QuestCheck.
local oldSpawns = workspace:FindFirstChild("EnemySpawns")
if oldSpawns then oldSpawns:Destroy() end

local EnemySpawns = Instance.new("Folder")
EnemySpawns.Name = "EnemySpawns"
EnemySpawns.Parent = workspace

local worldOrigin = workspace:FindFirstChild("_WorldOrigin")
local sourceSpawns = worldOrigin and worldOrigin:FindFirstChild("EnemySpawns")

if sourceSpawns then
    for _, v in ipairs(sourceSpawns:GetChildren()) do
        if v:IsA("BasePart") then
            local clone = v:Clone()
            local name = v.Name:gsub("Lv%. ", ""):gsub("[%[%]]", ""):gsub("%d+", ""):gsub("%s+", "")
            clone.Name = name
            clone.Parent = EnemySpawns
            clone.Anchored = true
        end
    end
end

-- Keep the original quest-selection logic, but reset its temporary values every call.
local function QuestCheck()
    local data = LocalPlayer:FindFirstChild("Data")
    local levelValue = data and data:FindFirstChild("Level")
    if not levelValue then return nil end

    local Lvl = levelValue.Value
    local QuestName, QuestLevel, MobName, Mon, NPCPosition, LevelRequire, MobCFrame

    if Lvl >= 1 and Lvl <= 9 then
        if tostring(LocalPlayer.Team) == "Marines" then
            MobName = "Trainee [Lv. 5]"
            QuestName = "MarineQuest"
            QuestLevel = 1
            Mon = "Trainee"
            NPCPosition = CFrame.new(-2709.67944, 24.5206585, 2104.24585)
        else
            MobName = "Bandit [Lv. 5]"
            Mon = "Bandit"
            QuestName = "BanditQuest1"
            QuestLevel = 1
            NPCPosition = CFrame.new(1059.99731, 16.9222069, 1549.28162)
        end

        local points = {}
        for _, v in ipairs(EnemySpawns:GetChildren()) do
            if v.Name == Mon then table.insert(points, v.CFrame) end
        end

        return {QuestLevel, NPCPosition, MobName, QuestName, Lvl, Mon, points}
    end

    -- This is the same GuideModule/Quests lookup used by the supplied script.
    local ok, GuideModule, Quests = pcall(function()
        return require(ReplicatedStorage.GuideModule), require(ReplicatedStorage.Quests)
    end)
    if not ok or not GuideModule or not Quests then return nil end

    local npcList = GuideModule.Data and GuideModule.Data.NPCList
    if not npcList then return nil end

    for npc, info in pairs(npcList) do
        if info.Levels then
            for questLevel, requiredLevel in pairs(info.Levels) do
                if Lvl >= requiredLevel and (not LevelRequire or requiredLevel > LevelRequire) then
                    NPCPosition = npc.CFrame
                    QuestLevel = questLevel
                    LevelRequire = requiredLevel
                end
            end
        end
    end

    if not LevelRequire then return nil end

    if Lvl >= 375 and Lvl <= 399 then
        MobCFrame = CFrame.new(61122.5625, 18.4716396, 1568.16504)
    elseif Lvl >= 400 and Lvl <= 449 then
        MobCFrame = CFrame.new(61122.5625, 18.4716396, 1568.16504)
    end

    for quest, questData in pairs(Quests) do
        for _, q in pairs(questData) do
            if q.LevelReq == LevelRequire and quest ~= "CitizenQuest" then
                QuestName = quest
                if q.Task then
                    for mob, _ in pairs(q.Task) do
                        MobName = mob
                        Mon = mob:split(" [Lv. " .. tostring(LevelRequire) .. "]")[1]
                    end
                end
            end
        end
    end

    if QuestName == "MarineQuest2" then
        QuestLevel, MobName, Mon, LevelRequire = 1, "Chief Petty Officer [Lv. 120]", "Chief Petty Officer", 120
    elseif QuestName == "ImpelQuest" then
        QuestName, QuestLevel, MobName, Mon, LevelRequire = "PrisonerQuest", 2, "Dangerous Prisoner [Lv. 190]", "Dangerous Prisoner", 210
        NPCPosition = CFrame.new(5310.60547, 0.350014925, 474.946594)
    elseif QuestName == "SkyExp1Quest" then
        if QuestLevel == 1 then
            NPCPosition = CFrame.new(-4721.88867, 843.874695, -1949.96643)
        elseif QuestLevel == 2 then
            NPCPosition = CFrame.new(-7859.09814, 5544.19043, -381.476196)
        end
    elseif QuestName == "Area2Quest" and QuestLevel == 2 then
        QuestName, QuestLevel, MobName, Mon, LevelRequire = "Area2Quest", 1, "Swan Pirate [Lv. 775]", "Swan Pirate", 775
    end

    if not MobName or not QuestName or not NPCPosition then return nil end

    -- Pick the exact mob variant currently present, like the original script.
    if not MobName:find("Lv") then
        for _, v in ipairs(workspace.Enemies:GetChildren()) do
            local mobLevel = tonumber(v.Name:match("%d+"))
            if mobLevel and v.Name:find(MobName, 1, true) and #v.Name > #MobName and mobLevel <= Lvl + 50 then
                MobName = v.Name
            end
        end
    end

    local clean = MobName:gsub("Lv%. ", ""):gsub("[%[%]]", ""):gsub("%d+", ""):gsub("%s+", "")
    local points = {}
    for _, v in ipairs(EnemySpawns:GetChildren()) do
        if v.Name == clean then table.insert(points, v.CFrame) end
    end

    if #points == 0 and MobCFrame then
        points = {MobCFrame}
    end

    return {QuestLevel, NPCPosition, MobName, QuestName, LevelRequire, Mon, points}
end

local function getIsland(pos)
    local world = workspace:FindFirstChild("_WorldOrigin")
    local spawns = world and world:FindFirstChild("PlayerSpawns")
    local team = LocalPlayer.Team
    local teamSpawns = team and spawns and spawns:FindFirstChild(tostring(team))
    if not teamSpawns then return nil end

    local closest, distance = nil, math.huge
    for _, v in ipairs(teamSpawns:GetChildren()) do
        local cf = v:GetModelCFrame()
        local d = (pos - cf.Position).Magnitude
        if d < distance then
            distance = d
            closest = v.Name
        end
    end
    return closest
end

local function toTarget(target)
    if not target then return nil end

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return nil end

    local targetCF
    if typeof(target) == "CFrame" then
        targetCF = target
    elseif typeof(target) == "Vector3" then
        targetCF = CFrame.new(target)
    elseif typeof(target) == "Instance" and target:IsA("BasePart") then
        targetCF = target.CFrame
    else
        return nil
    end

    if tween then pcall(function() tween:Cancel() end) end

    local distance = (targetCF.Position - root.Position).Magnitude
    Speed = distance < 1000 and 315 or 300

    local duration = math.max(distance / Speed, 0.05)
    tween = TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        {CFrame = targetCF}
    )
    tween:Play()

    return tween
end

local function equipWeapon()
    local character = LocalPlayer.Character
    local backpack = LocalPlayer.Backpack
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local selected
    for _, v in ipairs(backpack:GetChildren()) do
        if v:IsA("Tool") and (v.ToolTip == "Melee" or v.ToolTip == "Sword") then
            selected = v
            break
        end
    end
    selected = selected or backpack:FindFirstChildOfClass("Tool")

    if selected then
        pcall(function() hum:EquipTool(selected) end)
    end
end

-- Mob bring portion from the supplied script.
task.spawn(function()
    while task.wait() do
        if _G.AutoFarmLevelReal and BringMobFarm and PosMon then
            pcall(function()
                for _, v in ipairs(workspace.Enemies:GetChildren()) do
                    local hum = v:FindFirstChildOfClass("Humanoid")
                    local root = v:FindFirstChild("HumanoidRootPart")
                    if hum and root and not v.Name:find("Boss") and
                       (root.Position - PosMon.Position).Magnitude <= 400 and hum.Health > 0 then
                        root.CFrame = PosMon
                        root.Size = Vector3.new(60,60,60)
                        root.CanCollide = false
                        hum.WalkSpeed = 0
                        hum.JumpPower = 0
                    end
                end
            end)
        end
    end
end)

-- Main Auto Farm loop.
task.spawn(function()
    while task.wait(0.15) do
        if not _G.AutoFarmLevelReal then
            BringMobFarm = false
            continue
        end

        pcall(function()
            local character = LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local questGui = LocalPlayer.PlayerGui:FindFirstChild("Main")
            questGui = questGui and questGui:FindFirstChild("Quest")
            if not root or not questGui then return end

            local q = QuestCheck()
            if not q or not q[2] then return end

            if questGui.Visible then
                local mob = workspace.Enemies:FindFirstChild(q[3])

                if mob and mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart") and mob.Humanoid.Health > 0 then
                    local title = questGui:FindFirstChild("Container")
                    title = title and title:FindFirstChild("QuestTitle")
                    title = title and title:FindFirstChild("Title")

                    if title and not string.find(title.Text, q[6] or q[3], 1, true) then
                        ReplicatedStorage.Remotes.CommF_:InvokeServer("AbandonQuest")
                        BringMobFarm = false
                        return
                    end

                    PosMon = mob.HumanoidRootPart.CFrame
                    BringMobFarm = true
                    equipWeapon()
                    toTarget(mob.HumanoidRootPart.CFrame * CFrame.new(0, 30, 5))
                else
                    BringMobFarm = false
                    local points = q[7]

                    if points and #points > 0 then
                        if SetCFarme > #points then SetCFarme = 1 end
                        toTarget(points[SetCFarme] * CFrame.new(0, 30, 5))

                        if (points[SetCFarme].Position - root.Position).Magnitude <= 50 then
                            SetCFarme += 1
                            if SetCFarme > #points then SetCFarme = 1 end
                        end
                    else
                        -- No spawn point found: return to the quest NPC.
                        toTarget(q[2])
                    end
                end
            else
                BringMobFarm = false

                local points = q[7]
                local spawnPoint = points and points[1]
                local lastSpawn = LocalPlayer.Data:FindFirstChild("LastSpawnPoint")
                local island = spawnPoint and getIsland(spawnPoint.Position)

                if spawnPoint and lastSpawn and island and lastSpawn.Value == tostring(island) then
                    ReplicatedStorage.Remotes.CommF_:InvokeServer("StartQuest", q[4], q[1])
                    task.wait(0.5)
                    toTarget(spawnPoint * CFrame.new(0, 30, 20))
                else
                    toTarget(q[2])

                    if (q[2].Position - root.Position).Magnitude <= 20 then
                        ReplicatedStorage.Remotes.CommF_:InvokeServer("StartQuest", q[4], q[1])
                        task.wait(0.5)
                        if spawnPoint then
                            toTarget(spawnPoint * CFrame.new(0, 30, 20))
                        end
                    end
                end
            end
        end)
    end
end)

-- Stop movement immediately when disabled.
task.spawn(function()
    while task.wait(0.1) do
        if not _G.AutoFarmLevelReal and tween then
            pcall(function() tween:Cancel() end)
            tween = nil
        end
    end
end)

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "SimpleAutoLevelFarm"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(240, 135)
frame.Position = UDim2.new(0.5, -120, 0.5, -67)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 38)
title.BackgroundTransparency = 1
title.Text = "Auto Level Farm"
title.TextColor3 = Color3.new(1,1,1)
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.Parent = frame

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(0, 36)
status.Size = UDim2.new(1, 0, 0, 25)
status.BackgroundTransparency = 1
status.Text = "Status: STOPPED"
status.TextColor3 = Color3.fromRGB(255, 90, 90)
status.TextSize = 14
status.Font = Enum.Font.Gotham
status.Parent = frame

local start = Instance.new("TextButton")
start.Position = UDim2.fromOffset(12, 72)
start.Size = UDim2.fromOffset(102, 45)
start.Text = "START"
start.TextSize = 15
start.Font = Enum.Font.GothamBold
start.TextColor3 = Color3.new(1,1,1)
start.BackgroundColor3 = Color3.fromRGB(45, 150, 75)
start.Parent = frame

local stop = Instance.new("TextButton")
stop.Position = UDim2.fromOffset(126, 72)
stop.Size = UDim2.fromOffset(102, 45)
stop.Text = "STOP"
stop.TextSize = 15
stop.Font = Enum.Font.GothamBold
stop.TextColor3 = Color3.new(1,1,1)
stop.BackgroundColor3 = Color3.fromRGB(180, 55, 55)
stop.Parent = frame

for _, b in ipairs({start, stop}) do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = b
end

start.MouseButton1Click:Connect(function()
    _G.AutoFarmLevelReal = true
    _G.StartFarm = true
    status.Text = "Status: RUNNING"
    status.TextColor3 = Color3.fromRGB(90, 255, 120)
end)

stop.MouseButton1Click:Connect(function()
    _G.AutoFarmLevelReal = false
    _G.StartFarm = false
    BringMobFarm = false
    if tween then pcall(function() tween:Cancel() end) end
    tween = nil
    status.Text = "Status: STOPPED"
    status.TextColor3 = Color3.fromRGB(255, 90, 90)
end)

-- Drag the GUI.
local UIS = game:GetService("UserInputService")
local dragging, dragStart, startPos

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)
