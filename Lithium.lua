local getgenv = getgenv or function() return _G end
local identifyexecutor = identifyexecutor or function() return "Unknown" end
local Drawing = Drawing or {}

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local lighting = game:GetService("Lighting")

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local centerPosition = camera.ViewportSize / 2
local playerGui = localPlayer:WaitForChild("PlayerGui")

local hitboxSize = 20
local activeNPCs = {}
local trackedParts = {}
local originalSizes = {}
local wallConnections = {}

local wallEnabled       = false
local outlineEnabled    = false
local silentEnabled     = false
local showHitbox        = false
local fullBrightEnabled = false
local alwaysDayEnabled  = false
local fastScanEnabled   = false
local nvgEnabled        = false
local noBobEnabled      = false
local isUnloaded        = false
local patchOptions = {
    recoil    = false,
    firemodes = false,
    rapidFire = false,
    rpmValue  = 1000
}

local silentAimEnabled  = false
local antiDamageEnabled = false
local fovRadius         = 180
local showFovCircle     = true
local fovCircle         = nil

local maleColor         = Color3.fromRGB(0, 255, 0)
local zombieColor       = Color3.fromRGB(255, 0, 0)
local hitboxVisualColor = Color3.fromRGB(255, 0, 0)
local noFogConnection   = nil

--------------------------------------------------------------------------------
-- BRM5 HITBOX EXPANDER — State
-- ModifiedParts : part đang bị expand   → [BasePart] = true
-- HBOriginalSizes : size gốc trước expand → [BasePart] = Vector3
-- Dùng prefix HB để tránh đụng với originalSizes của hitbox cũ
--------------------------------------------------------------------------------
local HBModifiedParts  = {}
local HBOriginalSizes  = {}

-- Biến điều khiển từ UI
local hbExpanderEnabled = false
local hbExpanderSize    = 4       -- studs (mỗi chiều)
local hbShowVisual      = false   -- hiển thị hitbox trong suốt
local hbTeamCheck       = false   -- không expand đồng đội

--------------------------------------------------------------------------------
-- BRM5 HITBOX EXPANDER — Metamethod Hook
-- Khi game đọc .Size của part đang bị expand → trả về size GỐC
-- Điều này giúp server/logic nội bộ nhìn thấy hitbox bình thường
-- trong khi vật lý client thực sự to hơn
--------------------------------------------------------------------------------
local _mt = getrawmetatable(game)
local _old_index = _mt.__index
setreadonly(_mt, false)

_mt.__index = newcclosure(function(t, k)
    if k == "Size" and HBModifiedParts[t] then
        return HBOriginalSizes[t] or Vector3.new(1, 1, 1)
    end
    return _old_index(t, k)
end)

setreadonly(_mt, true)

--------------------------------------------------------------------------------
-- BRM5 HITBOX EXPANDER — Restore tất cả parts
--------------------------------------------------------------------------------
local function HB_RestoreAll()
    for part, _ in pairs(HBModifiedParts) do
        if part and part.Parent then
            part.Size         = HBOriginalSizes[part]
            part.Transparency = 1
            part.CanCollide   = true
        end
        HBModifiedParts[part] = nil
        HBOriginalSizes[part] = nil
    end
end

