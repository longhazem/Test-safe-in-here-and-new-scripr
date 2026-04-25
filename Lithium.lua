local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Camera = Workspace.CurrentCamera

local HitboxSize = 25
local Enabled = true
local Parts = {}
local Sizes = {}

-- HOOK: Chặn gửi một số Event (Cân nhắc kỹ: chặn ReplicateHit có thể khiến bạn không gây được sát thương)
local mt = getrawmetatable(game)
local namecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    -- Đã sửa lỗi dính chữ (thêm dấu cách trước 'and' và 'then')
    if method == "FireServer" and self.Name == "ReplicateHit" then
        -- Lưu ý: Nếu game yêu cầu ReplicateHit để gây sát thương, bạn nên XÓA đoạn return này đi.
        return
    end
    return namecall(self, ...)
end)
setreadonly(mt, true)

local function GetHead(m)
    return m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
end

local function Update()
    if not Enabled then
        -- Trả lại kích thước cũ
        for p, _ in pairs(Parts) do
            if p and p.Parent then
                p.Size = Sizes[p] or Vector3.new(2, 1, 1)
                p.Transparency = 0
                p.CanCollide = true
                if p.Name == "Head" or p.Name == "HumanoidRootPart" then
                    -- Trả lại màu (nếu cần)
                end
            end
        end
        Parts = {}
        Sizes = {}
        return
    end

    local s = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
    
    for _, m in pairs(Workspace:GetChildren()) do
        if m:IsA("Model") then
            local n = m.Name:lower()
            local h = GetHead(m)
            
            -- Kiểm tra nếu là NPC hoặc Player
            if h and (n:find("male") or m:FindFirstChild("Humanoid")) and h:IsA("BasePart") then
                local distance = (h.Position - Camera.CFrame.Position).Magnitude
                
                if distance <= 400 then
                    -- Lưu lại kích thước gốc nếu chưa lưu
                    if not Parts[h] then
                        Sizes[h] = h.Size
                        Parts[h] = true
                    end
                    
                    -- Phóng to Hitbox
                    h.Size = s
                    h.Transparency = 0.4
                    h.CanCollide = false
                    h.Color = Color3.new(1, 0, 0)
                end
            end
        end
    end
end

-- VÒNG LẶP: Dùng RenderStepped hoặc Heartbeat thay vì while wait() sẽ mượt và chuẩn hơn
RunService.Heartbeat:Connect(function()
    local success, err = pcall(Update)
    if not success then
        warn("Lỗi Hitbox Script: ", err) -- In lỗi ra console (F9) để bạn biết bị sai ở đâu
    end
end)

print("🔴 MALE NPC HITBOX " .. tostring(HitboxSize) .. "x ON")
