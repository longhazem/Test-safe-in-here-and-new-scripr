        local Version = "v1.0.1"
        local Compkiller = loadstring(game:HttpGet("https://raw.githubusercontent.com/4lpaca-pin/CompKiller/refs/heads/main/src/source.luau"))();
        Compkiller:Loader("rbxassetid://120245531583106" , 2.5).yield();
        -- Silence Annoying Warnings (Aggressive)
        local oldWarn = warn
        local oldPrint = print
        getgenv().warn = function(...)
            local msg = table.concat({...}, " ")
            if msg:find("ModuleScript") or msg:find("require") or msg:find("callback") or msg:find("destroyed") or msg:find("future") then return end
            return oldWarn(...)
        end

        -- Hook game warnings as well
        -- Notification Manager --
        local Notifier = Compkiller.newNotify();

        -- Create Config Manager --
        local ConfigManager = Compkiller:ConfigManager({
            Directory = "Compkiller-UI",
            Config = "BRM5-OldScript"
        });

        -- Loading UI (Icon, Duration) - Non-blocking --
        

        local TurretConfigModule = nil
        local OriginalTurretStats = {}
        local ActiveTurretMods = { NoSpread = false, NoRecoil = false, InstantReload = false, RapidFire = false }

        -- Lightweight caching wrappers for expensive GC calls
        local _gc_cache = {}


        local _getgc_cache = { t = 0, v = nil }
        local function cached_getgc(all)
            local now = tick()
            if _getgc_cache.v and (now - _getgc_cache.t) < 5 then return _getgc_cache.v end
            local ok, res = pcall(getgc, all)
            res = ok and res or {}
            _getgc_cache.v = res
            _getgc_cache.t = now
            return res
        end

        local function cached_search_gc(type_val, options, deep)
            local res = {}
            local keys = options.Keys
            local source = cached_getgc(true)
            
            for _, v in pairs(source) do
                if type(v) == type_val then
                    local match = true
                    if keys then
                        for _, k in ipairs(keys) do
                             -- Use rawget to avoid metamethods triggering
                            if type(v) ~= "table" or rawget(v, k) == nil then
                                match = false
                                break
                            end
                        end
                    end
                    if match then table.insert(res, v) end
                end
            end
            return res
        end

        local function findModule(name)
            -- GC Search removed from here for performance. Use GetServiceRobust if GC search is needed.
            
            -- Fuzzy search
            -- Priority search in Services
            local rf = game:GetService("ReplicatedFirst")
            local RS = game:GetService("ReplicatedStorage")
            for _, flux in ipairs(rf:GetChildren()) do
                if flux.Name:find("Flux") then
                    local services = flux:FindFirstChild("Services")
                    if services then
                        for _, s in ipairs(services:GetChildren()) do
                            if s.Name:find(name) and s:IsA("ModuleScript") then return s end
                        end
                    end
                end
            end

            local function search(parent)
                if not parent then return end
                for _, child in ipairs(parent:GetChildren()) do
                    local cName = child.Name
                    if (cName:find(name, 1, true) or cName:lower():find(name:lower(), 1, true)) and child:IsA("ModuleScript") then
                        if child.Parent then return child end
                    end
                    local found = search(child)
                    if found then return found end
                end
            end
            return search(rf) or search(RS)
        end

        local function GetTurretConfig()
            if not TurretConfigModule then
                local mod = findModule("Turrets")
                if mod and mod.Parent then
                    local s, r = pcall(require, mod)
                    if s then TurretConfigModule = r end
                end
            end
            return TurretConfigModule
        end


        local function ApplyTurretMods()
            local configs = GetTurretConfig()
            if not configs then return end
            for name, stats in pairs(configs) do
                if type(stats) == "table" then
                    local function ens(s, v) 
                        if not OriginalTurretStats[name] then OriginalTurretStats[name] = {} end
                        if OriginalTurretStats[name][s] == nil then OriginalTurretStats[name][s] = v end
                    end
                    if stats.Barrel_Spread then ens("Barrel_Spread", stats.Barrel_Spread); stats.Barrel_Spread = ActiveTurretMods.NoSpread and 0 or OriginalTurretStats[name].Barrel_Spread end
                    if stats.Recoil_Base then ens("Recoil_Base", stats.Recoil_Base); stats.Recoil_Base = ActiveTurretMods.NoRecoil and Vector2.new(0,0) or OriginalTurretStats[name].Recoil_Base end
                    if stats.RPM then ens("RPM", stats.RPM); stats.RPM = ActiveTurretMods.RapidFire and math.max(OriginalTurretStats[name].RPM * 2, 2000) or OriginalTurretStats[name].RPM end
                end
            end
            
        end


        -- UI Logic Tables
        local Toggles = {}
        local Options = {}

        local function MapToggle(key, val) Toggles[key] = { Value = val } end
        local function MapOption(key, val) Options[key] = { Value = val } end

        local runtime_settings = {
            ESPEnabled = true,
            ShowNames = true,
            ShowHealth = true,
            TeamCheck = true,
            ShowPlayers = true,
            ShowZombies = true,
            ShowNPCs = true,
            ShowTracers = false,
            BoxStyle = "Full",
            HealthStyle = "Bar",
            LabelPosition = "Bottom",
            TracerOrigin = "Bottom",
            SilentAimEnabled = true,
            FOVRadius = 400,
            ShowFOV = true,
            TargetPart = "Head",
            WallCheck = true,
            NoRecoil = false,
            NoSpread = false,
            UnlockModes = false,
            AutoReload = false,
            CustomRPM = false,
            RPMValue = 800,
            InstantInteract = false,
            InstantConsumables = false,
            InfiniteAmmo = false,
            NoMovementPenalty = false,
            AlwaysDay = false,
            NoFog = false,
            MaxESPDistance = 1000
        }

        local UI_Elements = {}

        local function get_val(key)
            if Toggles[key] ~= nil then 
                local v = Toggles[key]; return (type(v) == "table" and v.Value ~= nil) and v.Value or v 
            end
            if Options[key] ~= nil then 
                local v = Options[key]; return (type(v) == "table" and v.Value ~= nil) and v.Value or v 
            end
            if UI_Elements[key] then return UI_Elements[key].Value end
            return runtime_settings[key]
        end

        local function get_bool(key)
            local val = get_val(key)
            return val == true or (type(val) == "table" and val.Value == true)
        end

        -- Initialize Defaults immediately
        MapOption('EnemyColor', Color3.fromRGB(255, 0, 0))
        MapOption('TeamColor', Color3.fromRGB(0, 255, 0))
        MapOption('ZombieColor', Color3.fromRGB(255, 165, 0))
        MapOption('NPCColor', Color3.fromRGB(191, 191, 191))
        MapOption('BoxStyle', "Full")
        MapOption('HealthStyle', "Bar")
        MapOption('LabelPosition', "Bottom")
        MapToggle('ESPEnabled', true)
        MapToggle('TeamCheck', true)
        MapToggle('ShowTeammates', false)
        MapToggle('ESPTest', false)
        MapToggle('BulletDrop', true)
        MapToggle('Prediction', true)
        MapOption('SilentAimKey', "None")
        MapOption('FOVRadius', 400)
        MapOption('TargetPart', "Head")

        getgenv().CharSettings = {
            FlyEnabled = false,
            FlySpeed = 50,
            InfStamina = false,
            WalkSpeedMult = 1,
            SprintSpeedMult = 1,
            Spinbot = false,
            SpinSpeed = 50
        }

        local Library = {
            Notify = function(self, msg, duration) 
                Notifier.new({
                    Title = "BRM5 Cheat",
                    Content = msg,
                    Duration = duration or 5,
                    Icon = "rbxassetid://120245531583106"
                });
            end,
            Unload = function(self) if Unload then Unload() end end,
            AccentColor = Color3.fromRGB(0, 85, 255)
        }

        --------------------------------------------------------------------------------
        -- SERVICES
        --------------------------------------------------------------------------------
        local players = game:GetService("Players")
        local workspace = game:GetService("Workspace")
        local run_service = game:GetService("RunService")
        local user_input_service = game:GetService("UserInputService")
        local replicated_storage = game:GetService("ReplicatedStorage")
        local lighting = game:GetService("Lighting")
        local camera = workspace.CurrentCamera
        local local_player = players.LocalPlayer
        local function update_camera()
            local newCam = workspace.CurrentCamera or workspace:FindFirstChildOfClass("Camera") or camera
            if newCam ~= camera then
                camera = newCam
            end
        end

        local Vector3_new = Vector3.new
        local CFrame_new = CFrame.new
        local RaycastParams_new = RaycastParams.new
        local tick = tick
        local typeof = typeof
        local pairs = pairs
        local ipairs = ipairs
        local math_huge = math.huge
        local math_abs = math.abs
        local math_acos = math.acos
        local math_deg = math.deg
        local math_rad = math.rad
        local math_sin = math.sin
        local math_cos = math.cos
        local math_max = math.max
        local math_min = math.min
        local math_clamp = math.clamp
        local math_floor = math.floor
        local string_byte = string.byte
        local string_char = string.char
        local string_find = string.find
        local table_insert = table.insert
        local table_clear = table.clear
        local table_find = table.find
        local pcall = pcall

        -- Lightweight cache for player->actor lookups to avoid calling replicator_service:GetFromPlayer every frame
        local player_actor_cache = {}
        -- OPTIMIZATION: Player Cache & Simulated Actor Cache
        local CachedPlayers = players:GetPlayers()
        local SimulatedActorCache = {}
        
        players.PlayerAdded:Connect(function(p) table.insert(CachedPlayers, p) end)
        players.PlayerRemoving:Connect(function(p) 
            local idx = table.find(CachedPlayers, p)
            if idx then table.remove(CachedPlayers, idx) end
            SimulatedActorCache[p] = nil
            player_actor_cache[p.UserId] = nil
        end)
        
        -- Debug / profiling counters
        local PerfStats = { processed_last = 0, processed_now = 0, cache_hits = 0, cache_misses = 0 }

        local function get_actor_from_player(p)
            if not p then return nil end
            local id = p.UserId
            local now = tick()
            local ent = player_actor_cache[id]
            
            -- Cache Hit
            if ent and (now - ent.t) < 0.5 then
                PerfStats.cache_hits = PerfStats.cache_hits + 1
                return ent.v
            end
            
            -- Cache Miss
            PerfStats.cache_misses = PerfStats.cache_misses + 1
            
            local actor = nil
            if replicator_service then
                local ok, res = pcall(function() return replicator_service:GetFromPlayer(p) end)
                if ok then actor = res end
            end

            -- Fallback: Try Character Matching if service failed
            if not actor and p.Character then
                actor = get_actor_from_character(p.Character)
            end
            
            -- Cache result (even if nil) to avoid spamming pcalls
            player_actor_cache[id] = { v = actor, t = now }
            return actor
        end

        local function get_actor_from_character(model)
            if not model then return nil end
            local p = players:GetPlayerFromCharacter(model)
            if p then return get_actor_from_player(p) end
            -- fallback: search actor_list
            if type(actor_list) == "table" then
                for a in pairs(actor_list) do
                    if a.Character == model then return a end
                end
            end
            return nil
        end
        local local_player = players.LocalPlayer

        -- Localize Math for speed
        local abs, floor, sqrt, tan, cos, sin = math.abs, math.floor, math.sqrt, math.tan, math.cos, math.sin
        local Vector3_new, Vector2_new, CFrame_new = Vector3.new, Vector2.new, CFrame.new
        local tick, os_clock = tick, os.clock

        -- Global Service Variables (declared local to this script session)
        local client_service, replicator_service, inventory_service

        -- New Fly Logic Variables
        local MovementObj = nil
        local FlySettings = { Active = false, Speed = 1, Sprint = 2.5 }
        local function update_movement_obj()
            MovementObj = nil
            pcall(function()
                -- Use polyfilled cached_search_gc (works via getgc now)
                local results = cached_search_gc("table", {Keys = {"VelocityGravity", "_localActor"}}, false)
                for _, v in pairs(results) do
                    if v._localActor and (v._localActor.Character or v._localActor._model) then
                        MovementObj = v
                        break
                    end
                end
            end)
            return MovementObj
        end

        --------------------------------------------------------------------------------
        -- CLEANUP SYSTEM
        --------------------------------------------------------------------------------
        if getgenv().BRM5_Cleanup then
            pcall(getgenv().BRM5_Cleanup)
        end

        local connections = {}
        local esp_objects = {}

        getgenv().BRM5_Cleanup = function()
            for _, conn in ipairs(connections) do
                if conn and conn.Disconnect then conn:Disconnect() end
            end
            table.clear(connections)

            for _, objs in pairs(esp_objects) do
                if objs.box then objs.box:Destroy() end
            end
            table.clear(esp_objects)

            if getgenv().BRM5_FOV_UI then
                if typeof(getgenv().BRM5_FOV_UI) == "table" and getgenv().BRM5_FOV_UI.Gui then 
                    local success = pcall(function() getgenv().BRM5_FOV_UI.Gui:Destroy() end) 
                elseif typeof(getgenv().BRM5_FOV_UI) == "Instance" then
                    pcall(function() getgenv().BRM5_FOV_UI:Destroy() end)
                end
                getgenv().BRM5_FOV_UI = nil
            end

            print("✓ Previous instance cleaned up")
        end

        local actor_list = {} 
        local team_cache = {}
        local actor_history = {} -- Stores {pos: Vector3, time: number, vel: Vector3}
        local IsUnloading = false
        local last_target_tick = 0
        local cached_target = nil

        local function add_connection(conn)
            table.insert(connections, conn)
            return conn
        end

        --------------------------------------------------------------------------------
        -- UTILS / ENGINE SERVICES
        --------------------------------------------------------------------------------

        local PacketHistory = {}
        local PacketNetworkObj = nil
        local PacketConfigName = "brm5_packets.json"

        local function get_network_obj()
            if PacketNetworkObj and rawget(PacketNetworkObj, "_key") then return PacketNetworkObj end
                    for _, v in pairs(cached_getgc(true)) do
                if type(v) == "table" and rawget(v, "_key") and rawget(v, "_code") and type(rawget(v, "_key")) == "table" then
                    PacketNetworkObj = v
                    return PacketNetworkObj
                end
            end
            return nil
        end

        local function packet_encrypt(data)
            local net = get_network_obj()
            if not net then return nil end
            local success, rawStr = pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), data)
            if not success then return nil end
            local key = net._key
            local result = ""
            for i = 1, #rawStr do
                local ki = (i % 4) + 1
                local nb = (string.byte(rawStr, i) - 32 + key[ki]) % 95 + 32
                result = result .. string.char(nb)
            end
            for i = 1, (key[5] or 79) do
                result = result .. string.char(math.random(33, 126))
            end
            return result
        end

        local function packet_decrypt(str)
            local net = get_network_obj()
            if not net or type(str) ~= "string" then return str end
            local key = net._key
            local length = #str - (key[5] or 79)
            if length <= 0 then return str end
            local r = ""
            for i = 1, length do
                local ki = (i % 4) + 1
                local nb = (string.byte(str, i) - 32 - key[ki]) % 95 + 32
                r = r .. string.char(nb)
            end
            return r
        end

        local function replay_packet(packet_data)
            local net = get_network_obj()
            if not net or not packet_data then return end
            local to_send = {}
            for k, v in pairs(packet_data) do to_send[k] = v end
            to_send[1] = net._code
            local payload = packet_encrypt(to_send)
            if payload then
                game:GetService("ReplicatedStorage").Events.RemoteEvent:FireServer(payload)
                Library:Notify("Replayed Packet (enc): " .. tostring(to_send[2]))
                return
            end
            -- Fallback: try sending raw table (some servers accept unencrypted payloads)
            local ok, err = pcall(function()
                game:GetService("ReplicatedStorage").Events.RemoteEvent:FireServer(packet_data)
            end)
            if ok then
                Library:Notify("Replayed Packet (raw): " .. tostring(packet_data[2] or "?") )
            else
                Library:Notify("Replay failed: " .. tostring(err))
            end
        end

        local Status = {
            ClientSvc = "Waiting...",
            RepSvc = "Waiting...",
            Guns = "Waiting...",
            Turrets = "Waiting...",
            Storage = "Waiting...",
            Vehicles = "Waiting..."
        }

        -- Global Service Variables
        local client_service, replicator_service, inventory_service, vehicle_service

        -- UI Labels for Diagnostics (initialized later)
        local UI_Labels = {
            Players = nil,
            Zombies = nil,
            NPCs = nil,
            Status = nil,
            Technical = nil
        }

        local function updateStatus()
            local text = string.format("C:%s|R:%s|S:%s|V:%s|T:%s", 
                Status.ClientSvc == "OK" and "OK" or "??", 
                Status.RepSvc == "OK" and "OK" or "??", 
                Status.Storage == "OK" and "OK" or "??",
                Status.Vehicles == "OK" and "OK" or "??",
                Status.Turrets == "OK" and "OK" or "??")
            if UI_Labels.Technical then UI_Labels.Technical:SetTitle("Int: " .. text) end
        end

        local function findModule(name)
            local RF = game:GetService("ReplicatedFirst")
            for _, flux_name in ipairs({"Flux_client", "Flux/client", "Flux"}) do
                local flux = RF:FindFirstChild(flux_name)
                if flux then
                    local found = flux:FindFirstChild(name, true)
                    if found then return found end
                end
            end
            local found = RF:FindFirstChild(name, true)
            if found then return found end

            local Packages = replicated_storage:FindFirstChild("Packages")
            local RequireMod = Packages and Packages:FindFirstChild("require")
            if RequireMod then
                local success, Loader = pcall(require, RequireMod)
                if success and Loader and Loader._modules and Loader._modules[name] then
                    return Loader._modules[name]
                end
            end
            
            found = replicated_storage:FindFirstChild(name, true)
            if found and found:IsA("ModuleScript") then return found end

            return nil
        end

        local function GetServiceRobust(name, keys)
            -- 1. Try finding module in game hierarchy first (Fastest)
            local mod = findModule(name)
            if mod and mod.Parent then
                local success, res = pcall(require, mod)
                if success then return res end
            end

            -- 2. Fallback to GC Search (Slow, causes lag)
            local results = {}
            results = cached_search_gc("table", {Keys = keys}, false)
            for _, t in pairs(results) do
                if t[keys[1]] ~= nil then return t end
            end
            
            return nil
        end

        task.spawn(function()
            -- One-time service initialization to prevent periodic lag
            local max_attempts = 10
            for i = 1, max_attempts do
                if not replicator_service then
                    local rep = GetServiceRobust("ReplicatorService", {"Actors", "_lastReplicate"})
                    if rep then replicator_service = rep; Status.RepSvc = "OK" end
                end

                if not client_service then
                    local cli = GetServiceRobust("ClientService", {"Clients", "LocalClient"})
                    if cli then client_service = cli; Status.ClientSvc = "OK" end
                end

                if not inventory_service then
                    local inv = GetServiceRobust("InventoryService", {"Inventories", "Primary", "Load"})
                    if inv then inventory_service = inv; Status.Storage = "OK" end
                end

                if not vehicle_service then
                    local veh = GetServiceRobust("VehicleService", {"Vehicles", "Changed"})
                    if not veh then
                        local tables = cached_search_gc("table", {Keys = {"SetSeat", "GetVehicle", "QueryHitbox"}}, false)
                        for _, t in pairs(tables) do
                            if type(t) == "table" and t.Vehicles then
                                veh = t
                                break
                            end
                        end
                    end
                    if veh then vehicle_service = veh; Status.Vehicles = "OK" end
                end

                if not TurretConfigModule then
                    local tConf = GetTurretConfig()
                    if tConf then
                        Status.Turrets = "OK"
                    else
                        Status.Turrets = "Waiting..."
                    end
                end

                updateStatus()
                
                -- If we found the critical ones, we can stop early
                if replicator_service and client_service and inventory_service then
                    break
                end
                
                task.wait(2) -- Wait a bit between attempts if not found
            end
            print("✓ Service initialization completed.")
        end)

        local part_cache = setmetatable({}, {__mode = "k"})
        local function get_part(model, name)
            if not model then return nil end
            if not part_cache[model] then part_cache[model] = {} end
            
            local cached = part_cache[model][name]
            if cached and cached.Parent == model then return cached end
            
            local p = model:FindFirstChild(name)
            if p then
                part_cache[model][name] = p
            end
            return p
        end

        local function get_team(player)
            if not player then return nil end
            
            -- Ensure client_service is available
            if not client_service then
                local s = game:GetService("ReplicatedFirst"):FindFirstChild("Flux_client", true)
                if s then
                    local svcs = s:FindFirstChild("Services")
                    if svcs then
                        local m = svcs:FindFirstChild("ClientService") or svcs:FindFirstChild("ClientClass")
                        if m then 
                             local s, r = pcall(require, m)
                             if s then client_service = r end
                        end
                    end
                end
            end

            if not client_service then return nil end

            if player == local_player then 
                local client = client_service:GetClientFromName(player.Name)
                return client and client.Squad
            end
            
            -- Check Actor Cache
            local actor = get_actor_from_player(player)
            if actor then
                if actor._Squad and (tick() - (actor._SquadTick or 0) < 5) then return actor._Squad end
                
                local client = client_service:GetClientFromName(player.Name)
                if client then
                    actor._Squad = client.Squad
                    actor._SquadTick = tick()
                    return actor._Squad
                end
            else
                -- Fallback if actor not found (e.g. spectator?)
                local client = client_service:GetClientFromName(player.Name)
                return client and client.Squad
            end
            return nil
        end

        local function is_alive(actor)
            if not actor then return false end
            
            -- Basic actor check (Lua Actor property)
            if actor.Alive == false or actor.Downed == true then return false end
            
            local model = actor.Character or actor.model
            if not model or not model.Parent then return false end
            
            -- Attribute check (Engine property)
            local hp = model:GetAttribute("Health")
            if typeof(hp) == "number" and hp <= 0 then return false end
            
            -- Humanoid check (Roblox property)
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then return false end
            
            return true
        end

        -- Poprawiony WallCheck (optimized)
        local shared_ray_params = RaycastParams.new()
        shared_ray_params.FilterType = Enum.RaycastFilterType.Exclude
        shared_ray_params.IgnoreWater = true

        -- Optimized Lighting/Atmosphere Locking (Reactive)
        local function update_lighting()
            if get_bool('AlwaysDay') then
                lighting.ClockTime = 12
            end
            if get_bool('NoFog') then
                lighting.FogEnd = 99999
                local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
                if atmosphere then
                    atmosphere.Density = 0
                    atmosphere.Haze = 0
                end
                lighting.Brightness = 2
                lighting.GlobalShadows = false
            end
        end

        add_connection(lighting.Changed:Connect(function(prop)
            if prop == "ClockTime" or prop == "FogEnd" or prop == "FogStart" then
                update_lighting()
            end
        end))

        task.spawn(function()
            while not IsUnloading do
                local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
                if atmosphere then
                    add_connection(atmosphere.Changed:Connect(function()
                        if get_bool('NoFog') then
                            atmosphere.Density = 0
                            atmosphere.Haze = 0
                        end
                    end))
                    break
                end
                task.wait(5)
            end
        end)

        -- Mega-Optimized WallCheck (Zero-Allocation + Result Caching)
        local wall_params = RaycastParams.new()
        wall_params.FilterType = Enum.RaycastFilterType.Exclude
        wall_params.IgnoreWater = true
        

        local visibility_cache_v2 = {}
        local filter_table = {camera, workspace.CurrentCamera, nil, nil, nil}
        
        local function is_visible(targetPart)
            if not targetPart then return false end
            if not get_bool('WallCheck') then return true end
            
            local now = os.clock()
            if visibility_cache_v2[targetPart] and (now - visibility_cache_v2[targetPart].last < 0.1) then
                return visibility_cache_v2[targetPart].result
            end
            
            local camPos = camera.CFrame.Position
            local targetChar = targetPart.Parent
            local myChar = local_player.Character
            
            -- Maintain a contiguous array for Raycast Filter
            filter_table[3] = myChar
            filter_table[4] = targetChar
            wall_params.FilterDescendantsInstances = filter_table
            
            local function check_ray(origin, targetPos)
                local dir = targetPos - origin
                local res = workspace:Raycast(origin, dir, wall_params)
                
                if res then
                    local hit = res.Instance
                    if hit:IsDescendantOf(targetPart.Parent) or (targetChar and hit:IsDescendantOf(targetChar)) then 
                        return true 
                    end 
                    
                    -- Optimized Wallbang (Zero allocation attempt)
                    -- Ignore transparent parts, Glass, and Doors
                    local is_glass = hit:HasTag("Prefab") and hit:GetAttribute("Prefab") == "Glass"
                    local is_door = hit:HasTag("Prefab") and hit:GetAttribute("Prefab") == "Door"
                    local is_penetrable = hit.Transparency > 0.5 or not hit.CanCollide
                    
                    if is_glass or is_penetrable or (get_bool('Wallbang') and is_door) then
                        -- Check if we can add to filter temporarily or just re-raycast from hit pos
                        -- Re-raycasting is safer than modifying global filter_table mid-loop
                        return check_ray(res.Position + dir.Unit * 0.05, targetPos)
                    end
                    return false
                end
                return true
            end

            local is_vis = false
            -- 1. Check from Camera (Visual Visibility)
            if check_ray(camPos, targetPart.Position) then
                is_vis = true
            else
                -- 2. Check from Muzzle (Shooting Visibility - Fallback)
                local firearm = getgenv().CurrentFirearm
                if firearm and firearm.Equipped and firearm.GetMuzzleCFrame then
                    -- Use a global flag instead of modifying signature to avoid breaking game logic
                    getgenv()._SilentAimInternal = true
                    local success, muzzle = pcall(function() return firearm:GetMuzzleCFrame() end)
                    getgenv()._SilentAimInternal = false
                    
                    if success and muzzle and check_ray(muzzle.Position, targetPart.Position) then
                        is_vis = true
                    end
                end
            end
            
            visibility_cache_v2[targetPart] = { last = now, result = is_vis }
            return is_vis
        end

        local stepTime = travelTime
        local ping = local_player:GetNetworkPing()

        local function update_cached_parts(actor)
            local model = actor.Character
            if model and model.Parent and model:FindFirstChild("Head") then
                actor._CachedParts = {
                    Head = model:FindFirstChild("Head"),
                    UpperTorso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso"),
                    Primary = model.PrimaryPart or model:FindFirstChild("Head")
                }
            else
                actor._CachedParts = nil
            end
            actor._LastPartsUpdate = tick()
        end

        local function register_actor(actor)
            if not actor or actor_list[actor] then return end
            actor_list[actor] = true
            
            actor._Category = actor.Zombie and "Zombie" or (actor.Owner and "Player" or "NPC")
            update_cached_parts(actor)
        end

        getgenv().NetworkSearchActive = tick()
        local currentSearchId = getgenv().NetworkSearchActive

        task.spawn(function()
            -- Network hooking needs to be robust across reloads and round resets
            local network_obj = nil
            
            -- Try shared.import first (Aggressive)
            local success, net = pcall(function() return shared.import("network") end)
            if success and net and net.FireServer then
                network_obj = net
                print("✓ Network: Found via shared.import")
            end

            if not network_obj then
                for i = 1, 30 do
                    if getgenv().NetworkSearchActive ~= currentSearchId then return end
                    
                    local gc_results = cached_search_gc("table", {Keys = {"FireServer", "InvokeServer", "_events"}}, false)
                    for _, t in pairs(gc_results) do
                        if t._events and t._events.RegisterActor then
                            network_obj = t
                            break
                        end
                    end
                    if network_obj then break end
                    task.wait(2)
                end
            end

            if network_obj and network_obj._events then
                local events = network_obj._events
                if events.RegisterActor then
                    getgenv().ActorHooked = true
                    local old_reg = events.RegisterActor
                    
                    print("✓ Network: Dispatcher connected!")
                    
                    events.RegisterActor = function(uid, ...)
                        task.spawn(function()
                            task.wait(1)
                            local actors = replicator_service and (replicator_service.Actors or replicator_service._actors)
                            if actors and actors[uid] then register_actor(actors[uid]) end
                        end)
                        return old_reg(uid, ...)
                    end
                end
            end
        end)

        task.spawn(function()
            while true do
                team_cache = {} 
                task.wait(100)
            end
        end)

        -- RELIABLE ESP SYSTEM (BoxHandleAdornment)
        local bodyParts = {"Head"}
        local esp_pool = {}
        local current_esp_folder = nil

        local function GetESPFolder()
            if current_esp_folder and current_esp_folder.Parent then 
                return current_esp_folder 
            end
            
            -- Clear invalid pool if folder died
            current_esp_folder = nil
            for _, o in pairs(esp_pool) do if o.box then o.box:Destroy() end end
            table.clear(esp_pool)
            for id, o in pairs(esp_objects) do if o.box then o.box:Destroy() end end
            table.clear(esp_objects)

            local f = Instance.new("Folder")
            f.Name = "BRM5_ESP_Safe"
            
            local done = false
            if getgenv().gethui then
                pcall(function() f.Parent = getgenv().gethui() done = true end)
            end
            if not done then
                pcall(function() f.Parent = game:GetService("CoreGui") done = true end)
            end
            if not done then
                local lp = game:GetService("Players").LocalPlayer
                if lp then
                    local pg = lp:FindFirstChild("PlayerGui")
                    if pg then f.Parent = pg end
                end
            end
            current_esp_folder = f
            return f
        end

        getgenv().BRM5_Cleanup_ESP = function()
            if current_esp_folder then current_esp_folder:Destroy() end
        end
        
        -- Cleanup hook setup previously done...

        local function create_esp_group()
            local box = Instance.new("BoxHandleAdornment")
            box.Name = "ESP_Box"
            box.AlwaysOnTop = true
            box.ZIndex = 5
            box.Transparency = 0
            local folder = GetESPFolder()
            if folder then box.Parent = folder end
            return { box = box }
        end

        local function remove_esp(id)
            local objs = esp_objects[id]
            if objs then
                if objs.box then
                    objs.box.Adornee = nil
                    objs.box.Visible = false
                end
                table.insert(esp_pool, objs)
                esp_objects[id] = nil
            end
        end

        local function init_esp_entry(id)
            if esp_objects[id] then return end
            
            local group = nil
            while #esp_pool > 0 do
                local g = table.remove(esp_pool)
                if g and g.box and g.box.Parent then -- Must have valid parent
                    group = g
                    break
                elseif g and g.box then
                    g.box:Destroy()
                end
            end
            
            if not group then
                group = create_esp_group()
            end
            
            if group then
                if group.box then group.box.Visible = false end
                esp_objects[id] = group
            end
        end

        local function render_esp(id, actor, label_text, color, is_visible_toggle, settings, cache, dist_sqr)
            if not is_visible_toggle then
                if esp_objects[id] then remove_esp(id) end
                return
            end

            local model = actor.Character
            if not model or not model.Parent or not is_alive(actor) then
                if esp_objects[id] then remove_esp(id) end
                return
            end

            if dist_sqr > (settings.MaxDistSqr or 4000000) then 
                if esp_objects[id] then remove_esp(id) end
                return
            end

            if not esp_objects[id] then 
                init_esp_entry(id)
            end
            
            local objs = esp_objects[id]
            if not objs then return end
            
            local box = objs.box
            -- Check validity
            if not box or not box.Parent then
                esp_objects[id] = nil -- Force recreation
                return
            end

            if box then
                local root = model:FindFirstChild("Head") or model.PrimaryPart
                if root then
                    -- 1. Visibility Check
                    if not box.Visible then box.Visible = true end
                    
                    -- 2. Adornee Check
                    if box.Adornee ~= root then box.Adornee = root end
                    
                    -- 3. Parent Check (Lazy fix)
                    if not box.Parent then 
                        local f = GetESPFolder()
                        if f then box.Parent = f else return end
                    end
                    
                    -- 4. Static Properties (Only set once if possible or check)
                    -- For Size, checking Magnitude diff is cheaper than writing property potentially.
                    -- But Size * 1.2 is cheap. Let's just write access check.
                    local targetSize = root.Size * 1.2
                    if (box.Size - targetSize).Magnitude > 0.01 then
                        box.Size = targetSize
                    end

                    -- Only write these once
                    if not box.AlwaysOnTop then box.AlwaysOnTop = true end
                    if box.ZIndex ~= 5 then box.ZIndex = 5 end
                    
                    -- 5. Color Check
                    if objs._lastC ~= color then
                        box.Color3 = color
                        objs._lastC = color
                    end
                else
                    if box.Visible then box.Visible = false end
                end
            end
        end


        task.spawn(function()
            local CharacterController = nil
            
            while true do
                if not CharacterController then
                    local mod = findModule("CharacterController")
                    local enumMod = findModule("Enum")
                    local envMod = findModule("EnvironmentService")
                    
                    if mod then
                        local success, result = pcall(require, mod)
                        local eSuccess, eEnum = pcall(require, enumMod)
                        local _, envResult = pcall(require, envMod or "")
                        
                        local CharHeightState = (eSuccess and eEnum and eEnum.CharacterHeightState) or { 
                            Standing = 0, 
                            Crouching = 1,
                            Proning = 2,
                            Swimming = 4,
                            Climbing = 5,
                            Falling = 7, 
                            Skydiving = 8,
                            Parachuting = 9
                        }
                        
                        if success and result and result.Update then
                            CharacterController = result

                            if not getgenv().OldCharUpdate then
                                getgenv().OldCharUpdate = CharacterController.Update
                            end
                            
                            CharacterController.Update = function(self, inputVector, deltaTime)
                                if not self or not self._localActor then return getgenv().OldCharUpdate(self, inputVector, deltaTime) end

                                -- 1. Infinite Stamina
                                if CharSettings.InfStamina then
                                    self._exhaustStart = tick()
                                    self._exhausted = tick() + 1
                                end

                                -- 2. No Movement Penalty
                                if get_bool('NoMovementPenalty') then
                                    self._localActor.SpeedPenalty = 1
                                end

                                -- 3. Speed Multipliers (Walk & Sprint)
                                local baseWeight = self._weightMulti or 1
                                local walkMult = get_val('WalkSpeedMult') or 1
                                local sprintMult = get_val('SprintSpeedMult') or 1
                                local activeMult = self.IsSprinting and sprintMult or walkMult
                                
                                -- Temporarily apply multiplier to weightMulti for native physics support
                                self._weightMulti = baseWeight * activeMult

                                if CharSettings.FlyEnabled then
                                    -- High-Performance Native Fly
                                    self.VelocityGravity = 0
                                    self.HeightState = 0 -- Standing
                                    self.IsGrounded = true
                                    
                                    local camCF = camera.CFrame
                                    local dir = Vector3_new(0, 0, 0)

                                    if inputVector.Magnitude > 0 then
                                        dir = dir + (camCF.LookVector * -inputVector.Y) + (camCF.RightVector * inputVector.X)
                                    end

                                    if user_input_service:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3_new(0, 1, 0) end
                                    if user_input_service:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3_new(0, 1, 0) end

                                    if dir.Magnitude > 0 then
                                        local flySpeedVal = tonumber(CharSettings.FlySpeed) or 50
                                        local flySprint = user_input_service:IsKeyDown(Enum.KeyCode.LeftShift) and 2.5 or 1
                                        local nextPos = self._position + (dir.Unit * flySpeedVal * flySprint * deltaTime)
                                        
                                        self._position = nextPos
                                        self._lastSafePosition = nextPos
                                        if self._localActor then
                                            self._localActor.SimulatedPosition = nextPos
                                            self._localActor.Grounded = true
                                            self._localActor.Sprinting = false
                                        end
                                    end

                                    local char = self._localActor and (self._localActor.Character or self._localActor._model)
                                    if char then
                                        local root = char:FindFirstChild("Root") or char.PrimaryPart
                                        if root then
                                             root.Velocity = Vector3_new(0,0,0)
                                             root.AssemblyLinearVelocity = Vector3_new(0,0,0)
                                             
                                             local lookDir = camCF.LookVector
                                             if get_bool('Spinbot') then
                                                 getgenv()._SpinbotYaw = (getgenv()._SpinbotYaw or 0) + (deltaTime * (get_val('SpinSpeed') or 50) * 25)
                                                 lookDir = Vector3_new(math.cos(getgenv()._SpinbotYaw), 0, math.sin(getgenv()._SpinbotYaw))
                                                 if self._localActor then 
                                                     self._localActor.Orientation = getgenv()._SpinbotYaw 
                                                     self._localActor.GoalOrientation = getgenv()._SpinbotYaw
                                                 end
                                             end

                                             root.CFrame = CFrame_new(self._position, self._position + lookDir)
                                        end
                                    end
                                    self._weightMulti = baseWeight -- Restore
                                    return 
                                end

                                 local res = getgenv().OldCharUpdate(self, inputVector, deltaTime)
                                 
                                 if get_bool('Spinbot') and self._localActor then
                                     getgenv()._SpinbotYaw = (getgenv()._SpinbotYaw or 0) + (deltaTime * (get_val('SpinSpeed') or 50) * 25)
                                     self._localActor.Orientation = getgenv()._SpinbotYaw
                                     self._localActor.GoalOrientation = getgenv()._SpinbotYaw
                                 end

                                 -- Restore base weight for the next frame's start
                                 self._weightMulti = baseWeight
                                 return res
                            end

                            if not getgenv().OldCharExhaust then
                                getgenv().OldCharExhaust = CharacterController._exhaust
                            end
                            CharacterController._exhaust = function(self, ...)
                                if CharSettings.InfStamina then
                                    return true
                                end
                                return getgenv().OldCharExhaust(self, ...)
                            end

                            print("✓ Character: Fly, Stamina & Movement hooked!")
                            break -- Found and hooked, stop the loop
                        end
                    end
                end
                task.wait(2)
                if IsUnloading then break end
            end
        end)

        -- Extra Spinbot Hook for Camera (Required for weapons/ADS)
        task.spawn(function()
            local CameraMod = nil
            while not IsUnloading do
                CameraMod = findModule("CharacterCamera")
                if CameraMod then
                    local success, CameraClass = pcall(require, CameraMod)
                    if success and CameraClass and CameraClass.Update then
                        local oldUpdate = CameraClass.Update
                        CameraClass.Update = function(self, ...)
                            local res = oldUpdate(self, ...)
                            if get_bool('Spinbot') and self._localActor then
                                local yaw = getgenv()._SpinbotYaw or 0
                                self._localActor.Orientation = yaw
                                self._localActor.GoalOrientation = yaw
                            end
                            return res
                        end
                        print("✓ Camera: Spinbot bypass hooked!")
                        break
                    end
                end
                task.wait(5)
            end
        end)

        -- Persistent Spinbot Loop (Hard Overwrite)
        task.spawn(function()
            while not IsUnloading do
                run_service.PostSimulation:Connect(function()
                    if not get_bool('Spinbot') then return end
                    local actor = get_actor_from_player(local_player)
                    if not actor then return end
                    
                    local yaw = getgenv()._SpinbotYaw or 0
                    actor.Orientation = yaw
                    actor.GoalOrientation = yaw
                    
                    local model = actor.Character or actor._model
                    if model then
                        local root = model:FindFirstChild("Root") or model.PrimaryPart
                        if root then
                            root.CFrame = CFrame_new(root.Position) * CFrame.Angles(0, yaw, 0)
                        end
                    end
                end)
                break -- Only connect once
            end
        end)

        --------------------------------------------------------------------------------
        -- MISC TAB
        --------------------------------------------------------------------------------


        local StorageMonitorUI = {
            Gui = nil,
            MainFrame = nil,
            Scroll = nil,
            Visible = false
        }

        local function RefreshStorageMonitor()
            if not StorageMonitorUI.Scroll or not StorageMonitorUI.Visible then return end
            for _, child in pairs(StorageMonitorUI.Scroll:GetChildren()) do
                if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
            end

            if not inventory_service or not inventory_service.Inventories then 
                local l = Instance.new("TextLabel", StorageMonitorUI.Scroll)
                l.Text = "Inventory Service not found or no inventories loaded."
                l.Size = UDim2.new(1, 0, 0, 30)
                l.TextColor3 = Color3.new(1,0,0)
                l.BackgroundTransparency = 1
                return 
            end

            local Accent = Library.AccentColor or Color3.fromRGB(0, 85, 255)
            local yOffset = 0

            for id, inv in pairs(inventory_service.Inventories) do
                local is_local = (id == inventory_service.Primary)
                local titleText = is_local and "My Inventory" or "Storage: " .. tostring(id)
                
                local Header = Instance.new("Frame")
                Header.Size = UDim2.new(1, -10, 0, 25)
                Header.Position = UDim2.new(0, 5, 0, yOffset)
                Header.BackgroundColor3 = Color3.fromRGB(30,30,35)
                Header.BorderSizePixel = 0
                Header.Parent = StorageMonitorUI.Scroll
                
                local Title = Instance.new("TextLabel")
                Title.Text = titleText
                Title.Size = UDim2.new(1, -10, 1, 0)
                Title.Position = UDim2.new(0, 5, 0, 0)
                Title.TextColor3 = is_local and Accent or Color3.new(1,1,1)
                Title.BackgroundTransparency = 1
                Title.Font = Enum.Font.GothamBold
                Title.TextSize = 13
                Title.TextXAlignment = Enum.TextXAlignment.Left
                Title.Parent = Header
                
                yOffset = yOffset + 27

                local hasItems = false
                for sIdx, storage in pairs(inv.Storages) do
                    for secIdx, section in pairs(storage.Sections) do
                        for pos, item in pairs(section) do
                            hasItems = true
                            local Row = Instance.new("Frame")
                            Row.Size = UDim2.new(1, -20, 0, 20)
                            Row.Position = UDim2.new(0, 15, 0, yOffset)
                            Row.BackgroundTransparency = 1
                            Row.Parent = StorageMonitorUI.Scroll

                            local ItemLbl = Instance.new("TextLabel")
                            local itemName = item.Layout and item.Layout.Name or item.Name or "Unknown Item"
                            local count = (item.MetaData and item.MetaData.Stack) or 1
                            ItemLbl.Text = "- " .. itemName .. (count > 1 and (" x" .. count) or "")
                            ItemLbl.Size = UDim2.new(1, 0, 1, 0)
                            ItemLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
                            ItemLbl.BackgroundTransparency = 1
                            ItemLbl.Font = Enum.Font.Gotham
                            ItemLbl.TextSize = 12
                            ItemLbl.TextXAlignment = Enum.TextXAlignment.Left
                            ItemLbl.Parent = Row
                            
                            yOffset = yOffset + 20
                        end
                    end
                end

                if not hasItems then
                    local Row = Instance.new("Frame")
                    Row.Size = UDim2.new(1, -20, 0, 20)
                    Row.Position = UDim2.new(0, 15, 0, yOffset)
                    Row.BackgroundTransparency = 1
                    Row.Parent = StorageMonitorUI.Scroll
                    local EmptyLbl = Instance.new("TextLabel")
                    EmptyLbl.Text = "  (Empty)"
                    EmptyLbl.Size = UDim2.new(1, 0, 1, 0)
                    EmptyLbl.TextColor3 = Color3.fromRGB(120, 120, 120)
                    EmptyLbl.BackgroundTransparency = 1
                    EmptyLbl.Font = Enum.Font.Gotham
                    EmptyLbl.TextSize = 11
                    EmptyLbl.TextXAlignment = Enum.TextXAlignment.Left
                    EmptyLbl.Parent = Row
                    yOffset = yOffset + 20
                end
                yOffset = yOffset + 10
            end

            StorageMonitorUI.Scroll.CanvasSize = UDim2.new(0, 0, 0, yOffset)
        end

        local function ToggleStorageMonitor()
            StorageMonitorUI.Visible = not StorageMonitorUI.Visible
            if StorageMonitorUI.Visible then
                if not StorageMonitorUI.Gui then
                    local Accent = Library.AccentColor or Color3.fromRGB(0, 85, 255)
                    local Screen = Instance.new("ScreenGui")
                    if gethui then Screen.Parent = gethui() else Screen.Parent = game:GetService("CoreGui") end
                    
                    local Main = Instance.new("Frame")
                    Main.Size = UDim2.new(0, 400, 0, 500)
                    Main.Position = UDim2.new(0.5, 300, 0.5, -250)
                    Main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
                    Main.BorderSizePixel = 0
                    Main.Active = true
                    Main.Draggable = true
                    Main.Parent = Screen
                    
                    local MainStroke = Instance.new("UIStroke", Main)
                    MainStroke.Color = Accent
                    MainStroke.Thickness = 1
                    
                    local Header = Instance.new("Frame")
                    Header.Size = UDim2.new(1, 0, 0, 30)
                    Header.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                    Header.BorderSizePixel = 0
                    Header.Parent = Main
                    
                    local Title = Instance.new("TextLabel")
                    Title.Text = "Storage Viewer"
                    Title.Size = UDim2.new(1, -40, 1, 0)
                    Title.Position = UDim2.new(0, 10, 0, 0)
                    Title.TextColor3 = Color3.new(1,1,1)
                    Title.BackgroundTransparency = 1
                    Title.Font = Enum.Font.GothamBold
                    Title.TextSize = 14
                    Title.TextXAlignment = Enum.TextXAlignment.Left
                    Title.Parent = Header

                    local CloseBtn = Instance.new("TextButton")
                    CloseBtn.Text = "X"
                    CloseBtn.Size = UDim2.new(0, 30, 1, 0)
                    CloseBtn.Position = UDim2.new(1, -30, 0, 0)
                    CloseBtn.BackgroundTransparency = 1
                    CloseBtn.TextColor3 = Color3.new(1,1,1)
                    CloseBtn.Parent = Header
                    CloseBtn.MouseButton1Click:Connect(function() ToggleStorageMonitor() end)
                    
                    local Scroll = Instance.new("ScrollingFrame")
                    Scroll.Size = UDim2.new(1, -10, 1, -40)
                    Scroll.Position = UDim2.new(0, 5, 0, 35)
                    Scroll.BackgroundTransparency = 1
                    Scroll.ScrollBarThickness = 2
                    Scroll.ScrollBarImageColor3 = Accent
                    Scroll.BorderSizePixel = 0
                    Scroll.Parent = Main
                    
                    StorageMonitorUI.Gui = Screen
                    StorageMonitorUI.MainFrame = Main
                    StorageMonitorUI.Scroll = Scroll
                end
                StorageMonitorUI.Gui.Enabled = true
                RefreshStorageMonitor()
            else
                if StorageMonitorUI.Gui then StorageMonitorUI.Gui.Enabled = false end
            end
        end



        local TurretConfigModule = nil
        local OriginalTurretStats = {}
        local ActiveTurretMods = {
            NoSpread = false,
            NoRecoil = false,
            CustomRPM = false,
            RPMValue = 1000
        }

        local function GetTurretConfig()
            if not TurretConfigModule then
                local mod = findModule("Turrets")
                if mod then
                    local success, result = pcall(require, mod)
                    if success then
                        TurretConfigModule = result
                    end
                end
            end
            return TurretConfigModule
        end


        local function EnsureBackup(turretName, statName, value)
            if not OriginalTurretStats[turretName] then OriginalTurretStats[turretName] = {} end
            if OriginalTurretStats[turretName][statName] == nil then
                OriginalTurretStats[turretName][statName] = value
            end
        end

        local function ApplyTurretMods()
            local configs = GetTurretConfig()
            if not configs then return end

            for name, stats in pairs(configs) do
                if type(stats) == "table" then
                    if stats.Barrel_Spread then
                        EnsureBackup(name, "Barrel_Spread", stats.Barrel_Spread)
                        stats.Barrel_Spread = ActiveTurretMods.NoSpread and 0 or OriginalTurretStats[name].Barrel_Spread
                    end

                    if stats.Recoil_Base then
                        EnsureBackup(name, "Recoil_Base", stats.Recoil_Base)
                        stats.Recoil_Base = ActiveTurretMods.NoRecoil and Vector2.new(0, 0) or OriginalTurretStats[name].Recoil_Base
                    end
                    if stats.Recoil_Range then
                        EnsureBackup(name, "Recoil_Range", stats.Recoil_Range)
                        stats.Recoil_Range = ActiveTurretMods.NoRecoil and Vector2.new(0, 0) or OriginalTurretStats[name].Recoil_Range
                    end
                    if stats.Recoil_Camera then
                        EnsureBackup(name, "Recoil_Camera", stats.Recoil_Camera)
                        stats.Recoil_Camera = ActiveTurretMods.NoRecoil and 0 or OriginalTurretStats[name].Recoil_Camera
                    end
                    if stats.Recoil_Kick then
                        EnsureBackup(name, "Recoil_Kick", stats.Recoil_Kick)
                        stats.Recoil_Kick = ActiveTurretMods.NoRecoil and 0 or OriginalTurretStats[name].Recoil_Kick
                    end

                    if stats.RPM then
                        EnsureBackup(name, "RPM", stats.RPM)
                        if ActiveTurretMods.CustomRPM then
                            stats.RPM = ActiveTurretMods.RPMValue
                        else
                            stats.RPM = OriginalTurretStats[name].RPM
                        end
                    end
                end
            end
        end




        --------------------------------------------------------------------------------
        -- PACKET MANAGER TAB
        --------------------------------------------------------------------------------


        local MonitorUI = {
            Gui = nil,
            MainFrame = nil,
            Scroll = nil,
            Visible = false
        }
        local MonitorNeedsRefresh = false
        local PinnedFile = "brm5_pinned.json"

        local function RefreshMonitorTable()
            if not MonitorUI.Scroll or not MonitorUI.Visible then return end
            
            for _, child in pairs(MonitorUI.Scroll:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
            end
            
            local Accent = Library.AccentColor or Color3.fromRGB(0, 85, 255)

            local display_list = {}
            for _, p in ipairs(PacketHistory) do
                if p.pinned then table.insert(display_list, p) end
            end
            for _, p in ipairs(PacketHistory) do
                if not p.pinned and #display_list < 60 then 
                    table.insert(display_list, p) 
                end
            end

            for i, packet in ipairs(display_list) do
                local Row = Instance.new("Frame")
                Row.Size = UDim2.new(1, 0, 0, 24)
                
                if packet.pinned then
                    Row.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
                    local Marker = Instance.new("Frame")
                    Marker.Size = UDim2.new(0, 2, 1, 0)
                    Marker.BackgroundColor3 = Accent
                    Marker.BorderSizePixel = 0
                    Marker.Parent = Row
                else
                    Row.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(18, 18, 18) or Color3.fromRGB(22, 22, 22)
                end
                
                Row.BorderSizePixel = 0
                Row.Parent = MonitorUI.Scroll
                
                local TimeLbl = Instance.new("TextLabel")
                TimeLbl.Size = UDim2.new(0, 55, 1, 0)
                TimeLbl.Position = UDim2.new(0, 6, 0, 0)
                TimeLbl.BackgroundTransparency = 1
                TimeLbl.Text = packet.time
                TimeLbl.TextColor3 = packet.pinned and Accent or Color3.fromRGB(160, 160, 160)
                TimeLbl.Font = Enum.Font.Code
                TimeLbl.TextSize = 12
                TimeLbl.TextXAlignment = Enum.TextXAlignment.Left
                TimeLbl.Parent = Row
                
                local NameLbl = Instance.new("TextLabel")
                NameLbl.Size = UDim2.new(1, -250, 1, 0)
                NameLbl.Position = UDim2.new(0, 65, 0, 0)
                NameLbl.BackgroundTransparency = 1
                NameLbl.Text = packet.name
                NameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                NameLbl.Font = Enum.Font.Gotham
                NameLbl.TextSize = 13
                NameLbl.TextXAlignment = Enum.TextXAlignment.Left
                NameLbl.TextTruncate = Enum.TextTruncate.AtEnd
                NameLbl.Parent = Row
                
                if packet.pinned then
                    local AliasBox = Instance.new("TextBox")
                    AliasBox.Size = UDim2.new(0, 80, 0, 16)
                    AliasBox.Position = UDim2.new(1, -260, 0.5, -8)
                    AliasBox.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
                    AliasBox.BorderColor3 = Color3.fromRGB(40, 40, 40)
                    AliasBox.Text = packet.alias or ""
                    AliasBox.PlaceholderText = "Alias"
                    AliasBox.TextColor3 = Accent
                    AliasBox.Font = Enum.Font.Gotham
                    AliasBox.TextSize = 11
                    AliasBox.Parent = Row
                    AliasBox.FocusLost:Connect(function() packet.alias = AliasBox.Text end)
                end
                
                local BtnContainer = Instance.new("Frame")
                BtnContainer.Size = UDim2.new(0, 150, 1, -4)
                BtnContainer.Position = UDim2.new(1, -155, 0, 2)
                BtnContainer.BackgroundTransparency = 1
                BtnContainer.Parent = Row
                
                local Layout = Instance.new("UIListLayout")
                Layout.FillDirection = Enum.FillDirection.Horizontal
                Layout.Padding = UDim.new(0, 4)
                Layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
                Layout.Parent = BtnContainer
                
                local function AddBtn(text, textColor, callback)
                    local Btn = Instance.new("TextButton")
                    Btn.Size = UDim2.new(0, 32, 1, 0)
                    Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                    Btn.Text = text
                    Btn.TextColor3 = textColor
                    Btn.Font = Enum.Font.Gotham
                    Btn.TextSize = 10
                    Btn.BorderSizePixel = 1
                    Btn.BorderColor3 = Color3.fromRGB(0, 0, 0)
                    Btn.Parent = BtnContainer
                    Btn.AutoButtonColor = true
                    
                    local Stroke = Instance.new("UIStroke")
                    Stroke.Color = Color3.fromRGB(60, 60, 60)
                    Stroke.Thickness = 1
                    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                    Stroke.Parent = Btn
                    
                    Btn.MouseButton1Click:Connect(callback)
                    return Btn
                end
                
                AddBtn(packet.pinned and "★" or "☆", packet.pinned and Accent or Color3.fromRGB(150,150,150), function()
                    packet.pinned = not packet.pinned
                    MonitorNeedsRefresh = true
                end)
                
                AddBtn("REP", Color3.fromRGB(200, 200, 200), function() replay_packet(packet.data) end)
                AddBtn("CPY", Color3.fromRGB(200, 200, 200), function() 
                    if setclipboard then setclipboard(packet.raw_decrypted or "") Library:Notify("Copied") end 
                end)
                AddBtn("LOG", Color3.fromRGB(200, 200, 200), function() 
                    print("Packet:", packet.raw_decrypted)
                    Library:Notify("Logged")
                end)
            end
            
            MonitorUI.Scroll.CanvasSize = UDim2.new(0, 0, 0, #display_list * 25)
        end

        task.spawn(function()
            while true do
                if MonitorNeedsRefresh then
                    MonitorNeedsRefresh = false
                    pcall(RefreshMonitorTable)
                end
                task.wait(0.2)
            end
        end)

        local function TogglePacketMonitor()
            MonitorUI.Visible = not MonitorUI.Visible
            
            if MonitorUI.Visible then
                if not MonitorUI.Gui then
                    local Accent = Library.AccentColor
                    
                    local Screen = Instance.new("ScreenGui")
                    Screen.Name = "BRM5_CheatMonitor"
                    if gethui then Screen.Parent = gethui() else Screen.Parent = game:GetService("CoreGui") end
                    
                    local Main = Instance.new("Frame")
                    Main.Name = "MainFrame"
                    Main.Size = UDim2.new(0, 550, 0, 350)
                    Main.Position = UDim2.new(0.5, -275, 0.5, -175)
                    Main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
                    Main.BorderSizePixel = 0
                    Main.Active = true
                    Main.Draggable = true
                    Main.Parent = Screen
                    
                    local MainStroke = Instance.new("UIStroke")
                    MainStroke.Name = "AccentBorder"
                    MainStroke.Color = Accent
                    MainStroke.Thickness = 1
                    MainStroke.Parent = Main
                    
                    local TopLine = Instance.new("Frame")
                    TopLine.Size = UDim2.new(1, 0, 0, 2)
                    TopLine.Position = UDim2.new(0, 0, 0, 0)
                    TopLine.BackgroundColor3 = Accent
                    TopLine.BorderSizePixel = 0
                    TopLine.Parent = Main
                    
                    local Header = Instance.new("Frame")
                    Header.Size = UDim2.new(1, 0, 0, 25)
                    Header.Position = UDim2.new(0, 0, 0, 2)
                    Header.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
                    Header.BorderSizePixel = 0
                    Header.Parent = Main
                    
                    local Title = Instance.new("TextLabel")
                    Title.Text = "Packet Monitor"
                    Title.Size = UDim2.new(1, -30, 1, 0)
                    Title.Position = UDim2.new(0, 8, 0, 0)
                    Title.BackgroundTransparency = 1
                    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
                    Title.Font = Enum.Font.GothamBold
                    Title.TextSize = 14
                    Title.TextXAlignment = Enum.TextXAlignment.Left
                    Title.Parent = Header
                    
                    local CloseBtn = Instance.new("TextButton")
                    CloseBtn.Text = "X"
                    CloseBtn.Size = UDim2.new(0, 25, 1, 0)
                    CloseBtn.Position = UDim2.new(1, -25, 0, 0)
                    CloseBtn.BackgroundTransparency = 1
                    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    CloseBtn.Font = Enum.Font.Gotham
                    CloseBtn.TextSize = 14
                    CloseBtn.Parent = Header
                    CloseBtn.MouseButton1Click:Connect(function() TogglePacketMonitor() end)
                    
                    local Inner = Instance.new("Frame")
                    Inner.Size = UDim2.new(1, -14, 1, -55)
                    Inner.Position = UDim2.new(0, 7, 0, 48)
                    Inner.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
                    Inner.BorderColor3 = Color3.fromRGB(40, 40, 40)
                    Inner.BorderSizePixel = 1
                    Inner.Parent = Main
                    
                    local ColHeader = Instance.new("Frame")
                    ColHeader.Size = UDim2.new(1, -14, 0, 18)
                    ColHeader.Position = UDim2.new(0, 7, 0, 30)
                    ColHeader.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
                    ColHeader.BorderSizePixel = 0
                    ColHeader.Parent = Main
                    
                    local function AddCol(text, x, w)
                        local l = Instance.new("TextLabel")
                        l.Text = text
                        l.Size = UDim2.new(0, w, 1, 0)
                        l.Position = UDim2.new(0, x, 0, 0)
                        l.BackgroundTransparency = 1
                        l.TextColor3 = Color3.fromRGB(200, 200, 200)
                        l.Font = Enum.Font.Gotham
                        l.TextSize = 11
                        l.TextXAlignment = Enum.TextXAlignment.Left
                        l.Parent = ColHeader
                    end
                    AddCol("TIME", 6, 50)
                    AddCol("PACKET", 65, 200)
                    AddCol("ACTIONS", 360, 100)
                    
                    local Scroll = Instance.new("ScrollingFrame")
                    Scroll.Size = UDim2.new(1, -2, 1, -2)
                    Scroll.Position = UDim2.new(0, 1, 0, 1)
                    Scroll.BackgroundTransparency = 1
                    Scroll.ScrollBarThickness = 2
                    Scroll.ScrollBarImageColor3 = Accent
                    Scroll.BorderSizePixel = 0
                    Scroll.Parent = Inner
                    
                    local ListLayout = Instance.new("UIListLayout")
                    ListLayout.Padding = UDim.new(0, 1)
                    ListLayout.Parent = Scroll
                    
                    MonitorUI.Gui = Screen
                    MonitorUI.MainFrame = Main
                    MonitorUI.Scroll = Scroll
                end
                
                MonitorUI.Gui.Enabled = true
                MonitorNeedsRefresh = true
            else
                if MonitorUI.Gui then MonitorUI.Gui.Enabled = false end
            end
        end


        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            if method == "FireServer" and self.Name == "RemoteEvent" then
                local payload = args[1]
                if type(payload) == "string" then
                    task.spawn(function()
                        local raw = packet_decrypt(payload)
                        local success, data = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), raw)
                        
                        if success and type(data) == "table" then
                            -- Packet sniffer behavior (only when enabled)
                            if get_bool('PacketSnifferEnabled') then
                                local entry = {
                                    name = tostring(data[2] or "Unknown"),
                                    uuid = tostring(data[3] or "N/A"),
                                    data = data,
                                    raw_decrypted = raw,
                                    time = os.date("%X")
                                }
                                table.insert(PacketHistory, 1, entry)
                                if #PacketHistory > 200 then table.remove(PacketHistory) end
                                if MonitorUI.Visible then MonitorNeedsRefresh = true end
                            end

                            -- Auto-lockpick disabled/removed
                        end
                    end)
                end
            end
            return oldNamecall(self, ...)
        end))


        task.spawn(function()
            while not IsUnloading do
                local p_count, z_count, n_count = 0, 0, 0
                local status = "Connecting..."

                if Status.RepSvc == "OK" then
                    status = Status.ClientSvc == "OK" and "Connected" or "Wait Client"
                    pcall(function()
                        local actors = replicator_service and (replicator_service.Actors or replicator_service._actors)
                        if actors then
                            for _, actor in pairs(actors) do
                                if actor.Zombie then z_count = z_count + 1 else n_count = n_count + 1 end
                                if not actor_list[actor] then register_actor(actor) end
                            end
                        end
                        
                        for _, p in ipairs(players:GetPlayers()) do
                            local a = get_actor_from_player(p)
                            if a then p_count = p_count + 1 end
                        end
                    end)
                end

                if UI_Labels.Players then UI_Labels.Players:SetTitle("Players: " .. p_count) end
                if UI_Labels.Zombies then UI_Labels.Zombies:SetTitle("Zombies: " .. z_count) end
                if UI_Labels.NPCs then UI_Labels.NPCs:SetTitle("NPCs: " .. n_count) end
                if UI_Labels.Status then 
                    local my_sq = get_team(local_player)
                    UI_Labels.Status:SetTitle("Service: " .. status .. " | Sq: " .. (my_sq or "None")) 
                end
                
                task.wait(1)
            end
        end)



        local function process_prompt(v)
            if v:IsA("ProximityPrompt") then
                if get_bool('InstantInteract') then
                    v.HoldDuration = 0
                end
            end
        end

        add_connection(workspace.DescendantAdded:Connect(process_prompt))
        task.spawn(function()
            for i, v in ipairs(workspace:GetDescendants()) do
                process_prompt(v)
                if i % 500 == 0 then task.wait() end 
            end
        end)

        --------------------------------------------------------------------------------
        -- FOV CIRCLE
        --------------------------------------------------------------------------------
        --------------------------------------------------------------------------------
        -- FOV CIRCLE (UI Based, No Drawing API)
        --------------------------------------------------------------------------------
        local function CreateFOV()
            local Screen = Instance.new("ScreenGui")
            Screen.Name = "BRM5_FOV_UI"
            if gethui then Screen.Parent = gethui() else Screen.Parent = game:GetService("CoreGui") end
            
            local Circle = Instance.new("Frame")
            Circle.Name = "FOV"
            Circle.Size = UDim2.new(0, 800, 0, 800)
            Circle.Position = UDim2.new(0.5, 0, 0.5, 0)
            Circle.AnchorPoint = Vector2.new(0.5, 0.5)
            Circle.BackgroundTransparency = 1
            Circle.Parent = Screen
            
            local Stroke = Instance.new("UIStroke")
            Stroke.Color = Color3.fromRGB(255, 255, 255)
            Stroke.Thickness = 1
            Stroke.Transparency = 0.5
            Stroke.Parent = Circle
            
            local Corner = Instance.new("UICorner")
            Corner.CornerRadius = UDim.new(1, 0)
            Corner.Parent = Circle
            
            getgenv().BRM5_FOV_UI = { Gui = Screen, Circle = Circle, Stroke = Stroke }
            return getgenv().BRM5_FOV_UI
        end

        local FOV_Data = CreateFOV()

        add_connection(run_service.RenderStepped:Connect(function()
            local radius = (get_val('FOVRadius') or 400) * 2
            local visible = get_bool('ShowFOV') and get_bool('SilentAimEnabled')
            
            FOV_Data.Circle.Size = UDim2.new(0, radius, 0, radius)
            FOV_Data.Gui.Enabled = visible
        end))

        -- Aggressive Cleanup for Actor List (Anti-Leak)


        -- Auto Lockpick removed

        local CurrentSilentAimTarget = nil
        local BulletService = nil

        local function is_target_valid(targetPart)
            if not targetPart or not targetPart.Parent then return false end
            
            local model = targetPart.Parent
            local actor = get_actor_from_character(model)
            if not actor then
                for a in pairs(actor_list) do
                    if a.Character == model then actor = a; break end
                end
            end
            
            if not actor or not is_alive(actor) then return false end
            
            local maxFOV = get_val('FOVRadius') or 400
            local pos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
            if not onScreen or not pos then return false end
            
            local screenCenter = camera.ViewportSize / 2
            local dist = (Vector2_new(pos.X, pos.Y) - screenCenter).Magnitude^2
            if dist > (maxFOV * maxFOV) then return false end
            
            return is_visible(targetPart)
        end

        local function get_bullet_service()
            if BulletService then return BulletService end
            local mod = findModule("BulletService")
            if mod and typeof(mod) == "Instance" then
                local s, res = pcall(require, mod)
                if s then BulletService = res end
            elseif mod then
                BulletService = mod
            end
            return BulletService
        end

        local candidates = {} -- Placeholder for future logic if needed

        local function scan_for_best_target()
            if not replicator_service or not get_bool('SilentAimEnabled') then 
                CurrentSilentAimTarget = nil; return 
            end
            
            -- Keybind Check
            local saKey = get_val('SilentAimKey')
            if saKey and saKey ~= "None" and typeof(saKey) == "EnumItem" then
                if not user_input_service:IsKeyDown(saKey) then
                    CurrentSilentAimTarget = nil; return
                end
            end

            local maxFOVSqr = (get_val('FOVRadius') or 400)^2
            local screenCenter = camera.ViewportSize / 2
            local targetName = get_val('TargetPart') or "Head"
            
            local bestPart = nil
            local minFOVDist = math.huge
            local camPos = camera.CFrame.Position
            local lookDir = camera.CFrame.LookVector
            local my_team = get_team(local_player)

            -- Linear scan is much faster than sorting
            local function evaluate(actor, id)
                if not is_alive(actor) then return end
                local model = actor.Character
                if not model or model == local_player.Character then return end
                
                local cache = actor._CachedParts
                local primary = (cache and cache.Primary) or model.PrimaryPart or get_part(model, "Head")
                if not primary then return end
                
                local offset = primary.Position - camPos
                if offset:Dot(lookDir) < 0 or offset:Dot(offset) > 2250000 then return end

                -- Team Check (Cached)
                if get_bool('TeamCheck') then
                    local target_player = (typeof(id) == "number" and players:GetPlayerByUserId(id)) or actor.Owner
                    if target_player and get_team(target_player) == my_team then return end
                end

                local part = (cache and cache[targetName]) or get_part(model, targetName) or (cache and cache.Head) or get_part(model, "Head") or primary
                if not part then return end
                
                local pos, onScreen = camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local screenPos = Vector2_new(pos.X, pos.Y)
                    local fovDist = (screenPos - screenCenter):Dot(screenPos - screenCenter)
                    
                    if fovDist < maxFOVSqr and fovDist < minFOVDist then
                        if is_visible(part) then
                            minFOVDist = fovDist
                            bestPart = part
                        end
                    end
                end
            end

            local plrs = players:GetPlayers()
            for i = 1, #plrs do
                local p = plrs[i]
                if p ~= local_player then
                    local a = get_actor_from_player(p)
                    if a then evaluate(a, p.UserId) end
                end
            end
            for a in pairs(actor_list) do
                if not (a.Owner and a.Owner:IsA("Player")) then evaluate(a, a) end
            end

            CurrentSilentAimTarget = bestPart
        end

        local Recoiler = nil
        task.spawn(function()
            local rf = game:GetService("ReplicatedFirst")
            local flux = rf:FindFirstChild("ReplicatedFirst") and rf.ReplicatedFirst:FindFirstChild("Flux_client") or rf:FindFirstChild("Flux_client")
            if flux then
                local service = flux:FindFirstChild("Services")
                local vm_service = service and service:FindFirstChild("ViewmodelService")
                local recoiler_mod = vm_service and vm_service:FindFirstChild("Recoiler")
                if recoiler_mod then
                    Recoiler = require(recoiler_mod)
                    local oldImpulse = Recoiler.Impulse
                    local oldVMAdjust = Recoiler.GetViewmodelAdjustment
                    local oldCamAdjust = Recoiler.GetCameraAdjustment

                    Recoiler.Impulse = function(self, ...)
                        if get_bool('NoRecoil') then return end
                        return oldImpulse(self, ...)
                    end

                    Recoiler.GetViewmodelAdjustment = function(self, ...)
                        if get_bool('NoRecoil') then return CFrame.new() end
                        return oldVMAdjust(self, ...)
                    end

                    Recoiler.GetCameraAdjustment = function(self, ...)
                        if get_bool('NoRecoil') then return CFrame.Angles(0,0,0), 0 end
                        return oldCamAdjust(self, ...)
                    end
                    print("✓ Recoil: Hooked Recoiler class")
                end
            end
        end)

        local function ApplyGunMods(firearm)
            if not firearm or not firearm._firearm or not firearm._firearm.Tune then return end
            
            local tune = firearm._firearm.Tune
            local caliber = firearm._caliber
            
            if not tune._Originals then
                tune._Originals = {
                    Recoil_X = tune.Recoil_X,
                    Recoil_Z = tune.Recoil_Z,
                    Recoil_Camera = tune.Recoil_Camera,
                    RecoilForce_Tap = tune.RecoilForce_Tap,
                    RecoilForce_Impulse = tune.RecoilForce_Impulse,
                    Recoil_Range = tune.Recoil_Range,
                    Recoil_KickBack = tune.Recoil_KickBack,
                    Barrel_Spread = tune.Barrel_Spread,
                    Spread = tune.Spread,
                    RPM = tune.RPM,
                    Firemodes = tune.Firemodes,
                    RecoilAccelDamp_Crouch = tune.RecoilAccelDamp_Crouch,
                    RecoilAccelDamp_Prone = tune.RecoilAccelDamp_Prone,
                    Bolt = tune.Bolt,
                    Bolt_Action_Pause = tune.Bolt_Action_Pause,
                    Bolt_Action_NoPause = tune.Bolt_Action_NoPause
                }
            end

            if caliber and not caliber._Originals then
                caliber._Originals = {
                    Spread = caliber.Spread,
                    RecoilForce = caliber.RecoilForce
                }
            end
            
            if get_bool('NoRecoil') then
                if tune.Recoil_X ~= nil then tune.Recoil_X = 0 end
                if tune.Recoil_Z ~= nil then tune.Recoil_Z = 0 end
                if tune.Recoil_Camera ~= nil then tune.Recoil_Camera = 0 end
                if tune.RecoilForce_Tap ~= nil then tune.RecoilForce_Tap = 0 end
                if tune.RecoilForce_Impulse ~= nil then tune.RecoilForce_Impulse = 0 end
                if tune.Recoil_Range ~= nil then tune.Recoil_Range = Vector2.new(0,0) end
                if tune.Recoil_KickBack ~= nil then tune.Recoil_KickBack = 0 end
                if tune.RecoilAccelDamp_Crouch ~= nil then tune.RecoilAccelDamp_Crouch = Vector3.new(0,0,0) end
                if tune.RecoilAccelDamp_Prone ~= nil then tune.RecoilAccelDamp_Prone = Vector3.new(0,0,0) end
                if tune.Bolt ~= nil then tune.Bolt = 0 end
                if tune.Bolt_Action_Pause ~= nil then tune.Bolt_Action_Pause = 0 end
                if tune.Bolt_Action_NoPause ~= nil then tune.Bolt_Action_NoPause = true end
                if caliber then caliber.RecoilForce = 0 end
            else
                tune.Recoil_X = tune._Originals.Recoil_X
                tune.Recoil_Z = tune._Originals.Recoil_Z
                tune.Recoil_Camera = tune._Originals.Recoil_Camera
                tune.RecoilForce_Tap = tune._Originals.RecoilForce_Tap
                tune.RecoilForce_Impulse = tune._Originals.RecoilForce_Impulse
                tune.Recoil_Range = tune._Originals.Recoil_Range
                tune.Recoil_KickBack = tune._Originals.Recoil_KickBack
                tune.RecoilAccelDamp_Crouch = tune._Originals.RecoilAccelDamp_Crouch
                tune.RecoilAccelDamp_Prone = tune._Originals.RecoilAccelDamp_Prone
                tune.Bolt = tune._Originals.Bolt
                tune.Bolt_Action_Pause = tune._Originals.Bolt_Action_Pause
                tune.Bolt_Action_NoPause = tune._Originals.Bolt_Action_NoPause
                if caliber and caliber._Originals then caliber.RecoilForce = caliber._Originals.RecoilForce end
            end
            
            if get_bool('NoSpread') then
                if tune.Barrel_Spread ~= nil then tune.Barrel_Spread = 0 end
                if tune.Spread ~= nil then tune.Spread = 0 end
                if caliber then caliber.Spread = 0 end
            else
                tune.Barrel_Spread = tune._Originals.Barrel_Spread
                if tune.Spread ~= nil then tune.Spread = tune._Originals.Spread end
                if caliber and caliber._Originals then caliber.Spread = caliber._Originals.Spread end
            end
            
            if get_bool('CustomRPM') then
                local customRPM = tonumber(get_val('RPMValue'))
                if customRPM then
                    tune.RPM = customRPM
                end
            else
                tune.RPM = tune._Originals.RPM
            end

            if get_bool('UnlockModes') then
                tune.Firemodes = {1, 2, 3}
            else
                tune.Firemodes = tune._Originals.Firemodes
                if firearm._item and firearm._item.MetaData and firearm._item.MetaData.Mode > #tune.Firemodes then
                    firearm._item.MetaData.Mode = 1
                end
            end
        end

        task.spawn(function()
            local FirearmModule = findModule("FirearmInventory")
            local ReplicatorModule = findModule("FirearmInventoryReplicator")

            if FirearmModule then
                local FirearmClass = require(FirearmModule)
                
                if not getgenv().OldGetMuzzle then getgenv().OldGetMuzzle = FirearmClass.GetMuzzleCFrame end
                if not getgenv().OldEquip then getgenv().OldEquip = FirearmClass.Equip end
                if not getgenv().OldDischarge then getgenv().OldDischarge = FirearmClass.Discharge end
                
                local OldGetMuzzle = getgenv().OldGetMuzzle
                local OldEquip = getgenv().OldEquip
                local OldDischarge = getgenv().OldDischarge

                FirearmClass.GetMuzzleCFrame = function(self, ...)
                    local originCF, hitPoint, castResult = OldGetMuzzle(self, ...)
                    
                    -- Only redirect if NOT called internally by visibility checks and Silent Aim is active
                    if not getgenv()._SilentAimInternal and get_bool('SilentAimEnabled') and originCF then
                        local targetPart = CurrentSilentAimTarget
                        if targetPart and targetPart.Parent then
                            local targetPos = targetPart.Position
                            
                            -- Improved Prediction & Bullet Drop
                            if get_bool('Prediction') or get_bool('BulletDrop') then
                                local bs = get_bullet_service()
                                if bs and bs.GetInfo then
                                    local tune = self._firearm and self._firearm.Tune
                                    local muzzle_velocity = tune and bs:GetInfo(tune.CALIBER or tune.Caliber, tune.BARREL or tune.Barrel)
                                    
                                    if muzzle_velocity and muzzle_velocity > 0 then
                                        local originPos = originCF.Position
                                        local dist = (targetPos - originPos).Magnitude
                                        local travelTime = dist / muzzle_velocity
                                        
                                        -- 1. Velocity Prediction
                                        if get_bool('Prediction') then
                                            local model = targetPart.Parent
                                            local targetVelocity = Vector3.new(0,0,0)
                                            
                                            -- Attempt to get velocity from Actor or Character
                                            local p = players:GetPlayerFromCharacter(model)
                                            local actor = p and get_actor_from_player(p)
                                            
                                            if actor then
                                                -- Use native Direction property if available
                                                if actor.Direction and actor.Direction.Magnitude > 0 then
                                                    -- Direction is studs per frame, convert to studs per second (assuming ~60fps)
                                                    targetVelocity = Vector3.new(actor.Direction.X, 0, actor.Direction.Y) * 60
                                                end
                                            elseif model:FindFirstChild("HumanoidRootPart") then
                                                targetVelocity = model.HumanoidRootPart.Velocity
                                            end
                                            
                                            if targetVelocity.Magnitude > 0.1 then
                                                targetPos = targetPos + (targetVelocity * travelTime)
                                            end
                                        end
                                        
                                        -- 2. Bullet Drop Compensation
                                        if get_bool('BulletDrop') then
                                            local gravity = 32.2 
                                            local drop = 0.5 * gravity * (travelTime ^ 2)
                                            targetPos = targetPos + Vector3.new(0, drop, 0)
                                        end
                                    end
                                end
                            end
                            
                            originCF = CFrame.lookAt(originCF.Position, targetPos)
                        end
                    end
                    return originCF, hitPoint, castResult
                end

                FirearmClass.Discharge = function(self, ...)
                    return OldDischarge(self, ...)
                end

                FirearmClass.Equip = function(self, ...)
                    getgenv().CurrentFirearm = self
                    ApplyGunMods(self)
                    return OldEquip(self, ...)
                end
                
                Status.Guns = "OK"
                updateStatus()
                print("✓ Guns: Successfully hooked FirearmInventory")
            end



            -- Hook TurretController for Silent Aim
            task.spawn(function()
                local TurretMod = findModule("TurretController")
                if TurretMod then
                    local success, TurretClass = pcall(require, TurretMod)
                    if success and TurretClass then
                        if not getgenv().OldTurretMuzzle and TurretClass.GetMuzzleCFrame then
                            getgenv().OldTurretMuzzle = TurretClass.GetMuzzleCFrame
                        end
                        
                        if getgenv().OldTurretMuzzle then
                            TurretClass.GetMuzzleCFrame = function(self, ...)
                                local originCF = getgenv().OldTurretMuzzle(self, ...)
                                if not getgenv()._SilentAimInternal and get_bool('SilentAimEnabled') and CurrentSilentAimTarget and originCF then
                                    -- Check if target is valid
                                    if CurrentSilentAimTarget.Parent then
                                        originCF = CFrame.lookAt(originCF.Position, CurrentSilentAimTarget.Position)
                                    end
                                end
                                return originCF
                            end
                            Status.Turrets = "OK"
                            updateStatus()
                            print("✓ Turrets: Hooked Silent Aim")
                        end
                    end
                end
            end)

            if ReplicatorModule then
                local ReplicatorClass = require(ReplicatorModule)
                if not getgenv().OldRepDischarge then
                    getgenv().OldRepDischarge = ReplicatorClass.Discharge
                end
                
                local OldRepDischarge = getgenv().OldRepDischarge
                ReplicatorClass.Discharge = function(self, ...)
                    ApplyGunMods(self)
                    return OldRepDischarge(self, ...)
                end
                print("✓ Guns: Successfully hooked FirearmInventoryReplicator")
            end

            local ConsumableModule = findModule("ConsumableInventory")
            if ConsumableModule then
                local ConsumableClass = require(ConsumableModule)
                if not getgenv().OldConsumableNew then
                    getgenv().OldConsumableNew = ConsumableClass.new
                end
                local OldConsumableNew = getgenv().OldConsumableNew

                ConsumableClass.new = function(...)
                    local obj = OldConsumableNew(...)
                    if get_bool('InstantConsumables') then
                        obj._useTimer = 0
                    end
                    return obj
                end
                Status.Guns = "OK"
                updateStatus()
                print("✓ Guns: Successfully hooked ConsumableInventory")
            end
        end)

        --------------------------------------------------------------------------------
        -- MAIN RENDER LOOP (ULTRA-STABILIZED)
        --------------------------------------------------------------------------------
        local f_settings = {}
        local handled = {}
        local active_actors = {} -- Reused table for main loop
        local dummy_cache = { camPos = Vector3.new() }
        local last_gunmod_tick = 0
        local last_settings_tick = 0
        local last_sa_scan_tick = 0
        local frame_id = 0
        local colors_cache = { enemy = Color3.new(1,0,0), team = Color3.new(0,1,0), npc = Color3.new(1,1,1), zombie = Color3.new(1, 0.5, 0) }

        local function process_actor(actor, id, name, camPos, my_team, f_settings, dummy_cache, handled, now)
            -- Lazy update of cached parts (Throttle: 2s)
            if not actor._CachedParts or (now - (actor._LastPartsUpdate or 0) > 2) then
                update_cached_parts(actor)
            end

            local model = actor.Character
            if not model or not model.Parent then return end
            
            -- Skip Local Player
            if model == local_player.Character or (actor.Owner and actor.Owner == local_player) then return end

            local cache = actor._CachedParts
            local primary = (cache and cache.Primary) or model.PrimaryPart or get_part(model, "Head")
            if not primary or not primary.Parent then return end
            
            local current_pos = actor.SimulatedPosition or primary.Position
            local offset = current_pos - camPos
            local dist_sqr = offset:Dot(offset)
            
            if dist_sqr > (f_settings.MaxDistSqr or 100000000) then 
                if esp_objects[id] then remove_esp(id) end
                return 
            end

            -- Velocity Tracking (Throttled based on distance)
            local last_data = actor_history[id]
            local current_vel = primary.AssemblyLinearVelocity
            if last_data then
                local dt = now - last_data.time
                if dt > 0.02 then -- Don't calculate more than 50Hz
                    current_vel = last_data.vel:Lerp((current_pos - last_data.pos) / dt, 0.5)
                    actor_history[id] = {pos = current_pos, time = now, vel = current_vel}
                else
                    current_vel = last_data.vel
                end
            else
                actor_history[id] = {pos = current_pos, time = now, vel = current_vel}
            end
            actor.ExtractedVelocity = current_vel

            -- Team & Category Filtering (Throttle: Every 0.2s or if first time)
            if not actor._CachedVisuals or (now - (actor._LastVTick or 0) > 0.2) then
                local is_teammate = false
                
                -- ALWAYS run identification logic for visuals, regardless of "TeamCheck" setting
                local target_player = (typeof(id) == "number" and players:GetPlayerByUserId(id)) or actor.Owner
                if target_player then
                    -- 1. Custom Squad Check (Primary for BRM5)
                    local team = get_team(target_player)
                    if team and my_team and team == my_team then 
                        is_teammate = true 
                    end
                    
                    -- 2. Standard Roblox Team Check (Restored for PvP/Faction modes)
                    if not is_teammate then
                        local t1, t2 = target_player.Team, local_player.Team
                        if t1 and t2 then
                             -- Check if on same Team object
                             if t1 == t2 then
                                 is_teammate = true
                             end
                        -- Note: TeamColor check remains DISABLED to avoid "Everyone is Teammate" in Open World
                        -- unless you explicitly want color matching.
                        -- elseif target_player.TeamColor == local_player.TeamColor then
                        --     is_teammate = true
                        end
                    end

                    -- 3. Roblox Friends Check
                    if not is_teammate and local_player:IsFriendsWith(target_player.UserId) then
                        is_teammate = true
                    end
                end

                local color = colors_cache.enemy
                local visible = false
                local category = actor._Category or (actor.Zombie and "Zombie" or ((actor.Owner or typeof(id) == "number") and "Player" or "NPC"))

                if category == "Player" then
                    if is_teammate then
                        visible = f_settings.Teammates; color = colors_cache.team
                    else
                        visible = f_settings.Players
                    end
                elseif category == "Zombie" then
                    visible = f_settings.Zombies; color = colors_cache.zombie
                else -- NPC
                    visible = f_settings.NPCs; color = colors_cache.npc
                end
                actor._CachedVisuals = {color = color, visible = visible, name = name}
                actor._LastVTick = now
            end

            local visuals = actor._CachedVisuals
            if visuals then
                render_esp(id, actor, visuals.name, visuals.color, visuals.visible, f_settings, dummy_cache, dist_sqr)
            end
            handled[id] = true
        end

            -- Helper: Maintain a fast Name->Player map to optimize lookups (O(1) instead of FindFirstChild)
        local PlayerNameMap = {}
        local last_pmap_upd = 0
        local stable_count_zombies = 0
        local stable_count_npcs = 0
        
        -- Main Loop
        add_connection(run_service.RenderStepped:Connect(function()
            frame_id = frame_id + 1
            local now = tick()
            update_camera()
            local camCF = camera.CFrame
            local camPos = camCF.Position
            dummy_cache.camPos = camPos
            
            -- Update PlayerMap efficiently (every 0.5s)
            if now - last_pmap_upd > 0.5 then
                 local pm = {}
                 for _, p in ipairs(players:GetPlayers()) do
                     pm[p.Name] = p
                 end
                 PlayerNameMap = pm
                 last_pmap_upd = now
            end

            -- 1. Refresh Settings (Throttled 10Hz)
            if now - last_settings_tick > 0.1 then
                local cur_max_dist = get_val('MaxESPDistance') or 2000
                f_settings.ESP = get_bool('ESPEnabled')
                f_settings.SA = get_bool('SilentAimEnabled')
                f_settings.Players = get_bool('ShowPlayers')
                f_settings.NPCs = get_bool('ShowNPCs')
                f_settings.Zombies = get_bool('ShowZombies')
                f_settings.Teammates = get_bool('ShowTeammates')
                f_settings.MaxDistSqr = cur_max_dist * cur_max_dist
                if f_settings.MaxDistSqr <= 0 then f_settings.MaxDistSqr = 4000000 end
                f_settings.TeamCheck = get_bool('TeamCheck')
                f_settings.AutoReload = get_bool('AutoReload')

                colors_cache.enemy = (Options.EnemyColor and Options.EnemyColor.Value) or Color3.new(1,0,0)
                colors_cache.team = (Options.TeamColor and Options.TeamColor.Value) or Color3.new(0,1,0)
                colors_cache.npc = (Options.NPCColor and Options.NPCColor.Value) or Color3.new(1,1,1)
                colors_cache.zombie = (Options.ZombieColor and Options.ZombieColor.Value) or Color3.new(1, 0.5, 0)
                last_settings_tick = now
            end

            -- 2. Silent Aim Variables (Loop Fusion Init)
            local sa_bestPart = nil
            local sa_minFOVDist = math.huge
            local sa_shouldScan = false
            
            if f_settings.SA then
                sa_shouldScan = true
            else
                 CurrentSilentAimTarget = nil
            end

            local sa_maxFOVSqr = (get_val('FOVRadius') or 400)^2
            local sa_screenCenter = camera.ViewportSize / 2
            local sa_targetName = get_val('TargetPart') or "Head"
            local lookDir = camera.CFrame.LookVector -- Cached above as camPos is cached

            -- 3. Auto Reload
            if f_settings.AutoReload and getgenv().CurrentFirearm and (now - last_gunmod_tick > 0.2) then
                local weapon = getgenv().CurrentFirearm
                if ((weapon._mag and (weapon._mag.Capacity or 0) == 0) or (not weapon._mag)) and not weapon._reloading then
                    local mags = weapon:_getMags()
                    if #mags > 0 then weapon:_reload() end
                end
                last_gunmod_tick = now
            end
            
            -- 4. ESP Rendering
            if not f_settings.ESP then
                 -- If ESP is off, we still unfortunately need to iterate for Silent Aim if SA is on.
                 -- However, the code below assumes we iterate active_actors. 
                 -- If ESP is off, we might want to skip the "remove_esp" calls but we definitely need to populate active_actors if SA is on.
                 -- For now, let's keep the logic simple: We allow the loop to run if EITHER ESP or SA is on.
                 if not f_settings.SA then
                    if next(esp_objects) then for id in pairs(esp_objects) do remove_esp(id) end end
                    return
                 end
            end

            table.clear(handled)
            local my_team = get_team(local_player)

            -- Unified Processor
            table.clear(active_actors)
            
            -- OPTIMIZATION: Use cached player list to avoid GetPlayers() allocation every frame
            for _, p in ipairs(CachedPlayers) do
                if p ~= local_player then
                    local actor = get_actor_from_player(p)
                    
                    if not actor and p.Character then
                         -- Check for existing simulated actor
                         if SimulatedActorCache[p] and SimulatedActorCache[p].Character == p.Character then
                              actor = SimulatedActorCache[p]
                         else
                              -- ULTIMATE FALLBACK: Create and Cache Simulated Actor
                              local root = p.Character.PrimaryPart or p.Character:FindFirstChild("Head")
                              if root then
                                  actor = {
                                      Character = p.Character,
                                      Owner = p,
                                      Name = p.Name,
                                      Alive = true,
                                      _isSimulated = true,
                                      _CachedParts = {
                                          Head = p.Character:FindFirstChild("Head"),
                                          UpperTorso = p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso"),
                                          Primary = root
                                      }
                                  }
                                  SimulatedActorCache[p] = actor
                              end
                         end
                    end
             
                    if actor then 
                        active_actors[p.UserId] = {actor = actor, name = p.Name}
                    end
                end
            end
            
            -- Collect actors from actor_list (Secondary/Fallback + NPCs)
            -- We scan every frame to ensure Silent Aim reliability
            for actor in pairs(actor_list) do
                if not IsUnloading then
                    local model = actor.Character
                    if not model or not model.Parent then 
                        actor_list[actor] = nil
                        continue 
                    end

                    if actor.Owner then
                            -- Check if we missed this player (rare)
                            if not active_actors[actor.Owner.UserId] and actor.Owner ~= local_player then
                                active_actors[actor.Owner.UserId] = {actor = actor, name = actor.Owner.Name}
                            end
                        else
                            -- Potentially a Player without Owner ref or NPC
                            local foundPlayer = PlayerNameMap[model.Name]
                            
                            if foundPlayer and foundPlayer ~= local_player then
                                actor.Owner = foundPlayer
                                if not active_actors[foundPlayer.UserId] then
                                    active_actors[foundPlayer.UserId] = {actor = actor, name = foundPlayer.Name}
                                end
                            else
                                -- NPC / Zombie (Final Fallback)
                                local name = "NPC"
                                if actor.Zombie or (model and model.Name == "Zombie") then
                                    name = "Zombie"
                                elseif model then
                                    -- Common BRM5 NPC name patterns
                                    local mName = model.Name
                                    if string_find(mName, "Target") or string_find(mName, "Guard") or string_find(mName, "Hostage") then
                                        name = "NPC"
                                    end
                                end
                                active_actors[actor] = {actor = actor, name = name}
                            end
                        end
                    end
                end
              -- Render everything & SA Scan
            local processed = 0
            local count_players, count_zombies, count_npcs = 0, 0, 0
            
            for id, data in pairs(active_actors) do
                local ac = data.actor
                
                -- Force Owner for players to fix TeamCheck
                if not ac.Owner and typeof(id) == "number" then
                    ac.Owner = players:GetPlayerByUserId(id)
                end
                
                -- Stabilize Category based on BRM5 Actor structure
                if ac.Zombie or (ac.Character and ac.Character.Name == "Zombie") or data.name == "Zombie" then 
                    ac._Category = "Zombie"
                elseif ac.Owner or (typeof(id) == "number") then 
                    ac._Category = "Player"
                else
                    -- It's an NPC if it lacks an owner and isn't a known player ID
                    ac._Category = "NPC"
                end
                
                -- Distance Check
                local p_pos = nil
                if ac._CachedParts and ac._CachedParts.Primary then
                    p_pos = ac._CachedParts.Primary.Position
                end
                
                if p_pos then
                    -- OPTIMIZATION: Throttling ESP updates based on distance
                    local distSq = (p_pos - camPos):Dot(p_pos - camPos)
                    
                    local skip = false
                    if f_settings.ESP then
                         if distSq > 90000 then
                            local numeric_id = typeof(id) == "number" and id or processed
                            if distSq > 1000000 then
                                if frame_id % 15 ~= (numeric_id % 15) then skip = true end
                            else
                                if frame_id % 3 ~= (numeric_id % 3) then skip = true end
                            end
                        end
                    end
                    
                    if not skip and f_settings.ESP then
                        process_actor(ac, id, data.name, camPos, my_team, f_settings, dummy_cache, handled, now)
                    else
                         handled[id] = true 
                    end

                    -- SILENT AIM EVALUATION (Integrated)
                    if sa_shouldScan and is_alive(ac) then
                        -- Team Check (Using cached visuals check logic or active logic)
                        local is_enemy = true
                        if f_settings.TeamCheck then
                             if ac._Category == "Player" then
                                 local team = get_team(ac.Owner)
                                 if team and my_team and team == my_team then is_enemy = false end
                             end
                        end

                        if is_enemy then
                             -- Direction check (Optimization: Dot product)
                             local offset = p_pos - camPos
                             if offset:Dot(camera.CFrame.LookVector) > 0 and offset:Dot(offset) < 2250000 then
                                 local cache = ac._CachedParts
                                 local part = (cache and cache[sa_targetName]) or (cache and cache.Head) or (cache and cache.Primary)
                                 
                                 if part then
                                     local pos, onScreen = camera:WorldToViewportPoint(part.Position)
                                     if onScreen then
                                         local screenPos = Vector2.new(pos.X, pos.Y)
                                         local fovDist = (screenPos - sa_screenCenter).Magnitude ^ 2
                                         
                                         if fovDist < sa_maxFOVSqr and fovDist < sa_minFOVDist then
                                             if is_visible(part) then
                                                 sa_minFOVDist = fovDist
                                                 sa_bestPart = part
                                             end
                                         end
                                     end
                                 end
                             end
                        end
                    end
                end
                
                processed = processed + 1
                
                -- Statistics
                local cat = ac._Category
                if cat == "Player" then 
                    count_players = count_players + 1
                elseif cat == "Zombie" then 
                    count_zombies = count_zombies + 1
                else 
                    count_npcs = count_npcs + 1
                end
            end

            -- Update stable counts only when throttled collection runs
            if frame_id % 3 == 0 then
                stable_count_zombies = count_zombies
                stable_count_npcs = count_npcs
            end
            
            -- Final Silent Aim Assignment (After scanning all entities)
            CurrentSilentAimTarget = sa_bestPart -- Unified assignment for all methods (Turret + Gun)

            PerfStats.processed_last = PerfStats.processed_now
            PerfStats.processed_now = processed
            
            -- Update UI Counters (Directly here to prevent flickering delay)
            if now - (last_settings_tick or 0) < 0.2 then -- throttle UI update slightly
                 if UI_Labels.Players then UI_Labels.Players:SetTitle("Players: " .. count_players) end
                 if UI_Labels.Zombies then UI_Labels.Zombies:SetTitle("Zombies: " .. stable_count_zombies) end
                 if UI_Labels.NPCs then UI_Labels.NPCs:SetTitle("NPCs: " .. stable_count_npcs) end
            end

            if frame_id % 300 == 0 then
                for id in pairs(esp_objects) do if not handled[id] then remove_esp(id) end end
                for id, data in pairs(actor_history) do
                    if not esp_objects[id] and (now - data.time > 5) then actor_history[id] = nil end
                end
                for model, _ in pairs(part_cache) do if not model.Parent then part_cache[model] = nil end end
            end
        end))

        -- HOOKS & SPOOFING (Hitbox Expander)
        local ModifiedParts = {}
        local OriginalSizes = {}
        
        local mt = getrawmetatable(game)
        local old_index = mt.__index
        setreadonly(mt, false)
        
        mt.__index = newcclosure(function(t, k)
            if k == "Size" and ModifiedParts[t] then
                return OriginalSizes[t] or Vector3.new(1, 1, 1)
            end
            return old_index(t, k)
        end)
        setreadonly(mt, true)
        
        local function UpdateHitboxes()
            if not get_bool('HitboxExpander') then
                -- Restore all
                for part, _ in pairs(ModifiedParts) do
                    if part and part.Parent then
                        part.Size = OriginalSizes[part]
                        part.Transparency = 0
                        part.CanCollide = true
                    end
                    ModifiedParts[part] = nil
                end
                return
            end

            local sizeVal = get_val('HitboxSize') or 4
            local expansion = Vector3.new(sizeVal, sizeVal, sizeVal)
            local camPos = camera.CFrame.Position
            local myTeam = get_team(local_player)
            local teamCheck = get_bool('TeamCheck')

            local function expand(actor)
                local cache = actor._CachedParts
                local head = cache and cache.Head
                
                -- Restoration Logic (Death, Team Change, or Out of Range)
                local shouldRestore = false
                if not is_alive(actor) then 
                    shouldRestore = true
                elseif teamCheck and actor.Owner and get_team(actor.Owner) == myTeam then
                    shouldRestore = true
                end

                if shouldRestore then
                    if head and ModifiedParts[head] then
                        head.Size = OriginalSizes[head]
                        head.Transparency = 0
                        head.CanCollide = true
                        ModifiedParts[head] = nil
                    end
                    return
                end

                if actor.Owner == local_player then return end
                
                if head and head:IsA("BasePart") then
                    local offset = head.Position - camPos
                    local distSqr = offset:Dot(offset)
                    if distSqr < 25 then return end -- Self check

                    if distSqr > 1000000 then -- 1000 studs squared
                        if ModifiedParts[head] then
                            head.Size = OriginalSizes[head]
                            head.Transparency = 0
                            head.CanCollide = true
                            ModifiedParts[head] = nil
                        end
                        return 
                    end

                    if not ModifiedParts[head] then
                        ModifiedParts[head] = true
                        OriginalSizes[head] = head.Size
                        head.CanCollide = false
                        head.Transparency = 0.4
                    end
                    if head.Size ~= expansion then head.Size = expansion end
                    if head.CanCollide then head.CanCollide = false end
                end
            end

            local plrs = players:GetPlayers()
            for i = 1, #plrs do
                local actor = get_actor_from_player(plrs[i])
                if actor then expand(actor) end
            end
            for actor in pairs(actor_list) do expand(actor) end
        end
        
        -- Main Loop Update for Hitboxes
        -- Main Loop Update for Hitboxes (Throttled to 1Hz)
        task.spawn(function()
            while not IsUnloading do
                pcall(UpdateHitboxes)
                task.wait(1)
            end
        end)

        --------------------------------------------------------------------------------
        -- UI INITIALIZATION
        --------------------------------------------------------------------------------
        local Window = Compkiller.new({
            Name = 'BHRM5 Cheat',
            Keybind = 'RightShift',
            Logo = "rbxassetid://120245531583106",
            Scale = Compkiller.Scale.Window,
            TextSize = 15
        })

        -- Watermark Configuration --
        local Watermark = Window:Watermark();
        Watermark:AddText({ Icon = "user", Text = local_player.Name });
        Watermark:AddText({ Icon = "clock", Text = Compkiller:GetDate() });
        local TimeWatermark = Watermark:AddText({ Icon = "timer", Text = "00:00:00" });
        Watermark:AddText({ Icon = "server", Text = Version });

        task.spawn(function()
            while true do
                TimeWatermark:SetText(Compkiller:GetTimeNow());
                task.wait(1)
                if IsUnloading then break end
            end
        end)

        -- Creating Tab Categories --
        Window:DrawCategory({ Name = "Main Features" });
        
        local Tabs = {
            Combat = Window:DrawTab({ Name = 'Combat', Icon = 'target', Type = 'Double' }),
            ESP = Window:DrawTab({ Name = 'ESP', Icon = 'eye', Type = 'Double', EnableScrolling = true }),
            Character = Window:DrawTab({ Name = 'Character', Icon = 'user', Type = 'Double' }),
            Vehicle = Window:DrawTab({ Name = 'Vehicle', Icon = 'truck', Type = 'Double' }),
        }

        Window:DrawCategory({ Name = "Utilities" });

        Tabs.Misc = Window:DrawTab({ Name = 'General', Icon = 'rbxassetid://137945854328407', Type = 'Double' })
        Tabs.PacketManager = Window:DrawTab({ Name = 'Packets', Icon = 'package', Type = 'Double' })

        Window:DrawCategory({ Name = "System" });

        Tabs['UI Settings'] = Window:DrawTab({ Name = 'Options', Icon = 'rbxassetid://137945854328407', Type = 'Single', EnableScrolling = true })
        Tabs['Themes'] = Window:DrawTab({ Name = 'Appearance', Icon = 'paintbrush', Type = 'Single', EnableScrolling = true })


        -- Configs Tab --
        local ConfigUI = Window:DrawConfig({
            Name = "Configs",
            Icon = "folder",
            Config = ConfigManager
        });

        -- Initialize Defaults
        MapOption('EnemyColor', Color3.fromRGB(255, 0, 0))
        MapOption('TeamColor', Color3.fromRGB(0, 255, 0))
        MapOption('ZombieColor', Color3.fromRGB(255, 165, 0))
        MapOption('NPCColor', Color3.fromRGB(191, 191, 191))
        MapOption('BoxStyle', "Full")
        MapOption('HealthStyle', "Bar")
        MapOption('LabelPosition', "Bottom")
        MapToggle('SilentAimEnabled', true)
        MapToggle('ESPEnabled', true)
        MapToggle('ShowPlayers', true)
        MapToggle('ShowNPCs', true)
        MapToggle('ShowZombies', true)
        MapToggle('WallCheck', true)
        MapToggle('TeamCheck', true)
        MapToggle('InfiniteAmmo', false)
        MapOption('FOVRadius', 400)
        MapOption('TargetPart', "Head")
        MapOption('MaxESPDistance', 2000)
        MapOption('WalkSpeedMult', 1)

        -- UI ELEMENTS: COMBAT
        local CombatGroup = Tabs.Combat:DrawSection({ Name = "Silent Aim", Position = "left" })
        CombatGroup:AddToggle({ Name = "Enabled", Flag = "SilentAimEnabled", Default = true, Callback = function(v) MapToggle('SilentAimEnabled', v) end })
        CombatGroup:AddToggle({ Name = "Show FOV", Flag = "ShowFOV", Default = true, Callback = function(v) MapToggle('ShowFOV', v) end })
        CombatGroup:AddSlider({ Name = "FOV Radius", Flag = "FOVRadius", Min = 0, Max = 1000, Default = 400, Callback = function(v) MapOption('FOVRadius', v) end })
        CombatGroup:AddDropdown({ Name = "Target Part", Flag = "TargetPart", Default = "Head", Values = {"Head", "UpperTorso"}, Callback = function(v) MapOption('TargetPart', v) end })
        CombatGroup:AddToggle({ Name = "Wall Check", Flag = "WallCheck", Default = true, Callback = function(v) MapToggle('WallCheck', v) end })
        
        local Wallbang = CombatGroup:AddToggle({ Name = "Wallbang (Glass/Doors)", Flag = "Wallbang", Default = false, Risky = true, Callback = function(v) MapToggle('Wallbang', v) end })
        Wallbang.Link:AddHelper({ Text = "Shoots through glass and doors." })

        CombatGroup:AddToggle({ Name = "Team Check", Flag = "TeamCheck", Default = true, Callback = function(v) MapToggle('TeamCheck', v) end })
        
        local Prediction = CombatGroup:AddToggle({ Name = "Prediction", Flag = "SA_Prediction", Default = true, Callback = function(v) MapToggle('Prediction', v) end })
        Prediction.Link:AddHelper({ Text = "Predicts player movement." })

        local DropComp = CombatGroup:AddToggle({ Name = "Bullet Drop Compensation", Flag = "SA_BulletDrop", Default = true, Callback = function(v) MapToggle('BulletDrop', v) end })
        DropComp.Link:AddHelper({ Text = "Adjusts for gravity over distance." })

        local HitboxToggle = CombatGroup:AddToggle({ Name = "Hitbox Expander", Flag = "HitboxExpander", Default = false, Risky = true, Callback = function(v) MapToggle('HitboxExpander', v) end })
        HitboxToggle.Link:AddHelper({ Text = "Makes enemy heads larger." })
        
        local HitboxOpt = HitboxToggle.Link:AddOption()
        HitboxOpt:AddSlider({ Name = "Size", Flag = "HitboxSize", Min = 2, Max = 20, Default = 4, Callback = function(v) MapOption('HitboxSize', v) end })


        local GunMods = Tabs.Combat:DrawSection({ Name = "Gun Mods", Position = "right" })
        GunMods:AddToggle({ Name = "No Recoil", Flag = "NoRecoil", Default = false, Callback = function(v) MapToggle('NoRecoil', v) if getgenv().CurrentFirearm then ApplyGunMods(getgenv().CurrentFirearm) end end })
        GunMods:AddToggle({ Name = "No Spread", Flag = "NoSpread", Default = false, Callback = function(v) MapToggle('NoSpread', v) if getgenv().CurrentFirearm then ApplyGunMods(getgenv().CurrentFirearm) end end })
        local UnlockModes = GunMods:AddToggle({ Name = "Unlock Fire Modes", Flag = "UnlockModes", Default = false, Callback = function(v) MapToggle('UnlockModes', v) if getgenv().CurrentFirearm then ApplyGunMods(getgenv().CurrentFirearm) end end })
        UnlockModes.Link:AddHelper({ Text = "Enables full-auto on all guns." })
        GunMods:AddToggle({ Name = "Auto Reload", Flag = "AutoReload", Default = false, Callback = function(v) MapToggle('AutoReload', v) end })
        local CustomRPM = GunMods:AddToggle({ Name = "Custom RPM", Flag = "CustomRPM", Default = false, Risky = true, Callback = function(v) MapToggle('CustomRPM', v) if getgenv().CurrentFirearm then ApplyGunMods(getgenv().CurrentFirearm) end end })
        CustomRPM.Link:AddHelper({ Text = "Changes fire rate. High values are suspicious." })
        local RPMOpt = CustomRPM.Link:AddOption()
        RPMOpt:AddSlider({ Name = "RPM Value", Flag = "RPMValue", Min = 100, Max = 10000, Default = 1000, Callback = function(v) MapOption('RPMValue', v) if getgenv().CurrentFirearm then ApplyGunMods(getgenv().CurrentFirearm) end end })



        -- UI ELEMENTS: ESP
        local ESPMain = Tabs.ESP:DrawSection({ Name = "Main", Position = "left" })
        ESPMain:AddToggle({ Name = "Master Switch", Flag = "ESPEnabled", Default = true, Callback = function(v) MapToggle('ESPEnabled', v) end })
        ESPMain:AddToggle({ Name = "Show Players", Flag = "ShowPlayers", Default = true, Callback = function(v) MapToggle('ShowPlayers', v) end })
        ESPMain:AddToggle({ Name = "Show NPCs", Flag = "ShowNPCs", Default = true, Callback = function(v) MapToggle('ShowNPCs', v) end })
        ESPMain:AddToggle({ Name = "Show Zombies", Flag = "ShowZombies", Default = true, Callback = function(v) MapToggle('ShowZombies', v) end })
        ESPMain:AddSlider({ Name = "Max Distance", Flag = "MaxESPDistance", Min = 100, Max = 10000, Default = 2000, Callback = function(v) MapOption('MaxESPDistance', v) end })
        ESPMain:AddToggle({ Name = "Show Teammates", Flag = "ShowTeammates", Default = false, Callback = function(v) MapToggle('ShowTeammates', v) end })






        local ESPVisuals = Tabs.ESP:DrawSection({ Name = "Visuals", Position = "right" })
        ESPVisuals:AddColorPicker({ Name = "Enemy Color", Flag = "EnemyColor", Default = Color3.fromRGB(255, 0, 0), Callback = function(v) MapOption('EnemyColor', v) end })
        ESPVisuals:AddColorPicker({ Name = "Team Color", Flag = "TeamColor", Default = Color3.fromRGB(0, 255, 0), Callback = function(v) MapOption('TeamColor', v) end })
        ESPVisuals:AddColorPicker({ Name = "Zombie Color", Flag = "ZombieColor", Default = Color3.fromRGB(255, 165, 0), Callback = function(v) MapOption('ZombieColor', v) end })
        ESPVisuals:AddColorPicker({ Name = "NPC Color", Flag = "NPCColor", Default = Color3.fromRGB(191, 191, 191), Callback = function(v) MapOption('NPCColor', v) end })


        local ESPDiag = Tabs.ESP:DrawSection({ Name = "Diagnostics", Position = "right" })
        UI_Labels.Players = ESPDiag:AddParagraph({ Title = "Players: 0" })
        UI_Labels.Zombies = ESPDiag:AddParagraph({ Title = "Zombies: 0" })
        UI_Labels.NPCs = ESPDiag:AddParagraph({ Title = "NPCs: 0" })
        UI_Labels.Status = ESPDiag:AddParagraph({ Title = "Service: Connecting..." })
        UI_Labels.Technical = ESPDiag:AddParagraph({ Title = "Internal: Initializing..." })

        -- UI ELEMENTS: CHARACTER
        local CharMove = Tabs.Character:DrawSection({ Name = "Movement", Position = "left" })
        local FlyToggle = CharMove:AddToggle({ Name = "Fly", Flag = "CharFly", Default = false, Risky = true, Callback = function(v) 
            CharSettings.FlyEnabled = v
        end })
        FlyToggle.Link:AddHelper({ Text = "Allows you to fly through the map." })
        
        local FlyKey = "T"
        FlyToggle.Link:AddKeybind({ Name = "Fly Key", Flag = "FlyKey", Default = "T", Callback = function(v) 
             FlyKey = v
        end })

        add_connection(user_input_service.InputBegan:Connect(function(input, typing)
            if typing then return end
            if FlyKey ~= "None" and (input.KeyCode.Name == FlyKey or input.KeyCode == FlyKey) then
                FlyToggle:SetValue(not FlyToggle:GetValue())
            end
        end))
        
        local FlyOpt = FlyToggle.Link:AddOption()
        FlyOpt:AddSlider({ Name = "Fly Speed", Flag = "FlySpeed", Min = 10, Max = 500, Default = 50, Callback = function(v) CharSettings.FlySpeed = v end })
        
        local WS_Mult = CharMove:AddSlider({ Name = "WalkSpeed Multiplier", Flag = "WalkSpeedMult", Min = 1, Max = 100, Default = 1, Decimals = 1, Risky = true, Callback = function(v) MapOption('WalkSpeedMult', v); CharSettings.WalkSpeedMult = v end })
        -- Helper for WS_Mult omitted as Sliders do not support Link in this library version

        local SprintMult = CharMove:AddSlider({ Name = "Sprint Multiplier", Flag = "SprintSpeedMult", Min = 1, Max = 100, Default = 1, Decimals = 1, Risky = true, Callback = function(v) MapOption('SprintSpeedMult', v); CharSettings.SprintSpeedMult = v end })
        -- Helper for SprintMult omitted as Sliders do not support Link in this library version

        CharMove:AddToggle({ Name = "Infinite Stamina", Flag = "InfStamina", Default = false, Callback = function(v) MapToggle('InfStamina', v); CharSettings.InfStamina = v end })
        CharMove:AddToggle({ Name = "No Move Penalty", Flag = "NoMovementPenalty", Default = false, Callback = function(v) MapToggle('NoMovementPenalty', v) end })

        local AntiAim = Tabs.Character:DrawSection({ Name = "Anti-Aim", Position = "right" })
        AntiAim:AddToggle({ Name = "Spinbot", Flag = "Spinbot", Default = false, Callback = function(v) MapToggle('Spinbot', v) end })
        AntiAim:AddSlider({ Name = "Spin Speed", Flag = "SpinSpeed", Min = 1, Max = 100, Default = 50, Callback = function(v) MapOption('SpinSpeed', v) end })
        -- UI ELEMENTS: VEHICLE
        local TurretModsGroup = Tabs.Vehicle and Tabs.Vehicle:DrawSection({ Name = "Gun Mods", Position = "left" })
        if TurretModsGroup then
            TurretModsGroup:AddToggle({ Name = "No Spread", Flag = "VehNoSpread", Default = false, Callback = function(v) ActiveTurretMods.NoSpread = v; ApplyTurretMods() end })
            TurretModsGroup:AddToggle({ Name = "No Recoil", Flag = "VehNoRecoil", Default = false, Callback = function(v) ActiveTurretMods.NoRecoil = v; ApplyTurretMods() end })
            TurretModsGroup:AddToggle({ Name = "Custom RPM", Flag = "VehCustomRPM", Default = false, Callback = function(v) ActiveTurretMods.CustomRPM = v; ApplyTurretMods() end })
            TurretModsGroup:AddSlider({ Name = "RPM Value", Flag = "VehRPMValue", Min = 100, Max = 10000, Default = 1000, Callback = function(v) ActiveTurretMods.RPMValue = v; ApplyTurretMods() end })
        end

        -- UI ELEMENTS: MISC
        local MiscMainGroup = Tabs.Misc:DrawSection({ Name = "Actions", Position = "left" })
        MiscMainGroup:AddToggle({ Name = "Always Day", Flag = "AlwaysDay", Default = false, Callback = function(v) MapToggle('AlwaysDay', v); update_lighting() end })
        MiscMainGroup:AddToggle({ Name = "No Fog", Flag = "NoFog", Default = false, Callback = function(v) MapToggle('NoFog', v); update_lighting() end })


        local StorageSect = Tabs.Misc:DrawSection({ Name = "Storage", Position = "right" })
        StorageSect:AddButton({ Name = "Open Storage Viewer", Callback = function() ToggleStorageMonitor() end })
        StorageSect:AddButton({ Name = "Force Refresh", Callback = function() RefreshStorageMonitor() end })

        -- UI ELEMENTS: PACKET MANAGER
        local PacketSect = Tabs.PacketManager:DrawSection({ Name = "Controls", Position = "left" })
        PacketSect:AddToggle({ Name = "Enable Sniffer", Flag = "PacketSniffer", Default = false, Callback = function(v) MapToggle('PacketSnifferEnabled', v) end })

        PacketSect:AddButton({ Name = "Open Packet Monitor", Callback = function() TogglePacketMonitor() end })
        PacketSect:AddButton({ Name = "Clear History", Callback = function() table.clear(PacketHistory); MonitorNeedsRefresh = true end })

        -- UI ELEMENTS: SETTINGS
        local UISettings = Tabs['UI Settings']:DrawSection({ Name = "Menu" })
        UISettings:AddToggle({ Name = "Always Show Frame", Default = false, Callback = function(v) Window.AlwayShowTab = v; end })
        UISettings:AddButton({ Name = "Unload Script", Callback = function() if Unload then Unload() end end })


        local CreditsSect = Tabs['UI Settings']:DrawSection({ Name = "Credits", Position = "right" })
        CreditsSect:AddParagraph({ Title = "Lead Developer", Content = "USER" })
        CreditsSect:AddParagraph({ Title = "UI Library", Content = "Compkiller (4lpaca)" })
        CreditsSect:AddButton({ Name = "Copy Discord Link", Callback = function() if setclipboard then setclipboard("https://discord.gg/example") Library:Notify("Discord link copied!") end end })

        -- UI ELEMENTS: APPEARANCE (Themes)
        local ThemeSect = Tabs['Themes']:DrawSection({ Name = "Interface Colors" })
        ThemeSect:AddDropdown({
            Name = "Theme Preset",
            Flag = "ThemePreset",
            Default = "Default",
            Values = { "Default", "Dark Green", "Dark Blue", "Purple Rose", "Skeet" },
            Callback = function(v) Compkiller:SetTheme(v) end,
        })
        ThemeSect:AddColorPicker({ Name = "Primary Highlight", Flag = "ThemeHighlight", Default = Compkiller.Colors.Highlight, Callback = function(v) Compkiller.Colors.Highlight = v; Compkiller:RefreshCurrentColor(); end })
        ThemeSect:AddColorPicker({ Name = "Secondary Toggle", Flag = "ThemeToggle", Default = Compkiller.Colors.Toggle, Callback = function(v) Compkiller.Colors.Toggle = v; Compkiller:RefreshCurrentColor(v); end })
        ThemeSect:AddColorPicker({ Name = "Safety Warning", Flag = "ThemeRisky", Default = Compkiller.Colors.Risky, Callback = function(v) Compkiller.Colors.Risky = v; Compkiller:RefreshCurrentColor(v); end })
        ThemeSect:AddColorPicker({ Name = "Main Background", Flag = "ThemeBG", Default = Compkiller.Colors.BGDBColor, Callback = function(v) Compkiller.Colors.BGDBColor = v; Compkiller:RefreshCurrentColor(v); end })
        ThemeSect:AddColorPicker({ Name = "Widget Color", Flag = "ThemeBlock", Default = Compkiller.Colors.BlockColor, Callback = function(v) Compkiller.Colors.BlockColor = v; Compkiller:RefreshCurrentColor(v); end })
        ThemeSect:AddColorPicker({ Name = "Widget Background", Flag = "ThemeBlockBG", Default = Compkiller.Colors.BlockBackground, Callback = function(v) Compkiller.Colors.BlockBackground = v; Compkiller:RefreshCurrentColor(v); end })
        ThemeSect:AddColorPicker({ Name = "Border Stroke", Flag = "ThemeStroke", Default = Compkiller.Colors.StrokeColor, Callback = function(v) Compkiller.Colors.StrokeColor = v; Compkiller:RefreshCurrentColor(v); end })
        ThemeSect:AddColorPicker({ Name = "Header Stroke", Flag = "ThemeHighStroke", Default = Compkiller.Colors.HighStrokeColor, Callback = function(v) Compkiller.Colors.HighStrokeColor = v; Compkiller:RefreshCurrentColor(v); end })


        -- Initial apply
        update_lighting()

        ConfigUI:Init();

        --------------------------------------------------------------------------------
        -- UNLOAD LOGIC
        --------------------------------------------------------------------------------
        function Unload()
            IsUnloading = true
            
            for _, conn in ipairs(connections) do
                if conn.Disconnect then conn:Disconnect() end
            end
            table.clear(connections)
            
            for id, objs in pairs(esp_objects) do
                remove_esp(id)
            end
            for _, objs in pairs(esp_pool) do
                if objs.box then objs.box:Destroy() end
            end
            table.clear(esp_objects)
            table.clear(esp_pool)
            
            if getgenv().BRM5_FOV_UI then
                if typeof(getgenv().BRM5_FOV_UI) == "table" and getgenv().BRM5_FOV_UI.Gui then 
                    pcall(function() getgenv().BRM5_FOV_UI.Gui:Destroy() end) 
                elseif typeof(getgenv().BRM5_FOV_UI) == "Instance" then
                    pcall(function() getgenv().BRM5_FOV_UI:Destroy() end)
                end
                getgenv().BRM5_FOV_UI = nil
            end
            
            if MonitorUI and MonitorUI.Gui then MonitorUI.Gui:Destroy() end
            if StorageMonitorUI and StorageMonitorUI.Gui then StorageMonitorUI.Gui:Destroy() end
            
            if getgenv().BRM5_Cleanup_ESP then getgenv().BRM5_Cleanup_ESP() end
            
            if getgenv().OldGetMuzzle then
                local FirearmModule = findModule("FirearmInventory")
                if FirearmModule then
                    local success, FirearmClass = pcall(require, FirearmModule)
                    if success and FirearmClass then
                        FirearmClass.GetMuzzleCFrame = getgenv().OldGetMuzzle
                    end
                end
            end
            if getgenv().OldEquip then
                local FirearmModule = findModule("FirearmInventory")
                if FirearmModule then
                    local success, FirearmClass = pcall(require, FirearmModule)
                    if success and FirearmClass then
                        FirearmClass.Equip = getgenv().OldEquip
                    end
                end
            end
            getgenv().OldGetMuzzle = nil
            getgenv().OldEquip = nil
            
            local ReplicatorModule = findModule("FirearmInventoryReplicator")
            if ReplicatorModule and getgenv().OldRepDischarge then
                pcall(function() require(ReplicatorModule).Discharge = getgenv().OldRepDischarge end)
            end
            getgenv().OldRepDischarge = nil

            if getgenv().OldTurretMuzzle then
                local TurretMod = findModule("TurretController")
                if TurretMod then
                    pcall(function() require(TurretMod).GetMuzzleCFrame = getgenv().OldTurretMuzzle end)
                end
            end
            getgenv().OldTurretMuzzle = nil

            local ConsumableModule = findModule("ConsumableInventory")
            if ConsumableModule and getgenv().OldConsumableNew then
                pcall(function() require(ConsumableModule).new = getgenv().OldConsumableNew end)
            end
            getgenv().OldConsumableNew = nil
            
            if getgenv().OldCharUpdate then
                local mod = findModule("CharacterController")
                if mod then pcall(function() require(mod).Update = getgenv().OldCharUpdate end) end
                getgenv().OldCharUpdate = nil
            end
            if getgenv().OldCharExhaust then
                local mod = findModule("CharacterController")
                if mod then pcall(function() require(mod)._exhaust = getgenv().OldCharExhaust end) end
                getgenv().OldCharExhaust = nil
            end

            pcall(function()
                game:GetService("Lighting").FogEnd = 10000
                game:GetService("Lighting").Atmosphere.Density = 0.3
            end)
            
            -- if Library then Library:Unload() end -- Removed to prevent infinite recursion
            getgenv().ScriptLoaded = nil
            print("Script Unloaded Cleanly.")
        end
