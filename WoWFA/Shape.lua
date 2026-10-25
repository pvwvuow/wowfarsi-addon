-- WoWFA Shape.lua - Arabic-script reshaper (+ optional manual bidi) for WoW font strings.
-- WoW draws characters exactly as given, so Persian letters must be turned into
-- their presentation forms (isolated / initial / medial / final) by us:
--   1. map each Persian/Arabic letter to the right form according to joining
--      context, with ZWNJ breaks and lam-alef ligatures  (M.shape_only),
--   2. optionally reorder runs per line (M.line): RTL runs character-reversed,
--      Latin/digit/number runs kept left-to-right. Only needed when the game
--      client does NOT run its own bidi pass (see Core.lua modes).
-- Input is logical UTF-8 Persian text.

local M = {}

local RJ = 1 -- right-joining (connects to the previous letter only)
local DJ = 2 -- dual-joining (connects both ways)
-- letter codepoint -> { class, iso, fin, ini, med }  (ini/med only for DJ)
-- forms live in Arabic Presentation Forms-A/B and are NOT adjacent to the base
-- letter. Every code below was checked against the Unicode decomposition data
-- (<isolated>/<final>/<initial>/<medial> -> base letter).
local F = {}
local function d(letter, form) -- dual-joining: iso/fin/ini/med consecutive
        F[letter] = { DJ, form, form + 1, form + 2, form + 3 }
end
local function r(letter, form) -- right-joining: iso/fin consecutive
        F[letter] = { RJ, form, form + 1 }
end
local function hj(letter, form) -- hamza: never joins, single form
        F[letter] = { RJ, form, form }
end

hj(0x0621, 0xFE80) -- hamza (does not join)
r(0x0622, 0xFE81) -- alef madda
r(0x0623, 0xFE83) -- alef hamza above
r(0x0624, 0xFE85) -- waw hamza
r(0x0625, 0xFE87) -- alef hamza below
d(0x0626, 0xFE89) -- yeh hamza
r(0x0627, 0xFE8D) -- alef
d(0x0628, 0xFE8F) -- be
r(0x0629, 0xFE93) -- te marbuta (iso/fin only)
d(0x062A, 0xFE95) -- te
d(0x062B, 0xFE99) -- the
d(0x062C, 0xFE9D) -- jim
d(0x062D, 0xFEA1) -- hah
d(0x062E, 0xFEA5) -- khah
r(0x062F, 0xFEA9) -- dal
r(0x0630, 0xFEAB) -- thal
r(0x0631, 0xFEAD) -- re
r(0x0632, 0xFEAF) -- zeh
d(0x0633, 0xFEB1) -- sin
d(0x0634, 0xFEB5) -- shin
d(0x0635, 0xFEB9) -- sad
d(0x0636, 0xFEBD) -- dad
d(0x0637, 0xFEC1) -- tah
d(0x0638, 0xFEC5) -- zah
d(0x0639, 0xFEC9) -- ain
d(0x063A, 0xFECD) -- ghain
d(0x0641, 0xFED1) -- fe
d(0x0642, 0xFED5) -- qaf
d(0x0643, 0xFED9) -- kaf (arabic)
d(0x0644, 0xFEDD) -- lam
d(0x0645, 0xFEE1) -- mim
d(0x0646, 0xFEE5) -- noon
d(0x0647, 0xFEE9) -- heh
r(0x0648, 0xFEED) -- vav
r(0x0649, 0xFEEF) -- alef maksura
d(0x064A, 0xFEF1) -- yeh (arabic)
d(0x067E, 0xFB56) -- pe
d(0x0686, 0xFB7A) -- che
r(0x0698, 0xFB8A) -- zhe
d(0x06A9, 0xFB8E) -- kaf (persian)
d(0x06AF, 0xFB92) -- gaf
d(0x06CC, 0xFBFC) -- yeh (persian)
r(0x06C0, 0xFBA4) -- heh with yeh above
d(0x06AD, 0xFBD3) -- ng

local HAMZA = 0x0621
local LAM = 0x0644
local LAM_ALEF = { -- lam + alef variant -> ligature (iso, fin)
        [0x0622] = { 0xFEF5, 0xFEF6 },
        [0x0623] = { 0xFEF7, 0xFEF8 },
        [0x0625] = { 0xFEF9, 0xFEFA },
        [0x0627] = { 0xFEFB, 0xFEFC },
}

local ZWNJ = 0x200C

local function is_mark(cp) -- combining marks: transparent, never join
        return (cp >= 0x064B and cp <= 0x065F) or cp == 0x0670 or (cp >= 0x06D6 and cp <= 0x06DC)
end

local function is_arabic(cp)
        return (cp >= 0x0600 and cp <= 0x06FF) or (cp >= 0xFB50 and cp <= 0xFDFF) or (cp >= 0xFE70 and cp <= 0xFEFF)
end

local function is_alnum(cp) -- Latin letters and digits (ASCII + Persian/Arabic-Indic digits)
        return cp ~= nil
                and ((cp >= 0x41 and cp <= 0x5A) or (cp >= 0x61 and cp <= 0x7A) or (cp >= 0x30 and cp <= 0x39)
                or (cp >= 0x6F0 and cp <= 0x6F9) or (cp >= 0x660 and cp <= 0x669))
end

-- glue characters that belong to a number / token ONLY when they sit inside it
local GLUE_MID = { [0x2E] = true, [0x2F] = true, [0x2D] = true, [0x5F] = true, [0x3A] = true, [0x27] = true, [0x26] = true }

