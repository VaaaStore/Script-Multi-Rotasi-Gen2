local WM = "VaaaStore V5.2"
local C = {
    worlds_farm   = {"Farm1", "Farm2", "Farm3"}, -- world farm
    world_storage = "world_storage", -- world storage
    door_id       = "",  -- id door harus sama semua
    block_id = 4584, -- id block
    seed_id  = 4585, -- id seed
    wl_id    = 242,  -- id world lock
    gem_threshold   = 2000,   -- gems count untuk auto buy WL
    max_plant_seeds = 2645,   -- batas seed plant
    min_seed_keep   = 200,    -- seed yang disimpan di tas
    max_carry       = 200,    -- maksimal seed yang dibawa ke storage
    stack_cap       = 200,    -- maksimal satu jenis item di tas
    storage_seed = {0, 0},    -- koordinat drop seed storage
    storage_wl   = {0, 1},    -- koordinat drop WL storage
    pnb_pos      = {97, 1},   -- posisi bot saat PNB
    pnb_offsets  = {-1, 0, 1},-- tile yang dipecah: baris di atas bot (x + offset, y - 1)
    pnb_max_idle = 20,        -- looping PNB 
    max_hits     = 12,        -- maksimal hit per tile saat PNB
    delay_min   = 150,        -- delay acak minimum (ms)
    delay_max   = 1000,       -- delay acak maksimum (ms)
    check_delay = 10000,      -- delay cek gems
    tile_cap    = 4000,       -- maksimal drop per tile (WL/seed)
    max_shift   = 20          -- maksimal tile yang dicoba saat drop (WL/seed)
}

local function log_hp(t) log("[" .. WM .. "] " .. tostring(t)) end
local lag = 0
local function pause(lo, hi) sleep(math.random(lo or C.delay_min, hi or C.delay_max) + lag) end
local function lag_bad() lag = math.min(lag + 300, 2000) end
local function lag_ok() lag = math.max(lag - 100, 0) end
local function wait_until(fn, ms)
    local t = getTime()
    while getTime() - t < ms do
        local ok, r = pcall(fn)
        if ok and r then return true end
        sleep(100)
    end
    return false
end

local function inv(id)
    for _, it in pairs(getInventory()) do
        if it.id == id then return it.amount end
    end
    return 0
end

local function tile(x, y)
    local ok, t = pcall(getTile, x, y)
    if ok then return t end
end

local function tile_pos()
    local me = getLocal()
    return me.posX // 32, me.posY // 32
end

local function world_name()
    local ok, w = pcall(getCurrentWorldName)
    return (ok and w) or ""
end

local function world_is(name) return world_name():upper() == name:upper() end

local function ready()
    local ok, me = pcall(getLocal)
    return ok and me ~= nil and me.posX ~= nil and world_name() ~= ""
end

local function walk_to(x, y)
    local px, py = tile_pos()
    if px == x and py == y then return true end
    FindPath(x, y)
    local t = getTime()
    while getTime() - t < 3000 do
        px, py = tile_pos()
        if px == x and py == y then return true end
        sleep(200)
    end
    return false
end

local function warp(name)
    if world_is(name) then return true end
    local target = (C.door_id ~= "") and (name .. "|" .. C.door_id) or name
    for i = 1, 3 do
        log_hp("Warp ke " .. name .. " (" .. i .. "/3)")
        growtopia.warpTo(target)
        if wait_until(function() return world_is(name) and ready() end, 12000) then
            sleep(math.random(1500, 2500)) -- tunggu data world selesai dimuat
            return true
        end
    end
    log_hp("Gagal warp ke " .. name)
    return false
end

local function act(x, y, item)
    local me = getLocal()
    sendPacketRaw(false, {type = 3, value = item, px = x, py = y, x = me.posX, y = me.posY})
end

local function obj_tile(o)
    return o.pos.x // 32, o.pos.y // 32
end

local function collect()
    local px, py = tile_pos()
    for _, o in pairs(getObjectList()) do
        local ox, oy = obj_tile(o)
        if math.abs(ox - px) <= 3 and math.abs(oy - py) <= 3 then
            sendPacketRaw(false, {type = 11, value = o.id, x = o.pos.x, y = o.pos.y})
        end
    end
end

local function floor_total(item)
    local n = 0
    for _, o in pairs(getObjectList()) do
        if o.itemid == item then n = n + o.amount end
    end
    return n
end

local function fetch_floor(item)
    for _, o in pairs(getObjectList()) do
        if o.itemid == item then
            if inv(item) >= C.stack_cap then return end
            local ox, oy = obj_tile(o)
            if walk_to(ox, oy) then
                collect()
                pause()
            end
        end
    end
end

local function count_at(item, x, y)
    local total = 0
    for _, o in pairs(getObjectList()) do
        if o.itemid == item then
            local ox, oy = obj_tile(o)
            if ox == x and oy == y then total = total + o.amount end
        end
    end
    return total
end

local function drop_at(item, amount, pos)
    local y = pos[2]
    for x = pos[1], pos[1] + C.max_shift do
        local space = C.tile_cap - count_at(item, x, y)
        if space > 0 and walk_to(x, y) then
            local n = math.min(amount, space)
            growtopia.confirmDropItem(item, n)
            pause(300, 700)
            amount = amount - n
            log_hp("Drop " .. n .. " (ID " .. item .. ") di " .. x .. "," .. y)
            if amount <= 0 then return true end
        end
    end
    log_hp("Sisa " .. amount .. " (ID " .. item .. ") tidak terdrop: tile penuh/tidak terjangkau")
    return false
end

