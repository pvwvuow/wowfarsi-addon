-- WoWFA Core.lua - shows the Persian talent text under the English tooltip.
-- Pipeline per docs/ADDON.md: lookup -> resolve $?conditionals (player state)
-- -> fill raw $tokens from the live English description (option B fallback)
-- -> hand the text to the tooltip (see display modes below).
--
-- Display modes (/wowfa mode 1|2|3):
--   1 (default) the game client runs its own bidi pass on right-to-left text,
--               so we only reshape letters into presentation forms and let the
--               client order and wrap the line.
--   2           fully raw: logical Persian text, the client shapes and orders.
--   3           manual: we reshape AND reorder every line ourselves (only for a
--               client without any bidi support).

local ADDON_NAME = ...
local Shape = WoWFA_Shape

local Font = "Interface\\AddOns\\WoWFA\\Fonts\\Vazirmatn.ttf"
local FONT_SIZE = 12
local FA_COLOR_R, FA_COLOR_G, FA_COLOR_B = 0.85, 0.87, 0.92
local RLM = "\226\128\143" -- U+200F RIGHT-TO-LEFT MARK: makes the base direction RTL

WoWFA_Data = WoWFA_Data or {}
WoWFA_En = WoWFA_En or {}

local function get_mode()
        local m = WoWFA_DB and WoWFA_DB.mode
        if m == 1 or m == 2 or m == 3 then
                return m
        end
        return 1
end

-- ------------------------------------------------------------- conditionals
-- $?c1[A][B]   -> spec index within the class (1-based, like the talent frame)
-- $?a123[A][B] -> the player currently has aura 123
-- $?s123[A][B] -> the player knows spell 123
-- Unknown conditions fall back to the first branch.
local function spec_index()
        if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
                return C_SpecializationInfo.GetSpecialization() or 1
        end
        return GetSpecialization and GetSpecialization() or 1
end

local function eval_cond(cond)
        local kind, id = string.match(cond, "^([cas])(%d+)$")
        if kind == "c" then
                return tonumber(id) == spec_index()
        elseif kind == "a" then
                if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
                        return C_UnitAuras.GetPlayerAuraBySpellID(tonumber(id)) ~= nil
                end
                return false
        elseif kind == "s" then
                if IsSpellKnown then
                        return IsSpellKnown(tonumber(id))
                end
                return false
        end
        return nil -- unknown -> caller keeps branch A
end

-- scan balanced [..] groups starting at s[pos] == "["
local function read_group(s, pos)
        local depth = 0
        for i = pos, #s do
                local c = string.sub(s, i, i)
                if c == "[" then
                        depth = depth + 1
                elseif c == "]" then
                        depth = depth - 1
                        if depth == 0 then
                                return string.sub(s, pos + 1, i - 1), i + 1
                        end
                end
        end
        return nil, pos
end

