local identifyexecutorname = (identifyexecutor and identifyexecutor()) or "Unknown"
local clonereference = cloneref or function(...) return ... end
local clonefunction = clonefunction or function(...) return ... end

local voicechatservice = clonereference(game:GetService("VoiceChatService"))
local voicechatinternal = clonereference(game:GetService("VoiceChatInternal"))
local coregui = game:GetService("CoreGui")
local startergui = game:GetService("StarterGui")
local players = game:GetService("Players")
local localplayer = players.LocalPlayer
local getconnectionsfunc = clonefunction(getconnections)

local mutedimage = "rbxasset://textures/ui/VoiceChat/MicLight/Muted.png"
local ismuted = true
local hiddenfolder = Instance.new("Folder", game:GetService("RobloxReplicatedStorage"))

local topbarapp = coregui:WaitForChild("TopBarApp", 15):WaitForChild("TopBarApp", 15)
local unibarleft = topbarapp:WaitForChild("UnibarLeftFrame", 15)
local unibarmenu = unibarleft:WaitForChild("UnibarMenu", 15) or unibarleft:WaitForChild("ChromeMenu", 15)
local unibarcontainer


local function getunibarcontainer()
    if not unibarmenu then return nil end
    local frame = unibarmenu:WaitForChild("2", 15)
    if not frame then return nil end
    local unibar = frame:FindFirstChild("Unibar") or frame
    return unibar:WaitForChild("3", 15)
end

local function findmicbutton()
    if unibarcontainer then
        local found = unibarcontainer:FindFirstChild("toggle_mic_mute", true)
        if found then return found end
    end
    if unibarmenu then return unibarmenu:FindFirstChild("toggle_mic_mute", true) end
    return nil
end

pcall(function()
    unibarcontainer = getunibarcontainer()
end)

local micmutebutton = findmicbutton()

local function geticonlabel(button)
    button = button or micmutebutton
    local frame = button:WaitForChild("IntegrationIconFrame", 15)
    local container = frame:WaitForChild("IntegrationIcon", 15)
    return container:FindFirstChild("1") or frame:FindFirstChildOfClass("ImageLabel") or frame:FindFirstChildOfClass("ImageButton")
end

local function setmutestate(state)
    local audiodereviceinput = localplayer:FindFirstChildWhichIsA("AudioDeviceInput", true)
    if audiodereviceinput then
        audiodereviceinput.Active = not state
    else
        voicechatinternal:PublishPause(state)
    end
end

if not micmutebutton then 
    voicechatservice:joinVoice() 
    pcall(function()
        unibarcontainer = getunibarcontainer()
        micmutebutton = unibarcontainer and unibarcontainer:WaitForChild("toggle_mic_mute", 15) or findmicbutton()
    end)
end

if not micmutebutton then return print("Mic button not found - UI path changed.") end

startergui:SetCore("SendNotification", {Title = "mask say hiii", Text = "Unmute to continue.", Duration = 5})

repeat task.wait(2) until geticonlabel().Image ~= mutedimage

voicechatservice:leaveVoice()
task.wait(2)

local connections = getconnectionsfunc(voicechatinternal.StateChanged)
for i = 7, #connections do 
    if connections[i] then connections[i]:Disable() end
end

task.wait(2)
voicechatservice:joinVoice()

pcall(function()
    unibarcontainer = getunibarcontainer()
    micmutebutton = unibarcontainer and unibarcontainer:WaitForChild("toggle_mic_mute", 15) or findmicbutton()
end)

if micmutebutton and unibarcontainer then
    local clonedmutebutton = micmutebutton:Clone()
    micmutebutton.Parent = hiddenfolder
    clonedmutebutton.Name = "toggle_mic_mute_new"
    clonedmutebutton.Parent = unibarcontainer

    local clonedicon = geticonlabel(clonedmutebutton)
    local originalicon = geticonlabel(micmutebutton)

    setmutestate(true)
    clonedmutebutton:WaitForChild("IconHitArea_toggle_mic_mute", 15).Activated:Connect(function()
        ismuted = not ismuted
        setmutestate(ismuted)
        if ismuted then
            clonedicon.Image = mutedimage
        else
            clonedicon.Image = originalicon.Image
        end
    end)
end

