-- WoWFA Forever - items: Persian name + lines under the item tooltip.
-- Stale guard: the export keeps the numbers of the English stat / effect
-- lines; when the live tooltip no longer has them (the game changed the
-- item) only the Persian name is shown, with a short note.

local F = WoWFAF
local L = F.L
local T = F.T
local C = F.C
local SEP = "\031"
local GREEN = { 0.12, 1.0, 0.0 }
local YELLOW = { 1.0, 0.82, 0.0 }

local M = { id = "items", order = 1, risk = "low", nameKey = "m_items", descKey = "m_items_d", watchMiss = true }

function M.data()
    return F.D.items
end

local function has_tdp()
    return TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
        and Enum.TooltipDataType.Item ~= nil
end

function M.api()
    if has_tdp() then
        return true
    end
    return GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipSetItem")
end

-- small parse cache
local cache, cached = {}, 0
local function get(id)
    local rec = cache[id]
    if rec then
        return rec
    end
    local raw = F.D.items[id]
    if type(raw) ~= "string" then
        return nil
    end
    local parts = F.Split(raw, SEP)
    rec = { name = parts[1] or "", hash = parts[2] or "", lines = {} }
    for i = 3, #parts do
        local p = parts[i]
        if #p > 2 then
            rec.lines[#rec.lines + 1] = { c = string.sub(p, 1, 1), lvl = string.sub(p, 2, 2), text = string.sub(p, 3) }
        end
    end
    if cached > 400 then
        wipe(cache)
        cached = 0
    end
    cache[id] = rec
    cached = cached + 1
    return rec
end

local function norm(n)
    local v = tonumber(n)
    return v and string.format("%.14g", v) or n
end

local function is_stale(tt, data, hash)
    if hash == "" then
        return false
    end
    local live = {}
    for _, t in ipairs(T.TipText(tt, data)) do
        local _, nums = T.NumKey(t)
        for _, n in ipairs(nums) do
            n = norm(n)
            live[n] = (live[n] or 0) + 1
        end
    end
    local want = F.Split(hash, ",")
    local missing = 0
    for _, n in ipairs(want) do
        n = norm(n)
        if (live[n] or 0) > 0 then
            live[n] = live[n] - 1
        else
            missing = missing + 1
        end
    end
    return missing * 4 > #want
end

local missed = {}

local function item_id(tt, data)
    if data and F.Usable(data.id) and type(data.id) == "number" then
        return data.id
    end
    if tt.GetItem then
        local _, link = tt:GetItem()
        if F.Usable(link) and type(link) == "string" then
            return tonumber(string.match(link, "item:(%d+)"))
        end
    end
end

local function handler(tt, data)
    if not tt or (tt.IsForbidden and tt:IsForbidden()) then
        return
    end
    local id = item_id(tt, data)
    if not id then
        return
    end
    local rec = get(id)
    if not rec then
        -- count every unknown item once: a refreshing tooltip must not inflate misses
        if not missed[id] then
            missed[id] = true
            F:Track("items", false)
        end
        return
    end
    if not T.Once(tt, "i" .. id) then
        return
    end
    local stale = is_stale(tt, data, rec.hash)
    F:Track("items", true, stale)
    if rec.name ~= "" then
        T.TipLine(tt, T.Prepare(rec.name), C.gold)
    end
    local detail = F.db.itemDetail
    if stale then
        if detail > 1 then
            T.TipLine(tt, L.stale_item, C.muted)
        end
    elseif detail > 1 then
        for _, ln in ipairs(rec.lines) do
            if ln.lvl == "e" or detail >= 3 then
                local color = (ln.c == "g" and GREEN) or (ln.c == "y" and YELLOW) or C.text
                local text = T.Prepare(ln.text)
                local a, b = string.match(text, "^(.-)\t(.*)$")
                if a then
                    T.TipPair(tt, a, b, color)
                else
                    T.TipLine(tt, text, color)
                end
            end
        end
    end
    T.Done(tt)
    tt:Show()
end

function M.install()
    local fn = F:Wrap("items", handler)
    if has_tdp() then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)
        return
    end
    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
        local tt = _G[name]
        if tt and tt.HasScript and tt:HasScript("OnTooltipSetItem") then
            tt:HookScript("OnTooltipSetItem", fn)
        end
    end
end

F:RegisterModule(M)
