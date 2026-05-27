local ESP = {}
ESP.__index = ESP

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

ESP.Objects = {}
ESP.Categories = {}

ESP.Settings = {
    Enabled = true,

    Highlight = true,
    Text = false,
    Tracer = false,

    DefaultColor = Color3.fromRGB(255,255,255),
    DefaultPulse = false,
    DefaultPulseTime = 1,

    FillTransparency = 0.8,
    OutlineTransparency = 0,

    DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
}

function ESP:SetSetting(i,v)
    self.Settings[i] = v

    for obj,data in pairs(self.Objects) do
        if i == "Highlight" and data.Highlight then
            data.Highlight.Enabled =
                v and self.Settings.Enabled
        end

        if i == "Tracer" and data.Tracer then
            data.Tracer.Visible =
                v and self.Settings.Enabled
        end

        if i == "Text" and data.Text then
            data.Text.Enabled =
                v and self.Settings.Enabled
        end
    end
end

function ESP:GetSetting(i)
    return self.Settings[i]
end

function ESP:CreateCategory(name,settings)
    self.Categories[name] = {
        Settings = settings or {},
        Objects = {}
    }
end

function ESP:GetCategory(name)
    return self.Categories[name]
end

function ESP:ToggleCategory(name,state)
    local cat = self.Categories[name]

    if not cat then return end

    for obj,_ in pairs(cat.Objects) do
        local data = self.Objects[obj]

        if data then
            if data.Highlight then
                data.Highlight.Enabled = state
            end

            if data.Tracer then
                data.Tracer.Visible = state
            end

            if data.Text then
                data.Text.Enabled = state
            end
        end
    end
end

function ESP:_Gui(obj,state)
    for _,v in ipairs(obj:GetDescendants()) do
        if v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
            v.AlwaysOnTop = state
        end
    end
end

function ESP:AddConnection(obj,name,func)
    local data = self.Objects[obj]

    if not data then return end

    data.Connections[name] =
        RunService.RenderStepped:Connect(function(dt)
            func(obj,data,dt)
        end)

    return data.Connections[name]
end

function ESP:RemoveConnection(obj,name)
    local data = self.Objects[obj]

    if not data then return end

    local c = data.Connections[name]

    if c then
        c:Disconnect()
        data.Connections[name] = nil
    end
end

function ESP:ClearConnections(obj)
    local data = self.Objects[obj]

    if not data then return end

    for _,c in pairs(data.Connections) do
        c:Disconnect()
    end

    table.clear(data.Connections)
end

function ESP:Add(obj,color,pulse,pulseTime,category)
    if not obj or not obj:IsA("Instance") then
        return warn("Invalid object")
    end

    if obj:FindFirstChild("__esp") then
        return obj.__highlight
    end

    local cat = category and self.Categories[category]
    local settings = self.Settings

    color =
        color
        or (cat and cat.Settings.Color)
        or settings.DefaultColor

    pulse =
        pulse ~= nil and pulse
        or (cat and cat.Settings.Pulse)
        or settings.DefaultPulse

    pulseTime =
        pulseTime
        or (cat and cat.Settings.PulseTime)
        or settings.DefaultPulseTime

    local tracerEnabled =
        (cat and cat.Settings.Tracer)
        or settings.Tracer

    local textEnabled =
        (cat and cat.Settings.Text)
        or settings.Text

    local tag = Instance.new("BoolValue")
    tag.Name = "__esp"
    tag.Parent = obj

    local highlight = Instance.new("Highlight")
    highlight.Name = "__highlight"
    highlight.Adornee = obj
    highlight.DepthMode = settings.DepthMode
    highlight.FillTransparency = settings.FillTransparency
    highlight.OutlineTransparency = settings.OutlineTransparency
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.Enabled = settings.Enabled and settings.Highlight
    highlight.Parent = obj

    local billboard
    local label

    if textEnabled then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "__text"
        billboard.Size = UDim2.new(0,100,0,40)
        billboard.AlwaysOnTop = true
        billboard.StudsOffset = Vector3.new(0,3,0)
        billboard.Adornee = obj

        billboard.Enabled =
            settings.Enabled
            and settings.Text

        billboard.Parent = obj

        label = Instance.new("TextLabel")
        label.Size = UDim2.new(1,0,1,0)
        label.BackgroundTransparency = 1
        label.Text = obj.Name
        label.TextColor3 = color
        label.TextStrokeTransparency = 0
        label.TextScaled = true
        label.Font = Enum.Font.SourceSansBold
        label.Parent = billboard
    end

    local tracer

    if tracerEnabled then
        tracer = Drawing.new("Line")
        tracer.Visible =
            settings.Enabled
            and settings.Tracer
        tracer.Color = color
        tracer.Thickness = 2
        tracer.Transparency = 1
    end

    self:_Gui(obj,settings.Enabled)

    self.Objects[obj] = {
        Highlight = highlight,
        Connections = {},
        Category = category,

        Tracer = tracer,
        Text = billboard,
        Label = label,
    }

    local data = self.Objects[obj]

    if cat then
        cat.Objects[obj] = true
    end

    if pulse then
        local t = 0

        self:AddConnection(obj,"Pulse",function(_,data,dt)
            t += dt

            local alpha =
                (math.sin((t / pulseTime) * math.pi * 2) + 1) / 2

            data.Highlight.FillTransparency =
                0.4 + (alpha * 0.5)

            data.Highlight.OutlineTransparency =
                alpha * 0.5
        end)
    end

    if tracer then
        self:AddConnection(obj,"Tracer",function(obj,data)
            local part =
                obj.PrimaryPart
                or obj:FindFirstChildWhichIsA("BasePart")

            if not part then
                data.Tracer.Visible = false
                return
            end

            local pos,visible =
                Camera:WorldToViewportPoint(part.Position)

            if visible and ESP.Settings.Enabled and settings.Tracer then
                local viewport = Camera.ViewportSize

                data.Tracer.Visible = true
                data.Tracer.From =
                    Vector2.new(viewport.X / 2,viewport.Y)

                data.Tracer.To =
                    Vector2.new(pos.X,pos.Y)
            else
                data.Tracer.Visible = false
            end
        end)
    end

    return highlight
end

function ESP:Remove(obj)
    if not obj then return end

    local data = self.Objects[obj]

    if data then
        self:ClearConnections(obj)

        if data.Tracer then
            data.Tracer:Remove()
        end

        if data.Category and self.Categories[data.Category] then
            self.Categories[data.Category].Objects[obj] = nil
        end
    end

    local h = obj:FindFirstChild("__highlight")
    local t = obj:FindFirstChild("__esp")
    local b = obj:FindFirstChild("__text")

    if h then
        h:Destroy()
    end

    if t then
        t:Destroy()
    end

    if b then
        b:Destroy()
    end

    self.Objects[obj] = nil
end

function ESP:Toggle(state)
    self.Settings.Enabled = state

    for obj,data in pairs(self.Objects) do
        if data.Highlight then
            data.Highlight.Enabled =
                state and self.Settings.Highlight
        end

        if data.Tracer then
            data.Tracer.Visible =
                state and self.Settings.Tracer
        end

        if data.Text then
            data.Text.Enabled =
                state and self.Settings.Text
        end

        self:_Gui(obj,state)
    end
end

function ESP:Clear()
    for obj,_ in pairs(self.Objects) do
        self:Remove(obj)
    end
end

return ESP