--------------------------------------------------------------------------------
-- BRM5 HITBOX EXPANDER — Expand một model cụ thể
-- Nhận vào model (Instance) và head (BasePart)
-- Expand head, không expand bản thân, restore nếu chết hoặc quá xa
--------------------------------------------------------------------------------
local function HB_ExpandModel(model, head, camPos, expansion)
    if not head or not head:IsA("BasePart") then return end
    if model == localPlayer.Character then return end

    -- Team check (tùy chọn)
    if hbTeamCheck then
        local targetPlayer = Players:GetPlayerFromCharacter(model)
        if targetPlayer and targetPlayer.Team == localPlayer.Team then
            -- Đồng đội → restore
            if HBModifiedParts[head] then
                head.Size         = HBOriginalSizes[head]
                head.Transparency = 1
                head.CanCollide   = true
                HBModifiedParts[head] = nil
                HBOriginalSizes[head] = nil
            end
            return
        end
    end

    -- Kiểm tra khoảng cách
    local offset  = head.Position - camPos
    local distSqr = offset:Dot(offset)
    if distSqr < 25 then return end  -- self-check

    -- Quá xa (>1000 studs) → restore
    if distSqr > 1000000 then
        if HBModifiedParts[head] then
            head.Size         = HBOriginalSizes[head]
            head.Transparency = 1
            head.CanCollide   = true
            HBModifiedParts[head] = nil
            HBOriginalSizes[head] = nil
        end
        return
    end

    -- Lần đầu expand → lưu size gốc
    if not HBModifiedParts[head] then
        HBModifiedParts[head] = true
        HBOriginalSizes[head] = head.Size
        head.CanCollide = false
    end

    -- Apply size
    if head.Size ~= expansion then
        head.Size = expansion
    end

    -- Hiển thị visual (trong suốt một phần) nếu bật
    local wantedTransparency = hbShowVisual and 0.5 or 1
    if head.Transparency ~= wantedTransparency then
        head.Transparency = wantedTransparency
    end
    if hbShowVisual then
        head.Color    = hitboxVisualColor
        head.Material = Enum.Material.Neon
    end
    if head.CanCollide then head.CanCollide = false end
end

--------------------------------------------------------------------------------
-- BRM5 HITBOX EXPANDER — Main update (duyệt tất cả NPC đang track)
-- Gọi mỗi 1 giây để tránh lag
--------------------------------------------------------------------------------
local function HB_Update()
    if not hbExpanderEnabled then
        HB_RestoreAll()
        return
    end

    local sizeVal   = hbExpanderSize
    local expansion = Vector3.new(sizeVal, sizeVal, sizeVal)
    local camPos    = camera.CFrame.Position

    -- Duyệt activeNPCs (hệ thống NPC tracking của script gốc)
    for model, data in pairs(activeNPCs) do
        if model and model.Parent then
            local head = model:FindFirstChild("Head")
                or model:FindFirstChild("Root")
                or (data and data.head)
            HB_ExpandModel(model, head, camPos, expansion)
        end
    end

    -- Duyệt thêm characters của tất cả players (PvP)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and p.Character then
            local char = p.Character
            local head = char:FindFirstChild("Head")
            HB_ExpandModel(char, head, camPos, expansion)
        end
    end
end

-- Loop throttle 1 giây
task.spawn(function()
    while not isUnloaded do
        pcall(HB_Update)
        task.wait(1)
    end
    -- Cleanup khi unload
    pcall(HB_RestoreAll)
    pcall(function()
        setreadonly(_mt, false)
        _mt.__index = _old_index
        setreadonly(_mt, true)
    end)
end)

--------------------------------------------------------------------------------
-- ÂM THANH
--------------------------------------------------------------------------------
local activeLoopingSounds = {}

local function playSound(soundId, isLoop)
    if isLoop and activeLoopingSounds[soundId] then return end
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. tostring(soundId)
    sound.Parent  = SoundService
    sound.Volume  = 1
    sound.Looped  = isLoop or false
    sound:Play()
    if isLoop then
        activeLoopingSounds[soundId] = sound
    else
        sound.Ended:Connect(function() sound:Destroy() end)
    end
    return sound
end

local function stopSound(soundId)
    if activeLoopingSounds[soundId] then
        activeLoopingSounds[soundId]:Stop()
        activeLoopingSounds[soundId]:Destroy()
        activeLoopingSounds[soundId] = nil
    end
end

local function clearNVG(gui)
    if nvgEnabled and gui:IsA("ScreenGui") and gui.Name == "NVGInterface" then
        gui:Destroy()
    end
end

playerGui.ChildAdded:Connect(clearNVG)

