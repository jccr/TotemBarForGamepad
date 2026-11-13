-- Minimal WoW API stand-ins: frames record attributes and wrapped scripts so
-- the snippets GamepadKit installs can be extracted and syntax-checked.
SNIPPETS = {}
local Frame = {}
-- Real widget methods are no-ops here; any other field is nil, as in WoW.
local NOOP = {}
for name in ([[SetSize SetPoint ClearAllPoints SetAllPoints RegisterForClicks SetAlpha
    SetScale SetFrameStrata EnableMouse SetFrameLevel SetAtlas SetTexture SetTexCoord SetScript HookScript
    SetRotation SetBlendMode SetVertexColor RegisterEvent SetLooping SetOffset SetDuration
    SetSmoothing SetOrder Play Stop SetFromAlpha SetToAlpha SetColorTexture SetWidth SetHeight SetJustifyH SetFontObject
    SetHideCountdownNumbers EnableGamePadButton SetPropagateKeyboardInput
    GetNormalTexture GetPushedTexture GetHighlightTexture]]):gmatch("%S+") do
    NOOP[name] = function() end
end
Frame.__index = function(t, k)
    return rawget(Frame, k) or NOOP[k]
end
function Frame:SetAttribute(k, v)
    self.attrs[k] = v
    if type(v) == "string" and (k:sub(1, 1) == "_") then SNIPPETS[#SNIPPETS + 1] = { name = (self.name or "?") .. ":" .. k, body = v } end
end
function Frame:GetAttribute(k) return self.attrs[k] end
function Frame:GetName() return self.name end
function Frame:SetText(t) rawset(self, "text", t) end
function Frame:GetText() return rawget(self, "text") end
function Frame:CreateTexture() return setmetatable({ attrs = {} }, Frame) end
function Frame:CreateFontString() return setmetatable({ attrs = {} }, Frame) end
function Frame:CreateAnimationGroup() return setmetatable({ attrs = {} }, Frame) end
function Frame:CreateAnimation() return setmetatable({ attrs = {} }, Frame) end
function Frame:GetFrameLevel() return 1 end
function Frame:IsShown() return rawget(self, "shown") == true end
function Frame:Show() rawset(self, "shown", true) end
function Frame:Hide() rawset(self, "shown", false) end
function Frame:SetShown(v) rawset(self, "shown", v and true or false) end
function CreateFrame(_, name) return setmetatable({ name = name, attrs = {} }, Frame) end
function SecureHandlerWrapScript(frame, script, header, pre) SNIPPETS[#SNIPPETS + 1] = { name = (frame.name or "?") .. ":wrap " .. script, body = pre } end
function SecureHandlerSetFrameRef() end
function SecureHandlerExecute(_, body) SNIPPETS[#SNIPPETS + 1] = { name = "execute", body = body } end
UIParent = CreateFrame("Frame", "UIParent")
C_Timer = { NewTicker = function() end, After = function() end }
