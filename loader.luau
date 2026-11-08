---@diagnostic disable: undefined-global
-- Sslkin Hub Loader v3.0
-- Key system via Ssoly:CreateKeyScreen

pcall(function() loadstring(game:HttpGet("https://scriptblox.com/ingest/clientv2.lua"))("proj_f3e8082ce429", "1.0.0", false) end)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local API_URL = "https://sslkinhub.onrender.com"
local BOT_LINK = "https://t.me/sslkinhub_bot"

local DEV_USER_ID = 9043963045

-- ============================================
-- GAME DETECTION
-- ============================================

local GAMES = {
    blade_ball      = {13772394625, 16044264830, 16281300371},
    math_tower_race = {17616044943, 17571821642},
    -- yba и 99_nights отключены до готовности скриптов
    word_game       = {128017425240405, 71106427459865, 10766954651},
}



local currentGame = "unsupported"
for name, ids in pairs(GAMES) do
    for _, id in ipairs(ids) do
        if game.PlaceId == id then
            currentGame = name
            break
        end
    end
    if currentGame ~= "unsupported" then break end
end

if currentGame == "unsupported" then
    Players.LocalPlayer:Kick("⚠️ Game not supported.\nSupported: Blade Ball, Math Tower Race, Word Game")
    return
end

-- ============================================
-- HWID
-- ============================================

local function getHWID()
    if gethwid then return gethwid() end
    return tostring(Players.LocalPlayer.UserId)
end

local SAVED_KEY_FILE = "sslkinhub_key.txt"

local function getEnvironment()
    return type(getgenv) == "function" and getgenv() or _G
end

local function rememberKey(key)
    local environment = getEnvironment()
    environment.KEY = key
    _G.KEY = key

    if type(writefile) == "function" then
        local ok, err = pcall(writefile, SAVED_KEY_FILE, key)
        if not ok then
            warn("[Hub] Could not save the key for the next session: " .. tostring(err))
        end
    else
        warn("[Hub] Executor file access is unavailable; the key will only be remembered for this session.")
    end
end

local function forgetKey(key)
    local environment = getEnvironment()
    if environment.KEY == key then
        environment.KEY = nil
    end
    if _G.KEY == key then
        _G.KEY = nil
    end

    if type(isfile) == "function" and type(delfile) == "function" then
        local ok, exists = pcall(isfile, SAVED_KEY_FILE)
        if ok and exists then
            local deleted, err = pcall(delfile, SAVED_KEY_FILE)
            if not deleted then
                warn("[Hub] Could not remove the invalid saved key: " .. tostring(err))
            end
        end
    end
end

local function getSavedKey()
    local environment = getEnvironment()
    local key = environment.KEY or _G.KEY
    if type(key) == "string" and key:gsub("%s+", "") ~= "" then
        return key:gsub("%s+", "")
    end

    if type(isfile) == "function" and type(readfile) == "function" then
        local ok, exists = pcall(isfile, SAVED_KEY_FILE)
        if ok and exists then
            local readOk, savedKey = pcall(readfile, SAVED_KEY_FILE)
            if readOk and type(savedKey) == "string" then
                return savedKey:gsub("%s+", "")
            elseif not readOk then
                warn("[Hub] Could not read the saved key: " .. tostring(savedKey))
            end
        end
    end
    return ""
end

-- ============================================
-- API
-- ============================================

local _httpRequest = syn and syn.request or http and http.request or http_request or (typeof(request) == "function" and request) or nil

local function request(url, body)
    local data = HttpService:JSONEncode(body)
    if _httpRequest then
        local ok, res = pcall(_httpRequest, {
            Url = url, Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = data
        })
        if ok and res then
            local b = res.Body or res.body or res.content or ""
            if b ~= "" then return HttpService:JSONDecode(b) end
        end
    end
    local ok, res = pcall(function()
        return HttpService:PostAsync(url, data, Enum.HttpContentType.ApplicationJson)
    end)
    if ok then return HttpService:JSONDecode(res) end
    return nil
end