pcall(function()
    if Drawing.new then
        fovCircle = Drawing.new("Circle")
        fovCircle.Visible   = false
        fovCircle.Filled    = false
        fovCircle.Position  = centerPosition
        fovCircle.Radius    = fovRadius
        fovCircle.Thickness = 1.5
        fovCircle.Color     = Color3.new(1, 1, 1)
    end
end)

--------------------------------------------------------------------------------
-- PATCH WEAPONS
--------------------------------------------------------------------------------
local function patchWeapons()
    pcall(function()
        local weaponsFolder = RS:FindFirstChild("Shared")
            and RS.Shared:FindFirstChild("Configs")
            and RS.Shared.Configs:FindFirstChild("Weapon")
            and RS.Shared.Configs.Weapon:FindFirstChild("Weapons_Player")
        if not weaponsFolder then return end
        for _, platform in pairs(weaponsFolder:GetChildren()) do
            if platform.Name:match("^Platform_") then
                for _, weapon in pairs(platform:GetChildren()) do
                    for _, child in pairs(weapon:GetChildren()) do
                        if child:IsA("ModuleScript") and child.Name:match("^Receiver%.") then
                            task.spawn(function()
                                local success, receiver = pcall(require, child)
                                if success and receiver and receiver.Config and receiver.Config.Tune then
                                    local tune = receiver.Config.Tune
                                    if patchOptions.recoil then
                                        tune.Recoil_X           = 0
                                        tune.Recoil_Z           = 0
                                        tune.RecoilForce_Tap    = 0
                                        tune.RecoilForce_Impulse= 0
                                        tune.Recoil_Range       = Vector2.zero
                                        tune.Recoil_Camera      = 0
                                    end
                                    if patchOptions.firemodes then
                                        tune.Firemodes = {3, 2, 1, 0}
                                    end
                                    if patchOptions.rapidFire then
                                        tune.RoF = patchOptions.rpmValue
                                    end
                                end
                            end)
                        end
                    end
                end
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- VISIBILITY / NPC UTILS
--------------------------------------------------------------------------------
local function isVisible(targetModel)
    if not targetModel or not targetModel:FindFirstChild("Head") then return false end
    local ignoreList = {localPlayer.Character, targetModel}
    local obscuringParts = camera:GetPartsObscuringTarget({targetModel.Head.Position}, ignoreList)
    return #obscuringParts == 0
end

local function getClosestNPC()
    local closestNPC, closestDistance = nil, fovRadius
    for model, data in pairs(activeNPCs) do
        if model.Parent and data.head then
            local pos, onScreen = camera:WorldToViewportPoint(data.head.Position)
            if onScreen then
                local distance = (Vector2.new(pos.X, pos.Y) - centerPosition).Magnitude
                if distance <= fovRadius and distance < closestDistance then
                    if isVisible(model) then
                        closestNPC     = model
                        closestDistance = distance
                    end
                end
            end
        end
    end
    return closestNPC
end

--------------------------------------------------------------------------------
-- GAME HOOKS
--------------------------------------------------------------------------------
task.spawn(function()
    pcall(function()
        local getMuzzle = filtergc('function', {Name = 'GetMuzzleCFrame'}, true)
        local getRecoil = filtergc('function', {Name = 'getRecoil'}, true)

        if getMuzzle then
            local oldMuzzle; oldMuzzle = hookfunction(getMuzzle, function(self, cast)
                local origin, barrel, cameraCF = oldMuzzle(self, cast)
                if silentAimEnabled and not cast and origin then
                    local npc = getClosestNPC()
                    if npc and npc:FindFirstChild("Head") then
                        return CFrame.new(origin.Position, npc.Head.Position), barrel, cameraCF
                    end
                end
                return origin, barrel, cameraCF
            end)
        end

        if getRecoil then
            local oldRecoil; oldRecoil = hookfunction(getRecoil, function(...)
                local args = {...}
                if silentAimEnabled and args[1] then
                    args[1]['Barrel_Spread']    = 0
                    args[1]['RecoilForce_Tap']  = 0
                end
                return oldRecoil(unpack(args))
            end)
        end

        local characterCamera = filtergc('table', {Name = "CharacterCamera"}, true)
        if characterCamera and characterCamera.Update then
            local oldCamUpdate; oldCamUpdate = hookfunction(characterCamera.Update, function(...)
                local args = {...}
                if noBobEnabled and args[1] then
                    args[1]._shakes = {}
                    args[1]._bob    = 0
                end
                return oldCamUpdate(unpack(args))
            end)
        end

        local OldNamecall
        OldNamecall = hookmetamethod(game, "__namecall", function(Self, ...)
            local Method = getnamecallmethod()
            if antiDamageEnabled then
                if tostring(Method) == "TakeDamage" then return nil end
                if Method == "FireServer" and tostring(Self):find("Damage") then return nil end
            end
            return OldNamecall(Self, ...)
        end)

        RunService.Heartbeat:Connect(function()
            if antiDamageEnabled and localPlayer.Character then
                local root = localPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root and root.AssemblyLinearVelocity.Y < -60 then
                    root.AssemblyLinearVelocity = Vector3.new(
                        root.AssemblyLinearVelocity.X, -20, root.AssemblyLinearVelocity.Z
                    )
                end
            end
        end)
    end)
end)

--------------------------------------------------------------------------------
-- NPC TRACKING
--------------------------------------------------------------------------------
local function isValidNPC(model)
    if not model or not model.Parent then return false end
    local name    = model.Name:lower()
    local isZombie = string.find(name, "zombie") ~= nil
    local isMale   = (model.Name == "Male")
    if isMale then
        for _, c in ipairs(model:GetChildren()) do
            if c.Name:sub(1, 3) == "AI_" then return true end
        end
    end
    return isZombie
end

local function applyOutline(model)
    pcall(function()
        local highlight = model:FindFirstChild("ESP_Outline")
        if outlineEnabled and isValidNPC(model) then
            if not highlight then
                highlight      = Instance.new("Highlight")
                highlight.Name = "ESP_Outline"
                highlight.Parent = model
            end
            highlight.FillTransparency = 1
            highlight.OutlineColor     = string.find(model.Name:lower(), "zombie") and zombieColor or maleColor
            highlight.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
        else
            if highlight then highlight:Destroy() end
        end
    end)
end

local function createBoxForPart(part)
    if not part or part:FindFirstChild("Wall_Box") then return end
    local sphere       = Instance.new("SphereHandleAdornment")
    sphere.Name        = "Wall_Box"
    sphere.Radius      = 1.2
    sphere.Adornee     = part
    sphere.AlwaysOnTop = true
    sphere.ZIndex      = 10
    sphere.Transparency = 0.3
    local model = part.Parent
    if model then
        sphere.Color3 = string.find(model.Name:lower(), "zombie") and zombieColor or maleColor
    end
    sphere.Parent = part
    trackedParts[part] = true
end

local function addNPC(model)
    if activeNPCs[model] or not isValidNPC(model) then return end
    local head = model:FindFirstChild("Head")
    local root = model:FindFirstChild("Root")
        or model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("UpperTorso")
    if root then
        activeNPCs[model] = { head = head or root, root = root }
        if wallEnabled    then createBoxForPart(head or root) end
        if outlineEnabled then applyOutline(model) end
    end
end

local function applySilentHitbox(model, root)
    if not originalSizes[model] then originalSizes[model] = root.Size end
    local TARGET_SIZE = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
    if root.Size ~= TARGET_SIZE then root.Size = TARGET_SIZE end
    root.Transparency = showHitbox and 0.8 or 1
    if showHitbox then
        root.Color    = hitboxVisualColor
        root.Material = Enum.Material.Neon
    end
    root.CanCollide = true
end

local function restoreOriginalSize(model)
    local root = model:FindFirstChild("Root")
        or model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("UpperTorso")
    if root and originalSizes[model] then
        root.Size         = originalSizes[model]
        root.Transparency = 1
    end
    originalSizes[model] = nil
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name         = "⚔️🐧 Tokai Hub vietnams❤️ (Universal)",
    LoadingTitle = "Executor: " .. identifyexecutor(),
    Theme        = "bytokaivipproVN🇯🇵"
})

