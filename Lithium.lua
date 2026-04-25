local getgenv = getgenv or function() return _G end
local identifyexecutor = identifyexecutor or function() return "Unknown" end

-- Services
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Settings
local HitboxSize = 20
local SilentAimEnabled = false
local SilentHitboxEnabled = false
local ShowHitboxVisual = false
local AntiDamageEnabled = false
local WallEnabled = false
local OutlineEnabled = false
local ShowFovCircle = true
local FovRadius = 180

-- Storage
local ActiveNPCs = {}
local ModifiedParts = {}
local OriginalSizes = {}
local TrackedParts = {}
local ActiveSounds = {}
local FovCircle = nil

-- FOV Circle
pcall(function()
    if Drawing and Drawing.new then
        FovCircle = Drawing.new("Circle")
        FovCircle.Visible = false
        FovCircle.Filled = false
        FovCircle.Thickness = 2
        FovCircle.Color = Color3.new(1, 1, 1)
        FovCircle.Radius = FovRadius
        FovCircle.Position = Camera.ViewportSize / 2
    end
end)

-- Sound System
local function PlaySound(SoundId, Looped)
    if ActiveSounds[SoundId] then return end
    
    local Sound = Instance.new("Sound")
    Sound.SoundId = "rbxassetid://" .. SoundId
    Sound.Volume = 0.5
    Sound.Looped = Looped or false
    Sound.Parent = SoundService
    Sound:Play()
    
    if Looped then
        ActiveSounds[SoundId] = Sound
    else
        Sound.Ended:Connect(function()
            Sound:Destroy()
        end)
    end
end

local function StopSound(SoundId)
    if ActiveSounds[SoundId] then
        ActiveSounds[SoundId]:Stop()
        ActiveSounds[SoundId]:Destroy()
        ActiveSounds[SoundId] = nil
    end
end

-- Hitbox Functions
local function GetCharacterRoot(Model)
    return Model:FindFirstChild("Head") or 
           Model:FindFirstChild("HumanoidRootPart") or 
           Model:FindFirstChild("RootPart") or 
           Model.PrimaryPart
end

local function IsAlive(Model)
    local Humanoid = Model:FindFirstChildOfClass("Humanoid")
    return Humanoid and Humanoid.Health > 0
end

local function UpdateHitboxes()
    if not SilentHitboxEnabled then
        -- Restore original sizes
        for Part, _ in pairs(ModifiedParts) do
            if Part and Part.Parent then
                Part.Size = OriginalSizes[Part] or Vector3.new(4, 5, 1)
                Part.Transparency = 0
                Part.CanCollide = true
                Part.Material = Enum.Material.SmoothPlastic
            end
        end
        ModifiedParts = {}
        OriginalSizes = {}
        return
    end

    local ExpansionSize = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
    local CamPos = Camera.CFrame.Position

    -- Players
    for _, Player in pairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character then
            local Character = Player.Character
            if IsAlive(Character) then
                local Head = GetCharacterRoot(Character)
                if Head and Head:IsA("BasePart") then
                    local Distance = (Head.Position - CamPos).Magnitude
                    if Distance <= 500 then
                        if not ModifiedParts[Head] then
                            OriginalSizes[Head] = Head.Size
                            ModifiedParts[Head] = true
                        end
                        Head.Size = ExpansionSize
                        Head.Transparency = ShowHitboxVisual and 0.3 or 1
                        Head.CanCollide = false
                        if ShowHitboxVisual then
                            Head.Color = Color3.new(1, 0, 0)
                            Head.Material = Enum.Material.ForceField
                        end
                    end
                end
            end
        end
    end

    -- NPCs
    for Model, _ in pairs(ActiveNPCs) do
        if Model.Parent and IsAlive(Model) then
            local Head = GetCharacterRoot(Model)
            if Head then
                if not ModifiedParts[Head] then
                    OriginalSizes[Head] = Head.Size
                    ModifiedParts[Head] = true
                end
                Head.Size = ExpansionSize
                Head.Transparency = ShowHitboxVisual and 0.3 or 1
                Head.CanCollide = false
                if ShowHitboxVisual then
                    Head.Color = Color3.new(1, 0, 0)
                    Head.Material = Enum.Material.ForceField
                end
            end
        end
    end
