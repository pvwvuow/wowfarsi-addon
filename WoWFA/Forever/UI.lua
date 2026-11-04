-- WoWFA Forever - widget kit in the site / retail panel style:
-- smoked glass, fading 1px gold lines, diamond toggles, sigil buttons.
-- Everything is plain (insecure) frames: safe to show in combat.

local F = WoWFAF
local T = F.T
local C = F.C
local UI = {}
F.UI = UI

local function tex(parent, layer, file)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    if file then
        t:SetTexture(F.MEDIA .. file)
    end
    return t
end
UI.Tex = tex

local function gradient(t, dir, r1, g1, b1, a1, r2, g2, b2, a2)
    if CreateColor and t.SetGradient then
        local ok = pcall(t.SetGradient, t, dir, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
        if ok then
            return
        end
    end
    if t.SetGradientAlpha then
        pcall(t.SetGradientAlpha, t, dir, r1, g1, b1, a1, r2, g2, b2, a2)
    end
end

-- gold hairline (horizontal or vertical), faded at the ends by the texture
function UI.Line(parent, vertical, alpha)
    local t = tex(parent, "BORDER", vertical and "line_v" or "line_h")
    t:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], alpha or 0.45)
    if vertical then
        t:SetWidth(1)
    else
        t:SetHeight(1)
    end
    return t
end

function UI.Glass(f, alpha)
    local bg = tex(f, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(C.bg1[1], C.bg1[2], C.bg1[3], alpha or 0.94)
    local sheen = tex(f, "BACKGROUND")
    sheen:SetPoint("TOPLEFT")
    sheen:SetPoint("TOPRIGHT")
    sheen:SetHeight(120)
    sheen:SetColorTexture(1, 1, 1, 1)
    gradient(sheen, "VERTICAL", C.bg2[1], C.bg2[2], C.bg2[3], 0, 0.25, 0.20, 0.10, 0.22)
    local top = UI.Line(f, false, 0.6)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    local bottom = UI.Line(f, false, 0.35)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    local left = UI.Line(f, true, 0.35)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    local right = UI.Line(f, true, 0.35)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    for _, p in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local d = tex(f, "OVERLAY", "diamond")
        d:SetSize(7, 7)
        d:SetPoint("CENTER", f, p, 0, 0)
        d:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.8)
    end
end

-- Persian font string (re-rendered when mode / font size changes)
function UI.Text(parent, size, color, justify, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(F.FONT, size or T.Size(), "")
    fs.wfaSize = size
    fs.wfaJustify = justify or "RIGHT"
    color = color or C.text
    fs:SetTextColor(color[1], color[2], color[3])
    fs.SetFa = function(self, text, width)
        T.Set(self, text, width)
    end
    return fs
end

-- Latin font string (numbers, builds, English notes)
function UI.Latin(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(F.FONT, size or 11, "")
    color = color or C.muted
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function hover(b)
    local h = tex(b, "HIGHLIGHT")
    h:SetAllPoints()
    h:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.07)
end

-- sigil button: framed label
function UI.Button(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 120, h or 24)
    local bg = tex(b, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(C.bg2[1], C.bg2[2], C.bg2[3], 0.9)
    for _, side in ipairs({ "TOP", "BOTTOM" }) do
        local l = UI.Line(b, false, 0.55)
        l:SetPoint(side .. "LEFT")
        l:SetPoint(side .. "RIGHT")
    end
    hover(b)
    b.label = UI.Text(b, 11, C.goldLight, "CENTER")
    b.label:SetPoint("CENTER")
    b.SetLabel = function(self, t)
        self.label:SetFa(t, (w or 120) - 8)
    end
    b:SetLabel(text)
    b:SetScript("OnClick", function(self, button)
        if onClick then
            onClick(self, button)
        end
    end)
    return b
end

-- diamond toggle row: [desc / label] [diamond]  (right to left)
function UI.Toggle(parent, width, label, desc, get, set)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, desc and 40 or 26)
    hover(row)
    row.box = tex(row, "ARTWORK", "diamond_hollow")
    row.box:SetSize(14, 14)
    row.box:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -6)
    row.fill = tex(row, "OVERLAY", "diamond")
    row.fill:SetSize(8, 8)
    row.fill:SetPoint("CENTER", row.box, "CENTER")
    row.label = UI.Text(row, 12, C.text)
    row.label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -26, -4)
    row.label:SetWidth(width - 140)
    row.label:SetFa(label, width - 140)
    if desc then
        row.desc = UI.Text(row, 10, C.muted)
        row.desc:SetPoint("TOPRIGHT", row.label, "BOTTOMRIGHT", 0, -2)
        row.desc:SetWidth(width - 140)
        row.desc:SetFa(desc, width - 140)
    end
    row.Update = function(self)
        local on = get()
        local dim = self.dimmed
        local c = on and C.gold or C.off
        self.box:SetVertexColor(c[1], c[2], c[3], dim and 0.4 or 1)
        self.fill:SetShown(on and true or false)
        self.fill:SetVertexColor(C.goldLight[1], C.goldLight[2], C.goldLight[3], dim and 0.4 or 1)
        local t = (on and not dim) and C.text or C.muted
        self.label:SetTextColor(t[1], t[2], t[3])
    end
    row:SetScript("OnClick", function(self)
        set(not get())
        self:Update()
    end)
    row:Update()
    return row