-- ── COMBAT TAB ───────────────────────────────────────────────────────────────
local CombatTab = Window:CreateTab("Combat ⚔️")

CombatTab:CreateToggle({
    Name = "Silent Aim (Hook)", CurrentValue = false,
    Callback = function(v) silentAimEnabled = v end
})
CombatTab:CreateToggle({
    Name = "Silent Hitbox (NPC Root)", CurrentValue = false,
    Callback = function(v) silentEnabled = v end
})
CombatTab:CreateToggle({
    Name = "Show Hitbox Visual", CurrentValue = false,
    Callback = function(v) showHitbox = v end
})
CombatTab:CreateSlider({
    Name = "Silent Hitbox Size", Range = {0, 20}, Increment = 1, CurrentValue = 20,
    Callback = function(v) hitboxSize = v end
})

-- ── BRM5 HITBOX EXPANDER (mới thêm) ─────────────────────────────────────────
CombatTab:CreateSection("── BRM5 Hitbox Expander ──")

CombatTab:CreateToggle({
    Name = "Hitbox Expander (BRM5 Hook)",
    CurrentValue = false,
    Callback = function(v)
        hbExpanderEnabled = v
        if not v then
            -- Restore ngay khi tắt, không đợi loop 1 giây
            pcall(HB_RestoreAll)
        end
    end
})

