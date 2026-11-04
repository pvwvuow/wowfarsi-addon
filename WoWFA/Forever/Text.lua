-- WoWFA Forever - Persian text: name markers (like the site), quest tokens,
-- display modes, wrapping, and safe tooltip lines.
--
-- Display modes (same as the retail addon, picked on the welcome screen):
--   1 the client runs its own bidi pass: we only reshape letters
--   2 fully raw: the client shapes and orders
--   3 manual: we wrap, reshape and reorder every line ourselves

local F = WoWFAF
local L = F.L
local Shape = WoWFA_Shape
local T = {}
F.T = T

local RLM = "\226\128\143"
local LRM = "\226\128\142"
local FA_DIGITS = { "\219\176", "\219\177", "\219\178", "\219\179", "\219\180", "\219\181", "\219\182", "\219\183", "\219\184", "\219\185" }

T.FAMILIES = { "npc", "zn", "it", "sp", "ob", "qs", "cls", "tm" }

function T.Mode()
    local m = F.db and F.db.mode
    if m == 1 or m == 2 or m == 3 then
        return m
    end
    return 1
end

function T.Size()
    return (F.db and F.db.fontSize) or 12
end

function T.Digits(s)
    if not (F.db and F.db.faDigits) then
        return s
    end
    return (string.gsub(s, "%d", function(d)
        return FA_DIGITS[tonumber(d) + 1]
    end))
end

-- {{fam:English|Persian}} -> Persian, or English when that family is off
function T.Markers(s)
    local names = F.db and F.db.names or {}
    s = string.gsub(s, "{{(%a+):([^|{}]*)|([^{}]*)}}", function(fam, en, fa)
        if names[fam] == false then
            return en
        end
        return fa
    end)
    -- any other marker left by older data: {{x:a|b}} -> b, {{x:a}} -> a
    s = string.gsub(s, "{{%a+:([^|{}]*)|([^{}]*)}}", "%2")
    s = string.gsub(s, "{{%a+:([^{}]*)}}", "%1")
    return s
end

local function class_fa()
    local _, file = UnitClass("player")
    if not F.Usable(file) then
        return nil
    end
    local loc = UnitClass("player")
    local names = F.D and F.D.names and F.D.names.class
    if names and F.Usable(loc) and names[string.lower(loc)] then
        return names[string.lower(loc)]
    end
    return L.class[file]
end

local function race_fa()
    local loc, file = UnitRace("player")
    if not F.Usable(file) then
        return nil
    end
    return L.race[file] or (F.Usable(loc) and loc) or nil
end

-- quest tokens: $N name, $C class, $R race, $G male:female; , $B new line
function T.Tokens(s)
    local female = UnitSex and UnitSex("player") == 3
    s = string.gsub(s, "%$[Gg]%s*([^:;]*):([^;]*);", function(m, f)
        if female then
            return f
        end
        return m
    end)
    s = string.gsub(s, "%$([NnCcRrBb])", function(c)
        c = string.lower(c)
        if c == "n" then
            local n = UnitName("player")
            return F.Usable(n) and n or ""
        elseif c == "c" then
            return class_fa() or ""
        elseif c == "r" then
            return race_fa() or ""
        end
        return "\n"
    end)
    return s
end

function T.Clean(s)
    s = tostring(s or "")
    s = string.gsub(s, RLM, "")
    s = string.gsub(s, LRM, "")
    s = string.gsub(s, "\r", "")
    return s
end

-- full pipeline for data text
function T.Prepare(s)
    return T.Clean(T.Tokens(T.Markers(s or "")))
end

function T.ShapeLine(s, mode)
    mode = mode or T.Mode()
    if mode == 2 then
        return s
    elseif mode == 3 then
        return Shape.line(s)
    end
    return Shape.shape_only(s)
end

-- --------------------------------------------------------------- wrapping
local measure
local function width_of(s, size)
    if not measure then
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(10, 10)
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -400, -400)
        measure = f:CreateFontString(nil, "ARTWORK")
        measure:SetWordWrap(false)
        measure:SetAlpha(0)
    end
    measure:SetFont(F.FONT, size, "")
    measure:SetText(Shape.shape_only(s))
    local w = measure:GetStringWidth()
    if not w or w <= 0 then
        local _, chars = string.gsub(s, "[^\128-\191]", "")
        w = chars * size * 0.5
    end
    return w
end

