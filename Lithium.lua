local Workspace=game:GetService("Workspace")
local Camera=Workspace.CurrentCamera
local HitboxSize=25
local Enabled=true
local Parts={}
local Sizes={}

-- HOOK
local mt=getrawmetatable(game)
local namecall=mt.__namecall
setreadonly(mt,false)
mt.__namecall=newcclosure(function(self,...)
    local args={...}
    local method=getnamecallmethod()
    if method=="FireServer"and self.Name=="ReplicateHit"then
        return
    end
    return namecall(self,...)
end)
setreadonly(mt,true)

local function GetHead(m)
    return m:FindFirstChild("Head")or m:FindFirstChild("HumanoidRootPart")
end

local function Update()
    if not Enabled then
        for p,_ in pairs(Parts)do
            if p and p.Parent then
                p.Size=Sizes[p]or Vector3.new(2,1,1)
                p.Transparency=0
                p.CanCollide=true
            end
        end
        Parts={}
        return
    end
    local s=Vector3.new(HitboxSize,HitboxSize,HitboxSize)
    for _,m in pairs(Workspace:GetChildren())do
        if m:IsA("Model")then
            local n=m.Name:lower()
            local h=GetHead(m)
            if h and(n:find("male")or m:FindFirstChild("Humanoid"))and h:IsA("BasePart")then
                local d=(h.Position-Camera.CFrame.Position).Magnitude
                if d<=1000 then
                    if not Parts[h]then
                        Sizes[h]=h.Size
                        Parts[h]=true
                    end
                    h.Size=s
                    h.Transparency=0.4
                    h.CanCollide=false
                    h.Color=Color3.new(1,0,0)
                end
            end
        end
    end
end

-- LOOP
while task.wait()do
    pcall(Update)
end

print("🔴 MALE NPC HITBOX 25x ON")
print("Size:",HitboxSize)