CombatTab:CreateToggle({
    Name = "Show Expander Visual (trong suốt hồng)",
    CurrentValue = false,
    Callback = function(v) hbShowVisual = v end
})

CombatTab:CreateToggle({
    Name = "Team Check (không expand đồng đội)",
    CurrentValue = false,
    Callback = function(v) hbTeamCheck = v end
})

CombatTab:CreateSlider({
    Name         = "Expander Size (studs)",
    Range        = {1, 30},
    Increment    = 1,
    CurrentValue = 4,
    Callback     = function(v)
        hbExpanderSize = v
        -- Apply ngay nếu đang bật
        if hbExpanderEnabled then pcall(HB_Update) end
    end
})

-- ── CHARACTER TAB ─────────────────────────────────────────────────────────────
local CharacterTab = Window:CreateTab("Character 👤")

CharacterTab:CreateToggle({
    Name = "Anti Fall / Anti Damage dont on it",
    CurrentValue = false,
    Callback = function(v)
        antiDamageEnabled = v
        local soundID = 139836635302855
        if v then playSound(soundID, true) else stopSound(soundID) end
    end
})

CharacterTab:CreateButton({
    Name = "Fly & Walkspeed dont click (Coming Soon)",
    Callback = function()
        playSound(109033035962147)
        Rayfield:Notify({
            Title   = "why you click",
            Content = "aishiteru This will be added soon.",
            Duration = 3,
            Image    = 4483362458,
        })
    end,
})

-- ── FOV TAB ───────────────────────────────────────────────────────────────────
local FovTab = Window:CreateTab("FOV Settings ⭕")
FovTab:CreateToggle({
    Name = "Show FOV Circle", CurrentValue = true,
    Callback = function(v) showFovCircle = v end
})
FovTab:CreateSlider({
    Name = "FOV Radius", Range = {0, 500}, Increment = 1, CurrentValue = 180,
    Callback = function(v) fovRadius = v end
})

-- ── VISIBLE TAB ───────────────────────────────────────────────────────────────
local VisibleTab = Window:CreateTab("Visible 👁️")