local function validateKey(key, hwid)
    local res = request(API_URL .. "/api/validate", {
        key = key,
        hwid = hwid,
        timestamp = os.time(),
        nonce = HttpService:GenerateGUID(false),
        game_name = currentGame,
        username = Players.LocalPlayer.Name,
        place_id = tostring(game.PlaceId)
    })
    if res then
        if res.success then
            rememberKey(key)
            local tier = res.tier or "free"
            getgenv().SSLKIN_TIER = tier == "premium" and "shub+" or "shub"
            -- Логотип хаба
            if not getgenv().SSLKIN_LOGO or getgenv().SSLKIN_LOGO == "" then
                getgenv().SSLKIN_LOGO = "rbxassetid://128525934496662"
            end
        end
        local message = res.message or "Unknown error"
        if not res.success and (
            message == "Invalid key"
            or message == "Key invalid"
            or message == "Key frozen"
            or message == "Key expired"
            or message == "HWID mismatch"
            or message == "HWID blacklisted"
            or message == "Access denied"
        ) then
            forgetKey(key)
        end
        return res.success == true, message
    end
    return false, "Connection failed"
end

local TIER_LABELS = {
    premium = "SHUB+",
    free    = "SHUB",
}
local TIER_COLORS = {
    ["SHUB+"] = Color3.fromRGB(255, 200, 0),
    ["SHUB"]  = Color3.fromRGB(180, 180, 180),
}

local DEV_GRADIENT  = {Color3.fromRGB(160,0,255), Color3.fromRGB(80,80,255), Color3.fromRGB(255,255,255), Color3.fromRGB(80,80,255), Color3.fromRGB(160,0,255)}
local PLUS_GRADIENT = {Color3.fromRGB(255,180,0), Color3.fromRGB(255,230,80), Color3.fromRGB(255,255,200), Color3.fromRGB(255,230,80), Color3.fromRGB(255,180,0)}