function T.Wrap(text, maxWidth, size)
    local lines = {}
    for para in string.gmatch(text .. "\n", "([^\n]*)\n") do
        if para == "" then
            lines[#lines + 1] = ""
        else
            local cur
            for w in string.gmatch(para, "%S+") do
                local cand = cur and (cur .. " " .. w) or w
                if cur == nil or width_of(cand, size) <= maxWidth then
                    cur = cand
                else
                    lines[#lines + 1] = cur
                    cur = w
                end
            end
            if cur then
                lines[#lines + 1] = cur
            end
        end
    end
    return lines
end

-- display lines for a text block in the current (or a forced) mode
function T.Lines(text, width, size, mode)
    mode = mode or T.Mode()
    size = size or T.Size()
    text = T.Clean(text)
    local out = {}
    if mode == 3 then
        for _, ln in ipairs(T.Wrap(text, width or 260, size)) do
            out[#out + 1] = (ln == "") and " " or Shape.line(ln)
        end
    else
        for para in string.gmatch(text .. "\n", "([^\n]*)\n") do
            out[#out + 1] = T.ShapeLine(para, mode)
        end
    end
    return out
end

-- ------------------------------------------------------- UI font strings
local registry = setmetatable({}, { __mode = "k" })

-- fs.wfaSize / fs.wfaMode / fs.wfaJustify may be set by the caller
function T.Set(fs, text, width)
    fs.wfaText, fs.wfaWidth = text or "", width
    registry[fs] = true
    local size = fs.wfaSize or T.Size()
    local mode = fs.wfaMode or T.Mode()
    fs:SetFont(F.FONT, size, "")
    local w = width or fs:GetWidth()
    if not w or w < 40 then
        w = 260
    end
    fs:SetWordWrap(mode ~= 3)
    fs:SetText(table.concat(T.Lines(fs.wfaText, w, size, mode), "\n"))
    fs:SetJustifyH(fs.wfaJustify or "RIGHT")
end

function T.RefreshAll()
    for fs in pairs(registry) do
        if fs.wfaText then
            T.Set(fs, fs.wfaText, fs.wfaWidth)
        end
    end
    F:Fire("text")
end

-- ---------------------------------------------------------------- tooltip
-- Lines we add get our font; the line objects are reused by the next tooltip,
-- so the original font is restored when the tooltip is cleared.
local function restore(tt)
    local list = tt.wfaFonts
    if list then
        for i = #list, 1, -1 do
            local r = list[i]
            if r.font then
                pcall(r.fs.SetFont, r.fs, r.font, r.size, r.flags or "")
            end
            if r.justify then
                pcall(r.fs.SetJustifyH, r.fs, r.justify)
            end
            list[i] = nil
        end
    end
    tt.wfaKey = nil
end

local function hook_tooltip(tt)
    if tt.wfaHooked or not tt.HookScript then
        return
    end
    tt.wfaHooked = true
    pcall(tt.HookScript, tt, "OnTooltipCleared", restore)
    pcall(tt.HookScript, tt, "OnHide", restore)
end

-- true when this content was not added to this tooltip yet
function T.Once(tt, key)
    hook_tooltip(tt)
    if tt.wfaKey == key and tt.wfaLines and tt:NumLines() >= tt.wfaLines then
        return false
    end
    tt.wfaKey = key
    return true
end

function T.Done(tt)
    tt.wfaLines = tt:NumLines()
end

local function style(tt, side)
    hook_tooltip(tt)
    local name = tt:GetName()
    if not name then
        return
    end
    local fs = _G[name .. "Text" .. side .. tt:NumLines()]
    if not fs then
        return
    end
    tt.wfaFonts = tt.wfaFonts or {}
    local font, size, flags = fs:GetFont()
    table.insert(tt.wfaFonts, { fs = fs, font = font, size = size, flags = flags, justify = fs:GetJustifyH() })
    fs:SetFont(F.FONT, T.Size(), "")
    if side == "Left" then
        fs:SetJustifyH("RIGHT")
    end
end

function T.TipLine(tt, text, color, wrapWidth)
    color = color or F.C.text
    local mode = T.Mode()
    local size = T.Size()
    for _, ln in ipairs(T.Lines(text, wrapWidth or (size * 22), size, mode)) do
        tt:AddLine(ln, color[1], color[2], color[3], mode ~= 3)
        style(tt, "Left")
    end
end

-- "left\tright" pairs: Persian reads right to left, so the first part goes right
function T.TipPair(tt, first, second, color)
    color = color or F.C.text
    local mode = T.Mode()
    tt:AddDoubleLine(T.ShapeLine(T.Clean(second), mode), T.ShapeLine(T.Clean(first), mode), color[1], color[2], color[3], color[1], color[2], color[3])
    style(tt, "Left")
    style(tt, "Right")
end

-- plain text of every line (for stale checks); secret lines are skipped
function T.TipText(tt, data)
    local parts = {}
    if data and type(data.lines) == "table" then
        for _, ln in ipairs(data.lines) do
            if F.Usable(ln.leftText) then
                parts[#parts + 1] = ln.leftText
            end
            if F.Usable(ln.rightText) then
                parts[#parts + 1] = ln.rightText
            end
        end
        if #parts > 0 then
            return parts
        end
    end
    local name = tt:GetName()
    if not name then
        return parts
    end
    for i = 1, tt:NumLines() do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = _G[name .. "Text" .. side .. i]
            local t = fs and fs:GetText()
            if F.Usable(t) and t ~= "" then
                parts[#parts + 1] = t
            end
        end
    end
    return parts
end

-- numbers in order + text with every number replaced by "#"
-- (same rule as the exporter: 12, 1.5 -> #; "5." at a sentence end keeps the dot)
function T.NumKey(s)
    local nums, out, pos = {}, {}, 1
    while true do
        local a, b = string.find(s, "%d+", pos)
        if not a then
            out[#out + 1] = string.sub(s, pos)
            break
        end
        if string.sub(s, b + 1, b + 1) == "." and string.find(string.sub(s, b + 2, b + 2), "%d") then
            local _, b2 = string.find(s, "%d+", b + 2)
            b = b2
        end
        out[#out + 1] = string.sub(s, pos, a - 1)
        out[#out + 1] = "#"
        nums[#nums + 1] = string.sub(s, a, b)
        pos = b + 1
    end
    local key = table.concat(out)
    key = string.gsub(key, "%s+", " ")
    key = string.gsub(key, "^ ", "")
    key = string.gsub(key, " $", "")
    return key, nums
end

-- Persian template {0} {1} ... filled with live numbers
function T.Fill(fa, nums)
    return (string.gsub(fa, "{(%d+)}", function(i)
        local v = nums[tonumber(i) + 1]
        if v then
            return T.Digits(v)
        end
        return "{" .. i .. "}"
    end))
end