local function decode(s)
        local cps = {}
        local i = 1
        local n = #s
        while i <= n do
                local b = string.byte(s, i)
                local cp, step
                if b < 0x80 then
                        cp, step = b, 1
                elseif b < 0xE0 then
                        cp, step = (b - 0xC0) * 64 + (string.byte(s, i + 1) or 0) - 0x80, 2
                elseif b < 0xF0 then
                        cp, step = (b - 0xE0) * 4096 + ((string.byte(s, i + 1) or 0) - 0x80) * 64 + (string.byte(s, i + 2) or 0) - 0x80, 3
                else
                        cp, step = (b - 0xF0) * 262144 + ((string.byte(s, i + 1) or 0) - 0x80) * 4096 + ((string.byte(s, i + 2) or 0) - 0x80) * 64 + (string.byte(s, i + 3) or 0) - 0x80, 4
                end
                cps[#cps + 1] = cp
                i = i + step
        end
        return cps
end

local function encode(cp)
        if cp < 0x80 then
                return string.char(cp)
        end
        if cp < 0x800 then
                return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
        end
        if cp < 0x10000 then
                return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
        end
        return string.char(0xF0 + math.floor(cp / 262144), 0x80 + math.floor(cp / 4096) % 64, 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
end

-- ---------------------------------------------------------------- reshaping
function M.reshape(cps)
        local n = #cps
        local out = {}
        local i = 1
        while i <= n do
                local cp = cps[i]
                if cp == ZWNJ then
                        i = i + 1 -- breaks joining, renders nothing
                elseif is_mark(cp) then
                        out[#out + 1] = cp
                        i = i + 1
                else
                        local f = F[cp]
                        if not f then
                                out[#out + 1] = cp
                                i = i + 1
                        else
                                -- previous join: skip combining marks only, STOP at ZWNJ
                                local prev_ok = false
                                local j = i - 1
                                while j >= 1 and is_mark(cps[j]) do
                                        j = j - 1
                                end
                                if j >= 1 and cps[j] ~= ZWNJ then
                                        local pf = F[cps[j]]
                                        prev_ok = pf ~= nil and pf[1] == DJ
                                end
                                -- next letter: skip combining marks only, ZWNJ blocks
                                local k = i + 1
                                while k <= n and is_mark(cps[k]) do
                                        k = k + 1
                                end
                                local next_cp = (k <= n and cps[k] ~= ZWNJ) and cps[k] or nil
                                local lam = (cp == LAM and next_cp and LAM_ALEF[next_cp]) or nil
                                if lam then
                                        out[#out + 1] = prev_ok and lam[2] or lam[1]
                                        i = k + 1 -- consume lam + alef
                                else
                                        local form
                                        if f[1] == DJ then
                                                local next_joins = next_cp ~= nil and next_cp ~= HAMZA and F[next_cp] ~= nil
                                                if prev_ok and next_joins then
                                                        form = f[5] -- medial
                                                elseif prev_ok then
                                                        form = f[3] -- final
                                                elseif next_joins then
                                                        form = f[4] -- initial
                                                else
                                                        form = f[2] -- isolated
                                                end
                                        else
                                                form = prev_ok and f[3] or f[2]
                                        end
                                        out[#out + 1] = form
                                        i = i + 1
                                end
                        end
                end
        end
        return out
end

local function to_string(cps)
        local out = {}
        for i = 1, #cps do
                out[i] = encode(cps[i])
        end
        return table.concat(out)
end

-- logical text -> logical text with presentation forms (no reordering)
function M.shape_only(text)
        return to_string(M.reshape(decode(text)))
end

-- ------------------------------------------------------------------- bidi
local MIRROR = { ["("] = ")", [")"] = "(", ["["] = "]", ["]"] = "[", ["{"] = "}", ["}"] = "{", ["<"] = ">", [">"] = "<" }

local function classify(cps, idx)
        local cp = cps[idx]
        if is_alnum(cp) then
                return "L"
        end
        if is_arabic(cp) then
                return "R"
        end
        local p, nx = cps[idx - 1], cps[idx + 1]
        if cp == 0x24 then -- $token prefix
                return is_alnum(nx) and "L" or "N"
        elseif cp == 0x25 or cp == 0x2B then -- 16%  Mythic+
                return is_alnum(p) and "L" or "N"
        elseif GLUE_MID[cp] then -- 3.5  12:30  Zul'Aman  5-10
                return (is_alnum(p) and is_alnum(nx)) and "L" or "N"
        end
        return "N"
end

function M.bidi(cps)
        local runs = {}
        local cur, kind = {}, nil
        local function flush()
                if #cur > 0 then
                        runs[#runs + 1] = { kind = kind, cps = cur }
                end
        end
        for idx, cp in ipairs(cps) do
                local k = classify(cps, idx)
                if k ~= kind then
                        flush()
                        cur, kind = {}, k
                end
                cur[#cur + 1] = cp
        end
        flush()

        -- neutrals inherit their neighbours; base direction is RTL
        for i, run in ipairs(runs) do
                if run.kind == "N" then
                        local left = i > 1 and runs[i - 1].kind or "R"
                        local right = i < #runs and runs[i + 1].kind or "R"
                        run.kind = (left == "L" and right == "L") and "L" or "R"
                end
        end

        -- emit runs last-to-first: visual order for an RTL line
        local out = {}
        for i = #runs, 1, -1 do
                local run = runs[i]
                if run.kind == "R" then
                        for j = #run.cps, 1, -1 do
                                local ch = encode(run.cps[j])
                                out[#out + 1] = (#ch == 1 and MIRROR[ch]) or ch
                        end
                else
                        for _, cp in ipairs(run.cps) do
                                out[#out + 1] = encode(cp)
                        end
                end
        end
        return table.concat(out)
end

-- shape + reorder one line (call after wrapping and after numbers are filled)
function M.line(text)
        return M.bidi(M.reshape(decode(text)))
end

WoWFA_Shape = M
return M