local function zigzag(list)
    local rank, ys = {}, {}
    for _, p in ipairs(list) do
        if not rank[p.y] then
            rank[p.y] = true
            ys[#ys + 1] = p.y
        end
    end
    table.sort(ys, function(a, b) return a > b end)
    for i, y in ipairs(ys) do rank[y] = i end
    table.sort(list, function(a, b)
        if a.y ~= b.y then return a.y > b.y end
        if rank[a.y] % 2 == 1 then return a.x > b.x end
        return a.x < b.x
    end)
end

runThread(function()
    log_hp("Auto buy WL aktif")
    while true do
        pcall(function()
            if getGems() >= C.gem_threshold then
                sendPacket(2, "action|buy\nitem|world_lock")
                sleep(2000)
            end
        end)
        sleep(C.check_delay)
    end
end)

local function harvest_tile(t)
    if not walk_to(t.x, t.y) then return false end
    for _ = 1, 3 do
        act(t.x, t.y, 18)
        pause()
        local done = wait_until(function()
            local g = tile(t.x, t.y)
            return g and (g.fg ~= C.seed_id or not g.readyharvest)
        end, 1500)
        if done then
            lag_ok()
            collect()
            return true
        end
        lag_bad()
    end
    return false
end

local function harvest()
    log_hp("Harvest...")
    local total = 0
    for _ = 1, 10 do
        local list = {}
        for _, t in pairs(getTiles()) do
            if t.fg == C.seed_id and t.readyharvest then list[#list + 1] = {x = t.x, y = t.y} end
        end
        if #list == 0 then break end
        zigzag(list)
        local done = 0
        for _, t in ipairs(list) do
            if harvest_tile(t) then done = done + 1 end
        end
        total = total + done
        if done == 0 then break end
    end
    log_hp("Harvest selesai: " .. total)
end

local function pnb_tile(x, y)
    local t0 = tile(x, y)
    if not t0 or (t0.fg ~= 0 and t0.fg ~= C.block_id) then return end
    if t0.fg == 0 then
        if inv(C.block_id) <= 0 then return end
        act(x, y, C.block_id)
        pause()
        local placed = wait_until(function()
            local g = tile(x, y)
            return g and g.fg == C.block_id
        end, 1500)
        if not placed then
            lag_bad()
            return
        end
    end
    for _ = 1, C.max_hits do
        act(x, y, 18)
        pause()
        local g = tile(x, y)
        if g and g.fg ~= C.block_id then
            lag_ok()
            return
        end
    end
end

local function pnb()
    log_hp("PNB...")
    local px, py = C.pnb_pos[1], C.pnb_pos[2]
    local last, idle = nil, 0
    while true do
        local remain = inv(C.block_id) + floor_total(C.block_id)
        if remain == 0 then
            log_hp("PNB selesai, block bersih")
            return true
        end
        if last and remain >= last then idle = idle + 1 else idle = 0 end
        if idle >= C.pnb_max_idle then
            log_hp("PNB macet, sisa block: " .. remain)
            return false
        end
        last = remain
        if inv(C.block_id) <= 0 then fetch_floor(C.block_id) end
        if inv(C.block_id) > 0 and walk_to(px, py) then
            for _, dx in ipairs(C.pnb_offsets) do pnb_tile(px + dx, py - 1) end
            collect()
        end
        pause()
    end
end

local function plant_targets()
    local list, A = {}, C.plant_area
    for _, t in pairs(getTiles()) do
        local inside = (not A) or (t.x >= A.x1 and t.x <= A.x2 and t.y >= A.y1 and t.y <= A.y2)
        local is_pnb = (t.x == C.pnb_pos[1] and t.y == C.pnb_pos[2])
        if t.fg == 0 and inside and not is_pnb then
            local b = tile(t.x, t.y + 1)
            if b and b.fg ~= 0 and b.fg ~= C.seed_id then list[#list + 1] = {x = t.x, y = t.y} end
        end
    end
    zigzag(list)
    return list
end

local function plant_tile(x, y)
    for _ = 1, 2 do
        act(x, y, C.seed_id)
        pause()
        local ok = wait_until(function()
            local g = tile(x, y)
            return g and g.fg == C.seed_id
        end, 1500)
        if ok then
            lag_ok()
            return true
        end
        lag_bad()
    end
    return false
end

local function plant()
    log_hp("Plant...")
    local planted = 0
    for _, t in ipairs(plant_targets()) do
        if planted >= C.max_plant_seeds then break end
        if inv(C.seed_id) <= 0 then
            fetch_floor(C.seed_id)
            if inv(C.seed_id) <= 0 then break end
        end
        if walk_to(t.x, t.y) and plant_tile(t.x, t.y) then planted = planted + 1 end
    end
    log_hp("Plant selesai: " .. planted)
end

local function deposit()
    local extra = inv(C.seed_id) - C.min_seed_keep
    local wl = inv(C.wl_id)
    if extra <= 0 and wl <= 0 then return end
    if not warp(C.world_storage) then return end
    if extra > 0 then drop_at(C.seed_id, math.min(extra, C.max_carry), C.storage_seed) end
    if wl > 0 then drop_at(C.wl_id, wl, C.storage_wl) end
end

local function farm_world(w)
    if not warp(w) then return end
    harvest()
    if not pnb() then
        log_hp("World dilewati (PNB belum bersih): " .. w)
        return
    end
    plant()
end

local function guarded(fn, arg)
    local ok, err = pcall(fn, arg)
    if not ok then
        log_hp("Error: " .. tostring(err))
        sleep(3000)
    end
end

local function main()
    log_hp("Bot dimulai")
    while true do
        for i, w in ipairs(C.worlds_farm) do
            log_hp("[" .. i .. "/" .. #C.worlds_farm .. "] " .. w)
            if not ready() then wait_until(ready, 30000) end
            guarded(farm_world, w)
            pause(1000, 2000)
        end
        guarded(deposit)
    end
end

runThread(main)