end

-- NPC Detection
local function IsValidNPC(Model)
    if not Model or not Model.Parent then return false end
    local Name = Model.Name:lower()
    return Name:find("zombie") or Name:find("male") or 
           Name:find("enemy") or Model:FindFirstChild("Humanoid")
end

local function AddNPC(Model)
    if ActiveNPCs[Model] or not IsValidNPC(Model) then return end
    local Head = GetCharacterRoot(Model)
    if Head then
        ActiveNPCs[Model] = {Head = Head}
    end
end

local function RemoveNPC(Model)
    ActiveNPCs[Model] = nil
end

-- NPC Scanner
RunService.Heartbeat:Connect(function()
    for _, Obj in pairs(Workspace:GetDescendants()) do
        if Obj:IsA("Model") and IsValidNPC(Obj) then
            AddNPC(Obj)
        end
    end
end)

-- Main Loops
task.spawn(function()
    while task.wait(0.1) do
        pcall(UpdateHitboxes)
    end
end)

-- FOV Update
RunService.RenderStepped:Connect(function()
    if FovCircle then
        FovCircle.Position = Camera.ViewportSize / 2
        FovCircle.Radius = FovRadius
        FovCircle.Visible = ShowFovCircle
    end
end)

-- Anti-Damage
local AntiDamageConnection
local function ToggleAntiDamage(Enabled)
    AntiDamageEnabled = Enabled
    if AntiDamageConnection then
        AntiDamageConnection:Disconnect()
    end
    
    if Enabled then
        AntiDamageConnection = RunService.Heartbeat:Connect(function()
            if LocalPlayer.Character then
                local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if Humanoid then
                    Humanoid.Health = Humanoid.MaxHealth
                end
            end
        end)
    end
end

-- MetaTable Hook for Hitbox Protection
local Mt = getrawmetatable(game)
local OldIndex = Mt.__index
setreadonly(Mt, false)

Mt.__index = newcclosure(function(Self, Key)
    if Key == "Size" and ModifiedParts[Self] then
        return OriginalSizes[Self] or Vector3.new(4, 5, 1)
    end
    return OldIndex(Self, Key)
end)

setreadonly(Mt, true)

-- Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "⚔️ Tokai Hub VN",
    LoadingTitle = "Executor: " .. identifyexecutor(),
    Theme = "Dark"
})

-- Combat Tab
local CombatTab = Window:CreateTab("Combat")
CombatTab:CreateToggle({
    Name = "Silent Hitbox", 
    CurrentValue = false, 
    Callback = function(Value)
        SilentHitboxEnabled = Value
    end
})

CombatTab:CreateToggle({
    Name = "Show Hitbox Visual", 
    CurrentValue = false, 
    Callback = function(Value)
        ShowHitboxVisual = Value
    end
})

CombatTab:CreateSlider({
    Name = "Hitbox Size", 
    Range = {10, 50}, 
    Increment = 1, 
    CurrentValue = 20, 
    Callback = function(Value)
        HitboxSize = Value
    end
})

-- Visual Tab
local VisualTab = Window:CreateTab("Visual")
VisualTab:CreateToggle({
    Name = "FOV Circle", 
    CurrentValue = true, 
    Callback = function(Value)
        ShowFovCircle = Value
    end
})

VisualTab:CreateSlider({
    Name = "FOV Size", 
    Range = {50, 500}, 
    Increment = 10, 
    CurrentValue = 180, 
    Callback = function(Value)
        FovRadius = Value
    end
})

-- Player Tab
local PlayerTab = Window:CreateTab("Player")
PlayerTab:CreateToggle({
    Name = "Anti Damage", 
    CurrentValue = false, 
    Callback = function(Value)
        ToggleAntiDamage(Value)
    end
})

PlayerTab:CreateButton({
    Name = "Rejoin",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end
})

print("✅ Tokai Hub loaded successfully!")
Rayfield:Notify({
    Title = "Loaded",
    Content = "Tokai Hub v2.0 - Ready!",
    Duration = 3,
    Image = 4483362458
})
