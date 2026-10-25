-- WoWFA Shape.lua - Arabic-script reshaper + bidi reordering for WoW font strings.
-- WoW does not shape Arabic script or run RTL, so we do it ourselves:
--   1. map each Persian/Arabic letter to its presentation form (isolated /
--      initial / medial / final) according to joining context, with ZWNJ
--      breaks and lam-alef ligatures,
--   2. reorder runs per line: RTL runs character-reversed, Latin/digit/number
--      runs (spell names, $tokens, digits, percentages) kept left-to-right,
--      ASCII brackets mirrored inside RTL runs.
-- Input is logical UTF-8 Persian text, output is a visual string that a plain
-- left-to-right FontString renders correctly. Call per wrapped line.

local M = {}

local RJ = 1 -- right-joining (connects to the previous letter only)
local DJ = 2 -- dual-joining (connects both ways)
-- letter codepoint -> { class, iso, fin, ini, med }  (ini/med only for DJ)
-- forms live in Arabic Presentation Forms-B / Arabic Supplement blocks and
-- must be mapped explicitly (they are NOT adjacent to the base letter)
local F = {}
local function d(letter, form) -- dual-joining: iso/fin/ini/med consecutive
        F[letter] = { DJ, form, form + 1, form + 2, form + 3 }
end
local function r(letter, form) -- right-joining: iso/fin consecutive
        F[letter] = { RJ, form, form + 1 }
end

r(0x0621, 0xFE80) -- hamza
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
r(0x062F, 0xFEAB) -- dal
r(0x0630, 0xFEAD) -- thal
r(0x0631, 0xFEAF) -- re
r(0x0632, 0xFEB1) -- zeh
d(0x0633, 0xFEB3) -- sin
d(0x0634, 0xFEB7) -- shin
d(0x0635, 0xFEBB) -- sad
d(0x0636, 0xFEBF) -- dad
d(0x0637, 0xFEC3) -- tah
d(0x0638, 0xFEC7) -- zah
d(0x0639, 0xFECB) -- ain
d(0x063A, 0xFECF) -- ghain
d(0x0641, 0xFED3) -- fe
d(0x0642, 0xFED7) -- qaf
d(0x0643, 0xFEDB) -- kaf (arabic)
d(0x0644, 0xFEDF) -- lam
d(0x0645, 0xFEE3) -- mim
d(0x0646, 0xFEE7) -- noon
d(0x0647, 0xFEEB) -- heh
r(0x0648, 0xFEED) -- vav
r(0x0649, 0xFEEF) -- alef maksura
d(0x064A, 0xFEF1) -- yeh (arabic)
d(0x067E, 0xFB56) -- pe
d(0x0686, 0xFB7A) -- che
r(0x0698, 0xFB8A) -- zhe
d(0x06A9, 0xFB8E) -- kaf (persian)
d(0x06AF, 0xFB92) -- gaf
d(0x06CC, 0xFBFC) -- yeh (persian)
r(0x06C0, 0xFBAA) -- heh with yeh above
d(0x06AD, 0xFBD3) -- ng

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

local function is_ltr(cp) -- Latin letters, digits and number/token glue
        if (cp >= 0x41 and cp <= 0x5A) or (cp >= 0x61 and cp <= 0x7A) or (cp >= 0x30 and cp <= 0x39) then
                return true
        end
        local glue = { [0x24] = true, [0x25] = true, [0x2B] = true, [0x2D] = true, [0x2E] = true, [0x2F] = true,
                [0x5F] = true, [0x3A] = true, [0x27] = true, [0x26] = true }
        return glue[cp] or false
end

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
                                                local next_joins = next_cp ~= nil and F[next_cp] ~= nil
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

-- ------------------------------------------------------------------- bidi
local MIRROR = { ["("] = ")", [")"] = "(", ["["] = "]", ["]"] = "[", ["{"] = "}", ["}"] = "{", ["<"] = ">", [">"] = "<" }

function M.bidi(cps)
        local runs = {}
        local cur, kind = {}, nil
        local function flush()
                if #cur > 0 then
                        runs[#runs + 1] = { kind = kind, cps = cur }
                end
        end
        for _, cp in ipairs(cps) do
                local k = is_arabic(cp) and "R" or (is_ltr(cp) and "L" or "N")
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

-- shape one line (call after wrapping and after numbers are filled)
function M.line(text)
        return M.bidi(M.reshape(decode(text)))
end

WoWFA_Shape = M
return M