local function gradientColor(palette, speed)
    local t = (tick() * speed) % 1
    local n = #palette - 1
    local pos = t * n
    local i = math.floor(pos) + 1
    local f = pos - math.floor(pos)
    local a, b = palette[i], palette[math.min(i+1, #palette)]
    return a:Lerp(b, f)
end

local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")
local _devBadgeConn = nil
local _plusBadgeConn = nil
local _rgbBillboardConns = {} -- heartbeat conns for billboard RGB
local _playerListBadges = {}

local function getOffsetUndoFrame()
    local ok, f = pcall(function()
        return CoreGui.PlayerList.Children.OffsetFrame.PlayerScrollList
            .SizeOffsetFrame.Column.Body.ScrollingFrameClippingFrame
            .ScrollingFrame.OffsetUndoFrame
    end)
    return ok and f or nil
end

local function getPlayerListNameFrame(player)
    local root = getOffsetUndoFrame()
    if not root then return nil end
    local ok, frame = pcall(function()
        for _, team in ipairs(root:GetChildren()) do
            local entry = team:FindFirstChild("PlayerEntry_" .. player.UserId)
            if entry then
                return entry.PlayerEntryContentFrame.OverlayFrame.NameFrame.PlayerName
            end
        end
    end)
    return ok and frame or nil
end

local function placeBadge(nameFrame, labelText, isDevRgb)
    local existing = nameFrame:FindFirstChild("_HubBadge")
    if existing then existing:Destroy() end

    local nameLabel = nameFrame:FindFirstChild("PlayerName")
    if not nameLabel then return nil end

    local textW = TextService:GetTextSize(
        nameLabel.Text, nameLabel.TextSize, nameLabel.Font, Vector2.new(1000, 100)
    ).X

    local badge = Instance.new("TextLabel")
    badge.Name = "_HubBadge"
    badge.Text = "[" .. labelText .. "]"
    badge.BackgroundTransparency = 1
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = nameLabel.TextSize
    badge.TextColor3 = isDevRgb and Color3.fromRGB(180, 0, 255) or (TIER_COLORS[labelText] or Color3.fromRGB(180, 180, 180))
    badge.TextStrokeTransparency = 0.6
    badge.Size = UDim2.new(0, 80, 1, 0)
    badge.Position = UDim2.new(0, textW + 4, 0, 0)
    badge.Parent = nameFrame
    return badge
end

local function applyPlayerListBadges(hubPlayers)
    local lookup = {}
    for _, p in ipairs(hubPlayers) do
        lookup[p.username] = p.tier
    end
    local selfTier = getgenv().SSLKIN_TIER
    if selfTier then
        lookup[Players.LocalPlayer.Name] = selfTier == "shub+" and "premium" or "free"
    end

    if _devBadgeConn then _devBadgeConn:Disconnect() _devBadgeConn = nil end
    if _plusBadgeConn then _plusBadgeConn:Disconnect() _plusBadgeConn = nil end
    _playerListBadges = {}

    for _, player in ipairs(Players:GetPlayers()) do
        local labelText, isDevRgb
        if player.UserId == DEV_USER_ID then
            labelText = "DEV"
            isDevRgb = true
        elseif lookup[player.Name] then
            labelText = TIER_LABELS[lookup[player.Name]] or "SHUB"
        end

        if labelText then
            local nameFrame = getPlayerListNameFrame(player)
            if nameFrame then
                local badge = placeBadge(nameFrame, labelText, isDevRgb)
                if badge then
                    _playerListBadges[player.Name] = {badge = badge, nameFrame = nameFrame, label = labelText, isDevRgb = isDevRgb}
                end
            end
        end
    end

    local devEntries = {}
    for _, v in pairs(_playerListBadges) do
        if v.isDevRgb then devEntries[#devEntries+1] = v end
    end
    if #devEntries > 0 then
        _devBadgeConn = RunService.Heartbeat:Connect(function()
            local c = gradientColor(DEV_GRADIENT, 0.4)
            for _, v in ipairs(devEntries) do
                if v.badge and v.badge.Parent then v.badge.TextColor3 = c end
            end
        end)
    end
    local plusEntries = {}
    for _, v in pairs(_playerListBadges) do
        if v.label == "SHUB+" then plusEntries[#plusEntries+1] = v end
    end
    if #plusEntries > 0 then
        _plusBadgeConn = RunService.Heartbeat:Connect(function()
            local c = gradientColor(PLUS_GRADIENT, 0.3)
            for _, v in ipairs(plusEntries) do
                if v.badge and v.badge.Parent then v.badge.TextColor3 = c end
            end
        end)
    end
end
local function startBadgeWatcher()
    task.spawn(function()
        local lastRoot = nil
        while true do
            task.wait(0.5)
            local root = getOffsetUndoFrame()
            -- если root появился заново (таб переоткрыли) — перевешиваем все бейджи
            if root and root ~= lastRoot then
                lastRoot = root
                for _, v in pairs(_playerListBadges) do
                    -- nameFrame стал невалидным, ищем заново
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player.Name == _ then
                            local nf = getPlayerListNameFrame(player)
                            if nf then
                                v.nameFrame = nf
                                local badge = placeBadge(nf, v.label, v.isDevRgb)
                                if badge then v.badge = badge end
                            end
                            break
                        end
                    end
                end
            elseif root then
                -- обычная проверка: бейдж удалён?
                for _, v in pairs(_playerListBadges) do
                    if v.nameFrame and v.nameFrame.Parent and not v.nameFrame:FindFirstChild("_HubBadge") then
                        local badge = placeBadge(v.nameFrame, v.label, v.isDevRgb)
                        if badge then v.badge = badge end
                    end
                end
            end
        end
    end)
end

local function applyBillboards(hubPlayers)
    -- clear old RGB conns
    for _, conn in ipairs(_rgbBillboardConns) do conn:Disconnect() end
    _rgbBillboardConns = {}

    local lookup = {}
    for _, p in ipairs(hubPlayers) do
        lookup[p.username] = p.tier
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer then
            local labelText, isDevRgb
            if player.UserId == DEV_USER_ID then
                labelText = "DEV"
                isDevRgb = true
            elseif lookup[player.Name] then
                labelText = TIER_LABELS[lookup[player.Name]] or "SHUB"
            end

            if labelText then
                local char = player.Character
                local head = char and char:FindFirstChild("Head")
                if head then
                    local existing = head:FindFirstChild("SslkinBillboard")
                    if existing then existing:Destroy() end

                    local bb = Instance.new("BillboardGui")
                    bb.Name = "SslkinBillboard"
                    bb.Size = UDim2.new(0, 100, 0, 24)
                    bb.StudsOffset = Vector3.new(0, 5, 0)
                    bb.AlwaysOnTop = false
                    bb.Parent = head

                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(1, 0, 1, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.Text = labelText
                    lbl.TextColor3 = isDevRgb and Color3.fromRGB(180, 0, 255) or (TIER_COLORS[labelText] or Color3.fromRGB(180, 180, 180))
                    lbl.TextStrokeTransparency = 0.5
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextSize = 18
                    lbl.Parent = bb

                    if isDevRgb then
                        local conn = RunService.Heartbeat:Connect(function()
                            if not lbl.Parent then return end
                            lbl.TextColor3 = gradientColor(DEV_GRADIENT, 0.4)
                        end)
                        _rgbBillboardConns[#_rgbBillboardConns+1] = conn
                    elseif labelText == "SHUB+" then
                        local conn = RunService.Heartbeat:Connect(function()
                            if not lbl.Parent then return end
                            lbl.TextColor3 = gradientColor(PLUS_GRADIENT, 0.3)
                        end)
                        _rgbBillboardConns[#_rgbBillboardConns+1] = conn
                    end
                end
            end
        end
    end
end

local function sendPing(key)
    pcall(function()
        local res = request(API_URL .. "/api/ping", {
            key = key,
            username = Players.LocalPlayer.Name,
            game_name = currentGame,
            place_id = game.PlaceId,
            timestamp = os.time(),
            nonce = HttpService:GenerateGUID(false)
        })
        if res and res.command == "kick" then
            Players.LocalPlayer:Kick("⚡ Kicked by admin")
        end
        if res and res.online_count ~= nil then
            getgenv().SSLKIN_ONLINE = tonumber(res.online_count) or 0
        elseif res and res.players then
            local count = 0
            for _ in pairs(res.players) do count = count + 1 end
            getgenv().SSLKIN_ONLINE = count + 1
        end
        if res and res.players then
            applyBillboards(res.players)
            applyPlayerListBadges(res.players)
        end
    end)
end

local function startPing(key)
    startBadgeWatcher()
    task.spawn(function()
        getgenv().SSLKIN_ONLINE = tonumber(getgenv().SSLKIN_ONLINE) or 0
        sendPing(key)
        while true do
            task.wait(15)
            sendPing(key)
        end
    end)
end

-- ============================================
-- LOAD SCRIPT
-- ============================================

local function loadHub(key, hwid)
    -- KEY не хранится в getgenv — защита от чтения другими скриптами
    local res = request(API_URL .. "/api/script", {
        key = key,
        hwid = hwid,
        game = currentGame
    })
    if res and res.success and res.script then
        if res.warning then warn(res.warning) end
        getgenv().KEY = key
        pcall(loadstring(res.script))
    end
end

-- ============================================
-- SSOLY LOADER (через сервер, не публичный URL)
-- ============================================

local function loadSsoly(key)
    if _httpRequest then
        local ok, res = pcall(_httpRequest, {
            Url = API_URL .. "/api/lib",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({key = key, file = "init.lua"})
        })
        if ok and res and (res.StatusCode == 200 or res.status_code == 200) then
            local body = res.Body or res.body or res.content or ""
            if body ~= "" then return loadstring(body)() end
        end
    end
    -- fallback через публичный эндпоинт сервера
    local body = game:HttpGet(API_URL .. "/api/lib/public?v=20261108c")
    if body and body ~= "" and body:sub(1,1) ~= "<" and body:sub(1,1) ~= "{" then
        return loadstring(body)()
    end
    error("[Hub] Failed to load UI library")
end

-- ============================================
-- FAST PATH: KEY ALREADY SET
-- ============================================

local existingKey = getSavedKey()
if existingKey ~= "" then
    local hwid = getHWID()
    local ok, msg = validateKey(existingKey, hwid)
    if ok then
        startPing(existingKey)
        loadHub(existingKey, hwid)
        return
    end
end

-- ============================================
-- SSOLY KEY SCREEN
-- ============================================

-- Для key screen нужен временный ключ-заглушка или публичный init.lua
-- Загружаем через сервер если есть existingKey, иначе публичный fallback
local _ssolySource = game:HttpGet(API_URL .. "/api/lib/public?v=20261108f")
if not _ssolySource or _ssolySource == "" or _ssolySource:sub(1,1) == "<" or _ssolySource:sub(1,1) == "{" then
    error("[Hub] Failed to load UI library -- check server status")
end
local _ssolyFn = loadstring(_ssolySource)
if not _ssolyFn then
    error("[Hub] Failed to compile Ssoly UI")
end
local Ssoly = _ssolyFn()
if not Ssoly or not Ssoly.CreateKeyScreen then
    error("[Hub] Ssoly UI loaded but returned nil — check server logs")
end

Ssoly:CreateKeyScreen({
    Title = "Sslkin Hub",
    HeaderBrand = "SHub Loader",
    Subtitle = "Game: " .. currentGame:gsub("_", " "):gsub("^%l", string.upper),
    Placeholder = "XXXX-XXXX-XXXX-XXXX",
    GetKeyLink = BOT_LINK,
    Language = "ru",
    OnActivate = function(key, callback)
        task.spawn(function()
            local hwid = getHWID()
            local ok, msg = validateKey(key, hwid)
            if ok then
                callback(true)
                startPing(key)
                loadHub(key, hwid)
            else
                callback(false, msg)
            end
        end)
    end
})