local contentprovider = game:GetService("ContentProvider")
local runservice = game:GetService("RunService")
local mutediconimage = mutedimage
local unmutediconimage = "rbxasset://textures/ui/VoiceChat/MicLight/Unmuted.png"
do
    local ok, currentimage = pcall(function() return geticonlabel(micmutebutton).Image end)
    if ok and currentimage and currentimage ~= "" then
        unmutediconimage = currentimage
    end
end

local function getvoicebubbleinsert(player)
    local ok, insert = pcall(function()
        local bubbles = coregui:FindFirstChild("bubbleChat", true)
        if not bubbles then
            local experiencechat = coregui:FindFirstChild("ExperienceChat", true)
            bubbles = experiencechat and experiencechat:FindFirstChild("bubbleChat", true)
        end
        local bubble = bubbles and bubbles:FindFirstChild("BubbleChat_" .. player.UserId, true)
        local voicebubble = bubble and bubble:FindFirstChild("VoiceBubble", true)
        return voicebubble and voicebubble:FindFirstChild("Insert", true)
    end)
    if ok then return insert end
    return nil
end

local function assettoloads(url)
    return pcall(function() contentprovider:PreloadAsync({ url }) end)
end

local talkingimages = {}
do
    local templateimage
    local insert = getvoicebubbleinsert(localplayer)
    if insert then
        local ok, image = pcall(function() return insert.Image end)
        if ok and type(image) == "string" then templateimage = image end
    end
    local prefixes = { "rbxasset://textures/ui/VoiceChat/MicLight/" }
    local base = templateimage and templateimage:match("^(.-)Unmuted%d+%.png$")
    if base then table.insert(prefixes, 1, base) end
    for _, prefix in ipairs(prefixes) do
        for _, step in ipairs({ "0", "20", "40", "60", "80", "100" }) do
            local url = prefix .. "Unmuted" .. step .. ".png"
            if assettoloads(url) then table.insert(talkingimages, url) end
        end
    end
    if #talkingimages == 0 then
        if templateimage and assettoloads(templateimage) then
            table.insert(talkingimages, templateimage)
        else
            table.insert(talkingimages, unmutediconimage)
        end
    end
end

local muteentries = {}
local muteconnections = {}

local scannedinputs

local function getvoiceinput(player)
    if not player then return nil end
    local input = player:FindFirstChildWhichIsA("AudioDeviceInput", true)
    if input then return input end
    input = player:FindFirstChild("AudioDeviceInput", true)
    if input then return input end
    if scannedinputs == nil then
        scannedinputs = {}
        for _, instance in ipairs(workspace:GetDescendants()) do
            if instance:IsA("AudioDeviceInput") then
                local ownerok, owner = pcall(function() return instance.Player end)
                if ownerok and owner and not scannedinputs[owner] then scannedinputs[owner] = instance end
            end
        end
    end
    return scannedinputs[player]
end

local function getvoiceemitter(player)
    local character = player and player.Character
    if character then
        local emitter = character:FindFirstChildWhichIsA("AudioEmitter", true)
        if emitter then return emitter end
    end
    return player and player:FindFirstChildWhichIsA("AudioEmitter", true)
end

local function resolveemitter(entry)
    local character = entry.player and entry.player.Character
    if entry.emitter and entry.emittercharacter == character then return entry.emitter end
    entry.emittercharacter = character
    entry.emitter = getvoiceemitter(entry.player)
    entry.basecurve = nil
    entry.basemode = nil
    return entry.emitter
end

local function applymute(entry, muted)
    entry.muted = muted
    local input = entry.input or getvoiceinput(entry.player)
    entry.input = input
    if input then
        pcall(function() input.Muted = muted end)
        if entry.baseinputvolume == nil then
            local volumeok, volume = pcall(function() return input.Volume end)
            entry.baseinputvolume = volumeok and type(volume) == "number" and volume or 1
        end
        pcall(function() input.Volume = muted and 0 or entry.baseinputvolume end)
    end
    local emitter = resolveemitter(entry)
    if not emitter then return end
    if entry.basecurve == nil then
        local curveok, curve = pcall(function() return emitter:GetDistanceAttenuation() end)
        entry.basecurve = curveok and type(curve) == "table" and curve or false
    end
    if entry.basemode == nil then
        local modeok, mode = pcall(function() return emitter.DistanceAttenuationMode end)
        entry.basemode = modeok and mode or Enum.DistanceAttenuationMode.Custom
    end
    if muted then
        pcall(function()
            emitter.DistanceAttenuationMode = Enum.DistanceAttenuationMode.Custom
            emitter:SetDistanceAttenuation({ [0] = 0 })
        end)
    else
        pcall(function()
            emitter.DistanceAttenuationMode = entry.basemode
            if type(entry.basecurve) == "table" and next(entry.basecurve) ~= nil then
                emitter:SetDistanceAttenuation(entry.basecurve)
            end
        end)
    end