end

-- option cycler: [button: current option] .... [label]
function UI.Cycler(parent, width, label, options, get, set)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, 28)
    row.label = UI.Text(row, 12, C.text)
    row.label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.label:SetWidth(width - 200)
    row.label:SetFa(label, width - 200)
    row.btn = UI.Button(row, options[get()] or "?", 180, 22, function()
        local v = get() % #options + 1
        set(v)
        row:Update()
    end)
    row.btn:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.Update = function(self)
        self.btn:SetLabel(options[get()] or "?")
    end
    return row
end

-- vertical scroll page (mouse wheel), content = page.child
function UI.ScrollPage(parent, width, height)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:SetSize(width, height)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(width, height)
    sf:SetScrollChild(child)
    sf.child = child
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, child:GetHeight() - self:GetHeight())
        local v = math.min(max, math.max(0, self:GetVerticalScroll() - delta * 36))
        self:SetVerticalScroll(v)
    end)
    local bar = tex(sf, "OVERLAY")
    bar:SetWidth(2)
    bar:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.35)
    sf.bar = bar
    sf.UpdateBar = function(self)
        local h, ch = self:GetHeight(), child:GetHeight()
        if ch <= h + 1 then
            bar:Hide()
            return
        end
        bar:Show()
        local bh = math.max(20, h * h / ch)
        local off = (self:GetVerticalScroll() / (ch - h)) * (h - bh)
        bar:ClearAllPoints()
        bar:SetHeight(bh)
        bar:SetPoint("TOPLEFT", self, "TOPLEFT", -6, -off)
    end
    sf:SetScript("OnVerticalScroll", function(self)
        self:UpdateBar()
    end)
    sf:SetScript("OnScrollRangeChanged", function(self)
        self:UpdateBar()
    end)
    return sf
end

-- section header: gold text + fading line
function UI.Header(parent, text, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 24)
    f.text = UI.Text(f, 13, C.gold)
    f.text:SetPoint("RIGHT", f, "RIGHT", -2, 2)
    f.text:SetFa(text, width - 10)
    local l = UI.Line(f, false, 0.4)
    l:SetPoint("BOTTOMLEFT")
    l:SetPoint("BOTTOMRIGHT")
    return f
end

-- --------------------------------------------------------------- toast
local toast, queue = nil, {}
local function show_next()
    local msg = table.remove(queue, 1)
    if not msg then
        return
    end
    toast.text:SetFa(msg, 380)
    toast:SetHeight(math.max(36, toast.text:GetStringHeight() + 18))
    toast.t = 0
    toast:SetAlpha(0)
    toast:Show()
end

function F.Toast(msg)
    if not toast then
        toast = CreateFrame("Button", "WoWFAF_Toast", UIParent)
        toast:SetSize(420, 40)
        toast:SetPoint("TOP", UIParent, "TOP", 0, -140)
        toast:SetFrameStrata("HIGH")
        UI.Glass(toast, 0.9)
        toast.text = UI.Text(toast, 12, C.text, "CENTER")
        toast.text:SetPoint("CENTER")
        toast.text:SetWidth(390)
        toast:SetScript("OnUpdate", function(self, el)
            self.t = self.t + el
            if self.t < 0.3 then
                self:SetAlpha(self.t / 0.3)
            elseif self.t > 7 then
                local a = 1 - (self.t - 7) / 0.8
                if a <= 0 then
                    self:Hide()
                    show_next()
                else
                    self:SetAlpha(a)
                end
            else
                self:SetAlpha(1)
            end
        end)
        toast:SetScript("OnClick", function(self)
            self:Hide()
            if F.OpenPanel then
                F.OpenPanel("health")
            end
            show_next()
        end)
        toast:Hide()
    end
    for _, q in ipairs(queue) do
        if q == msg then
            return
        end
    end
    table.insert(queue, msg)
    if #queue > 5 then
        table.remove(queue, 1)
    end
    if not toast:IsShown() then
        show_next()
    end
end
