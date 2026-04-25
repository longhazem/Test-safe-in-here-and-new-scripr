-- ========== HITBOX CHỈ MALE NPC ==========
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local HitboxSize = 20
local Enabled = false
local ModifiedParts = {}
local OriginalSizes = {}

-- Metatable Hook
local mt = getrawmetatable(game)
local old = mt.__index
setreadonly(mt, false)
mt.__index = newcclosure(function(t, k)
    if k == "Size" and ModifiedParts[t] then
        return OriginalSizes[t] or Vector3.new(1,1,1)
    end
    return old(t, k)
end)
setreadonly(mt, true)

local function GetHead(Model)
    return Model:FindFirstChild("Head") or Model:FindFirstChild("HumanoidRootPart")
end

local function IsAlive(Model)
    local hum = Model:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function IsMaleNPC(Model)
    local name = Model.Name:lower()
    return name:find("male") or (Model:FindFirstChildOfClass("Humanoid") and not game.Players:GetPlayerFromCharacter(Model))
end

local function UpdateHitbox()
    if not Enabled then
        for part in pairs(ModifiedParts) do
            if part and part.Parent then
                part.Size = OriginalSizes[part]
                part.Transparency = 0
                part.CanCollide = true
            end
        end
        ModifiedParts = {}
        return
    end

    local size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
    
    -- ✅ CHỈ NPC "male"
    for _, model in pairs(Workspace:GetChildren()) do
        if model:IsA("Model") and IsMaleNPC(model) and IsAlive(model) then
            local head = GetHead(model)
            if head and head:IsA("BasePart") then
                local dist = (head.Position - Camera.CFrame.Position).Magnitude
                if dist <= 1000 then -- 1000 studs
                    if not ModifiedParts[head] then
                        OriginalSizes[head] = head.Size
                        ModifiedParts[head] = true
                    end
                    head.Size = size
                    head.Transparency = 0.3
                    head.CanCollide = false
                    head.Color = Color3.new(1, 0, 0) -- ĐỎ
                end
            end
        end
    end
end

-- Loop 10Hz
task.spawn(function()
    while task.wait(0.1) do
        pcall(UpdateHitbox)
    end
end)

-- API
getgenv().MaleHitbox = {
    Toggle = function() Enabled = not Enabled end,
    SetSize = function(s) HitboxSize = math.clamp(s, 5, 50) end
}

print("✅ Male NPC Hitbox Loaded!")
print("getgenv().MaleHitbox.Toggle() -- BẬT/TẮT")
print("getgenv().MaleHitbox.SetSize(30) -- SIZE")