end

local function detectspeaking(entry)
    if entry.input and not entry.analyzer and not entry.analyzertried then
        entry.analyzertried = true
        local ok, analyzer = pcall(function()
            local analyzer = Instance.new("AudioAnalyzer")
            analyzer.Name = "VoiceAnalyzer"
            analyzer.Parent = entry.player
            local wire = Instance.new("Wire")
            wire.SourceInstance = entry.input
            wire.TargetInstance = analyzer
            wire.Parent = analyzer
            return analyzer
        end)
        if ok then entry.analyzer = analyzer end
    end
    if entry.analyzer then
        local rmsok, rms = pcall(function() return entry.analyzer.RmsLevel end)
        if rmsok and type(rms) == "number" then return rms > 0.02 end
        local peakok, peak = pcall(function() return entry.analyzer.PeakLevel end)
        if peakok and type(peak) == "number" then return peak > 0.02 end
        pcall(function() entry.analyzer:Destroy() end)
        entry.analyzer = nil
    end
    if not entry.voicebubble then
        entry.voicebubble = getvoicebubbleinsert(entry.player)
        entry.lastoffset = nil
    end
    if entry.voicebubble then
        local ok, offset = pcall(function() return entry.voicebubble.ImageRectOffset end)
        if ok and offset then
            if entry.lastoffset ~= nil and offset ~= entry.lastoffset then return true end
            entry.lastoffset = offset
        end
    end
    return false
end

local function refreshbadge(entry)
    local muted = entry.muted == true
    local speaking = entry.speaking == true
    if entry.icon then
        if muted then
            entry.icon.Image = mutediconimage
            entry.icon.ImageColor3 = Color3.fromRGB(255, 90, 90)
        elseif speaking then
            entry.icon.Image = talkingimages[entry.frameindex or 1] or unmutediconimage
            entry.icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        else
            entry.icon.Image = unmutediconimage
            entry.icon.ImageColor3 = Color3.fromRGB(235, 240, 255)
        end
    end
    if entry.circle then
        if muted then
            entry.circle.BackgroundColor3 = Color3.fromRGB(120, 35, 45)
            entry.circle.BackgroundTransparency = 0.25
        elseif speaking then
            entry.circle.BackgroundColor3 = Color3.fromRGB(35, 110, 60)
            entry.circle.BackgroundTransparency = 0.3
        else
            entry.circle.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
            entry.circle.BackgroundTransparency = 0.35
        end
    end
end

local function gethead(player)
    local character = player and player.Character
    local head = character and character:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head end
    return nil
end

local function destroybadge(entry)
    if entry.badge then pcall(function() entry.badge:Destroy() end) end
    entry.badge = nil
    entry.circle = nil
    entry.icon = nil
    entry.name = nil
end