local function resolve_conditionals(text)
        local out = {}
        local i = 1
        while i <= #text do
                local a, b = string.find(text, "%$%?", i)
                if not a then
                        out[#out + 1] = string.sub(text, i)
                        break
                end
                out[#out + 1] = string.sub(text, i, a - 1)
                local condEnd = string.find(text, "[", b + 1, true)
                if not condEnd then
                        out[#out + 1] = string.sub(text, a)
                        break
                end
                local cond = string.sub(text, b + 1, condEnd - 1)
                -- game data itself can carry a stray ']' inside the condition
                -- ($?a137008][A][B], DK talent 434905 "Grim Reaper"). Keep the
                -- leading <kind><id> part so the condition still evaluates and
                -- the stray bracket never reaches the tooltip.
                cond = string.match(cond, "^%s*([cas]%d+)") or cond
                local branchA, afterA = read_group(text, condEnd)
                local branchB = ""
                if afterA and string.sub(text, afterA, afterA) == "[" then
                        branchB, afterA = read_group(text, afterA)
                end
                if branchA == nil then
                        out[#out + 1] = string.sub(text, a)
                        break
                end
                local ok = eval_cond(cond)
                out[#out + 1] = (ok == false and branchB or branchA)
                i = afterA or (b + 1)
        end
        return table.concat(out)
end

-- --------------------------------------------------- raw-token number fill
-- The export resolved every plain client-table value; what is left depends on
-- the player. The English template (WoWFA_En) is aligned against the live
-- English description (C_Spell.GetSpellDescription) to read each token's
-- value, then the same token is replaced in the Persian text.
local function tpl_segments(tpl)
        -- returns { {lit="..."}, {tok="$s1"}, ... } in order
        local segs = {}
        local i = 1
        while i <= #tpl do
                local c = string.sub(tpl, i, i)
                if c == "$" then
                        local m
                        local b1 = string.sub(tpl, i + 1, i + 1)
                        if b1 == "{" then
                                m = string.match(tpl, "%$%b{}", i)
                        elseif b1 == "@" then
                                m = string.match(tpl, "%$@spell%a+%d+", i)
                        elseif b1 == "?" then
                                m = string.match(tpl, "%$%?[^%[]*", i)
                        elseif b1 == "<" then
                                m = string.match(tpl, "%$<[^>]*>", i)
                        else
                                m = string.match(tpl, "%$%d*%a%d*", i)
                        end
                        if m and #m > 0 then
                                segs[#segs + 1] = { tok = m }
                                i = i + #m
                        else
                                segs[#segs + 1] = { lit = "$" }
                                i = i + 1
                        end
                else
                        local j = string.find(tpl, "$", i, true) or (#tpl + 1)
                        if j > i then
                                segs[#segs + 1] = { lit = string.sub(tpl, i, j - 1) }
                        end
                        i = j
                end
        end
        return segs
end

local function fill_numbers(spellId, fa)
        local tpl = WoWFA_En[spellId]
        if not tpl then
                return fa
        end
        local ok, en = pcall(C_Spell.GetSpellDescription, spellId)
        if not ok or not en or en == "" then
                return fa
        end
        local segs = tpl_segments(tpl)
        -- walk the live English text: each token's value = the text between the
        -- end of the previous literal and the start of the next literal
        local values, pos = {}, 1
        local failed = false
        for si = 1, #segs do
                local seg = segs[si]
                if seg.lit then
                        local at = string.find(en, seg.lit, pos, true)
                        if not at then
                                failed = true
                                break
                        end
                        pos = at + #seg.lit
                else
                        -- find where the next literal starts
                        local nxt
                        for sj = si + 1, #segs do
                                if segs[sj].lit and #segs[sj].lit > 0 then
                                        nxt = sj
                                        break
                                end
                        end
                        local val
                        if nxt then
                                local at = string.find(en, segs[nxt].lit, pos, true)
                                if not at then
                                        failed = true
                                        break
                                end
                                val = string.sub(en, pos, at - 1)
                                pos = at
                        else
                                val = string.sub(en, pos)
                        end
                        if values[seg.tok] == nil then
                                values[seg.tok] = val
                        end
                end
        end
        if failed then
                return fa -- alignment lost -> template shows as-is (raw tokens)
        end
        -- replace longest tokens first so $s1 never eats $s12
        local toks = {}
        for tok in pairs(values) do
                toks[#toks + 1] = tok
        end
        table.sort(toks, function(x, y)
                return #x > #y
        end)
        for _, tok in ipairs(toks) do
                local v = (values[tok] or ""):gsub("%%", "%%%%")
                local pat = tok:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
                -- malformed tokens coming from the game data itself (e.g.
                -- ${$s1/-1000)} on priest talent 390670) must degrade to
                -- "left raw", never raise and never abort the whole fill
                local ok2, err = pcall(function()
                        fa = fa:gsub(pat, v)
                end)
                if not ok2 then
                        if WoWFA_DEBUG then
                                print("WoWFA fill skip " .. tostring(tok) .. ": " .. tostring(err))
                        end
                end
        end
        return fa
end

-- -------------------------------------------------------------------- wrap
-- only used by mode 3 (manual): in modes 1 and 2 the client wraps the line
local measureFrame = CreateFrame("Frame", "WoWFAMeasure", UIParent)
measureFrame:SetSize(10, 10)
measureFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -200, -200)
measureFrame:SetFrameStrata("TOOLTIP")
local measure = measureFrame:CreateFontString(nil, "ARTWORK")
measure:SetFont(Font, FONT_SIZE, "")
measure:SetAlpha(0)
measure:SetWordWrap(false)
measure:SetJustifyH("LEFT")

local function text_width(s)
        measure:SetText(s)
        local w = measure:GetStringWidth()
        if not w or w <= 0 then
                -- measuring failed: estimate from the character count
                local _, chars = string.gsub(s, "[^\128-\191]", "")
                w = chars * FONT_SIZE * 0.55
        end
        return w
end

local function wrap(text, maxWidth)
        if maxWidth < 120 then
                return { text }
        end
        local lines = {}
        for para in string.gmatch(text, "([^\n]*)\n?") do
                if para == "" and #lines > 0 then
                        lines[#lines + 1] = ""
                else
                        local words = {}
                        for w in string.gmatch(para, "%S+") do
                                words[#words + 1] = w
                        end
                        local cur
                        for _, w in ipairs(words) do
                                local cand = cur and (cur .. " " .. w) or w
                                if cur == nil or text_width(cand) <= maxWidth then
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
        if #lines == 0 then
                lines[1] = ""
        end
        return lines
end

-- ------------------------------------------------------------------- hook
local function style_last_line(tooltip)
        local name = tooltip:GetName()
        local fs = name and _G[name .. "TextLeft" .. tooltip:NumLines()]
        if fs and fs:GetFont() then
                fs:SetFont(Font, FONT_SIZE, "")
                if fs.SetJustifyH then
                        fs:SetJustifyH("RIGHT")
                end
        end
end

local function add_persian(tooltip, spellId)
        local fa = WoWFA_Data[spellId]
        if not fa then
                return
        end
        local ok, result = pcall(function()
                fa = resolve_conditionals(fa)
                fa = fill_numbers(spellId, fa)
                local mode = get_mode()
                if mode == 3 then
                        local width = tooltip:GetWidth() - 40
                        if width < 200 then
                                width = 260
                        end
                        local lines = wrap(fa, width)
                        for _, ln in ipairs(lines) do
                                tooltip:AddLine(ln == "" and " " or Shape.line(ln), FA_COLOR_R, FA_COLOR_G, FA_COLOR_B, true)
                                style_last_line(tooltip)
                        end
                else
                        -- one tooltip line per paragraph; the client wraps and orders it
                        for para in string.gmatch(fa, "([^\n]*)\n?") do
                                if para ~= "" then
                                        local txt = (mode == 1) and Shape.shape_only(para) or para
                                        tooltip:AddLine(RLM .. txt, FA_COLOR_R, FA_COLOR_G, FA_COLOR_B, true)
                                        style_last_line(tooltip)
                                end
                        end
                end
                tooltip:Show()
        end)
        if not ok then
                if WoWFA_DEBUG then
                        print("WoWFA error: " .. tostring(result))
                end
        end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip)
        if tooltip:IsForbidden() then
                return
        end
        local spellId
        if TooltipUtil and TooltipUtil.GetDisplayedSpell then
                local _, id = TooltipUtil.GetDisplayedSpell(tooltip)
                spellId = id
        end
        if not spellId and tooltip.GetSpellId then
                spellId = tooltip:GetSpellId()
        end
        if spellId then
                add_persian(tooltip, spellId)
        end
end)

-- /wowfa mode 1|2|3   - pick how the Persian line is drawn (saved between sessions)
SLASH_WOWFA1 = "/wowfa"
SlashCmdList["WOWFA"] = function(msg)
        local cmd, arg = string.match(msg or "", "^%s*(%a*)%s*(%d*)")
        if cmd == "mode" and (arg == "1" or arg == "2" or arg == "3") then
                WoWFA_DB = WoWFA_DB or {}
                WoWFA_DB.mode = tonumber(arg)
                print("WoWFA: display mode " .. arg .. " - hover a talent again")
        else
                print("WoWFA: mode = " .. get_mode() .. "  (use /wowfa mode 1, 2 or 3)")
        end
end

print("WoWFA loaded: " .. (function()
        local n = 0
        for _ in pairs(WoWFA_Data) do
                n = n + 1
        end
        return n
end)() .. " Persian talents")

-- test hook (only active when a harness pre-sets WoWFA_TEST)
if WoWFA_TEST then
        WoWFA_internals = {
                resolve_conditionals = resolve_conditionals,
                fill_numbers = fill_numbers,
                wrap = wrap,
        }
end