VisibleTab:CreateToggle({
    Name = "ESP NPC (Sphere)", CurrentValue = false,
    Callback = function(v)
        wallEnabled = v
        if v then
            for _, d in pairs(activeNPCs) do createBoxForPart(d.head) end
        else
            for part, _ in pairs(trackedParts) do
                if part:FindFirstChild("Wall_Box") then part.Wall_Box:Destroy() end
            end
            trackedParts = {}
        end
    end,
})
VisibleTab:CreateToggle({
    Name = "ESP NPC (Outline Only)", CurrentValue = false,
    Callback = function(v)
        outlineEnabled = v
        for model, _ in pairs(activeNPCs) do applyOutline(model) end
    end
})
VisibleTab:CreateToggle({
    Name = "No Bob no worrk (Camera)", CurrentValue = false,
    Callback = function(v) noBobEnabled = v end
})
VisibleTab:CreateToggle({
    Name = "NPC Scan", CurrentValue = false,
    Callback = function(v) fastScanEnabled = v end
})
VisibleTab:CreateToggle({
    Name = "Remove NVG Interface", CurrentValue = false,
    Callback = function(v)
        nvgEnabled = v
        if v then for _, gui in ipairs(playerGui:GetChildren()) do clearNVG(gui) end end
    end
})
VisibleTab:CreateToggle({
    Name = "No Fog", CurrentValue = false,
    Callback = function(v)
        local atm = lighting:FindFirstChildOfClass("Atmosphere")
        if v then
            if atm then
                noFogConnection = atm:GetPropertyChangedSignal("Density"):Connect(function()
                    atm.Density = 0
                end)
                atm.Density = 0
            end
            lighting.FogEnd = 100000
        else
            if noFogConnection then noFogConnection:Disconnect() end
            if atm then atm.Density = 0.3 end
        end
    end,
})
VisibleTab:CreateToggle({
    Name = "FullBright", CurrentValue = false,
    Callback = function(v) fullBrightEnabled = v end
})
VisibleTab:CreateToggle({
    Name = "Always Day", CurrentValue = false,
    Callback = function(v) alwaysDayEnabled = v end
})

-- ── WEAPONS TAB ───────────────────────────────────────────────────────────────
local WeaponsTab = Window:CreateTab("Weapons 🔫")
WeaponsTab:CreateToggle({
    Name = "No Recoil", CurrentValue = false,
    Callback = function(v) patchOptions.recoil = v; patchWeapons() end
})
WeaponsTab:CreateToggle({
    Name = "Unlock Firemodes", CurrentValue = false,
    Callback = function(v) patchOptions.firemodes = v; patchWeapons() end
})
WeaponsTab:CreateToggle({
    Name = "Rapid Fire unknown work", CurrentValue = false,
    Callback = function(v) patchOptions.rapidFire = v; patchWeapons() end
})

--------------------------------------------------------------------------------
-- BACKGROUND LOOPS (giữ nguyên từ script gốc)
--------------------------------------------------------------------------------

-- Dọn NPC đã chết
task.spawn(function()
    while not isUnloaded do
        for model, _ in pairs(activeNPCs) do
            if not model.Parent then activeNPCs[model] = nil end
        end
        task.wait(0.5)
    end
end)

-- Silent hitbox loop (hệ thống cũ — giữ nguyên)
task.spawn(function()
    while not isUnloaded do
        if silentEnabled then
            for model, data in pairs(activeNPCs) do
                if model.Parent and data.root then applySilentHitbox(model, data.root) end
            end
        else
            for model, _ in pairs(originalSizes) do restoreOriginalSize(model) end
        end
        task.wait(0.1)
    end
end)

-- Render loop
RunService.RenderStepped:Connect(function()
    if fovCircle then
        fovCircle.Visible  = (showFovCircle and silentAimEnabled)
        fovCircle.Position = camera.ViewportSize / 2
        fovCircle.Radius   = fovRadius
    end
    if fullBrightEnabled then
        lighting.Brightness     = 2
        lighting.Ambient        = Color3.new(1, 1, 1)
        lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    end
    if alwaysDayEnabled then lighting.ClockTime = 12 end
end)

-- Initial NPC scan
for _, m in ipairs(Workspace:GetDescendants()) do
    if m:IsA("Model") and isValidNPC(m) then addNPC(m) end
end
Workspace.DescendantAdded:Connect(function(m)
    if m:IsA("Model") then
        task.delay(0.1, function()
            if isValidNPC(m) then addNPC(m) end
        end)
    end
end)