local function createbadge(entry)
    local head = gethead(entry.player)
    if not head then return end
    destroybadge(entry)

    local badge = Instance.new("BillboardGui")
    badge.Name = "VoiceMuteBadge"
    badge.Adornee = head
    badge.StudsOffset = Vector3.new(0, 2.2, 0)
    badge.Size = UDim2.fromOffset(70, 44)
    badge.MaxDistance = 30
    badge.AlwaysOnTop = true
    badge.LightInfluence = 0
    badge.Parent = head
    entry.badge = badge

    local circle = Instance.new("TextButton")
    circle.Name = "Toggle"
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.Position = UDim2.new(0.5, 0, 0, 16)
    circle.Size = UDim2.fromOffset(32, 32)
    circle.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
    circle.BackgroundTransparency = 0.35
    circle.BorderSizePixel = 0
    circle.Text = ""
    circle.AutoButtonColor = false
    circle.Parent = badge
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(220, 230, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = circle
    entry.circle = circle

    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Position = UDim2.fromOffset(4, 4)
    icon.Size = UDim2.fromOffset(24, 24)
    icon.BackgroundTransparency = 1
    icon.Image = unmutediconimage
    icon.ImageColor3 = Color3.fromRGB(235, 240, 255)
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = circle
    entry.icon = icon

    local name = Instance.new("TextLabel")
    name.Name = "Name"
    name.Position = UDim2.new(0, -25, 0, 36)
    name.Size = UDim2.fromOffset(120, 14)
    name.BackgroundTransparency = 1
    name.Font = Enum.Font.Gotham
    name.TextSize = 12
    name.TextColor3 = Color3.fromRGB(240, 244, 255)
    name.TextStrokeColor3 = Color3.fromRGB(10, 10, 15)
    name.TextStrokeTransparency = 0.4
    name.Text = entry.player.DisplayName
    name.Parent = badge
    entry.name = name

    circle.Activated:Connect(function()
        applymute(entry, not entry.muted)
        refreshbadge(entry)
    end)

    refreshbadge(entry)
end

local function addplayer(player)
    if player == localplayer then return end
    if muteentries[player] then return end

    local entry = {
        player = player,
        userid = player.UserId,
        muted = false,
        speaking = false,
        frameindex = 1,
        framedirection = 1,
        framewait = 0,
    }
    muteentries[player] = entry

    local characterconnection = player.CharacterAdded:Connect(function()
        task.wait(0.5)
        if muteentries[player] == entry then createbadge(entry) end
    end)
    local nameconnection = player:GetPropertyChangedSignal("DisplayName"):Connect(function()
        if entry.name then entry.name.Text = player.DisplayName end
    end)
    muteconnections[player] = { character = characterconnection, name = nameconnection }

    createbadge(entry)
    applymute(entry, entry.muted)
end

local function removeplayer(player)
    local entry = muteentries[player]
    if not entry then return end
    muteentries[player] = nil
    if entry.analyzer then pcall(function() entry.analyzer:Destroy() end) end
    destroybadge(entry)
    local connections = muteconnections[player]
    if connections then
        connections.character:Disconnect()
        connections.name:Disconnect()
        muteconnections[player] = nil
    end
end

local function animatetalking(dt)
    for _, entry in pairs(muteentries) do
        if entry.speaking and not entry.muted and #talkingimages > 1 then
            entry.framewait = entry.framewait + dt
            if entry.framewait >= 0.07 then
                entry.framewait = 0
                entry.frameindex = entry.frameindex + entry.framedirection
                if entry.frameindex > #talkingimages then
                    entry.frameindex = #talkingimages - 1
                    entry.framedirection = -1
                elseif entry.frameindex < 1 then
                    entry.frameindex = 2
                    entry.framedirection = 1
                end
                if entry.icon then entry.icon.Image = talkingimages[entry.frameindex] end
            end
        end
    end
end

do
    local oldgui = localplayer:FindFirstChildOfClass("PlayerGui") and localplayer.PlayerGui:FindFirstChild("VoiceMuteList")
    if oldgui then oldgui:Destroy() end
    for _, instance in ipairs(workspace:GetDescendants()) do
        if instance:IsA("BillboardGui") and instance.Name == "VoiceMuteBadge" then
            instance:Destroy()
        end
    end
end

for _, player in ipairs(players:GetPlayers()) do
    addplayer(player)
end
players.PlayerAdded:Connect(addplayer)
players.PlayerRemoving:Connect(removeplayer)

runservice.RenderStepped:Connect(function(dt)
    animatetalking(math.min(dt, 0.1))
end)

task.spawn(function()
    while true do
        for _, entry in pairs(muteentries) do
            if not entry.input then entry.input = getvoiceinput(entry.player) end
            if not entry.badge then createbadge(entry) end
            if entry.muted then applymute(entry, true) end
            local speaking = detectspeaking(entry)
            if speaking ~= entry.speaking then
                entry.speaking = speaking
                entry.frameindex = 1
                entry.framedirection = 1
                refreshbadge(entry)
            end
        end
        task.wait(0.1)
    end
end)
