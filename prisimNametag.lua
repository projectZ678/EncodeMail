-- Prism Nametag System
-- Standalone module for custom nametags with animations and API sync

local PrismNametags = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Dependencies
local PM = getgenv().PrismMain

-- Color constants (will be overridden by PM.C if available)
local C = PM and PM.C or {
    bg = Color3.fromRGB(15, 15, 15),
    card = Color3.fromRGB(28, 28, 28),
    accent = Color3.fromRGB(180, 180, 180),
    text = Color3.fromRGB(230, 230, 230),
    textDim = Color3.fromRGB(90, 90, 90),
    border = Color3.fromRGB(45, 45, 45),
    sep = Color3.fromRGB(60, 60, 70),
}

-- Utility functions
local function mk(class, parent, props)
    local i = Instance.new(class)
    i.Parent = parent
    for k, v in pairs(props or {}) do i[k] = v end
    return i
end

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
    return c
end

local function stroke(p, c, t, trans)
    local s = Instance.new("UIStroke")
    s.Color = c or Color3.fromRGB(40, 40, 40)
    s.Thickness = t or 1
    s.Transparency = trans or 0
    s.Parent = p
    return s
end

local function tween(obj, time, props, style)
    return TweenService:Create(obj, TweenInfo.new(time or 0.3, style or Enum.EasingStyle.Quad), props):Play()
end

-- File download system
local httprequest = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
local waxgetcustomasset = getcustomasset or getsynasset

-- File registry
PrismNametags.FileRegistry = {
    nametags = {
        kavrenoo = {
            url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/kavrenoo.png",
            path = "prism/nametags/kavrenoo.png"
        },
        kavrenoo_frame0 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_0.png", path = "prism/nametags/Kavrenoo/frame_0.png"},
        kavrenoo_frame1 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_1.png", path = "prism/nametags/Kavrenoo/frame_1.png"},
        kavrenoo_frame2 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_2.png", path = "prism/nametags/Kavrenoo/frame_2.png"},
        kavrenoo_frame3 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_3.png", path = "prism/nametags/Kavrenoo/frame_3.png"},
        kavrenoo_frame4 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_4.png", path = "prism/nametags/Kavrenoo/frame_4.png"},
        kavrenoo_frame5 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_5.png", path = "prism/nametags/Kavrenoo/frame_5.png"},
        kavrenoo_frame6 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_6.png", path = "prism/nametags/Kavrenoo/frame_6.png"},
        kavrenoo_frame7 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_7.png", path = "prism/nametags/Kavrenoo/frame_7.png"},
        kavrenoo_frame8 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_8.png", path = "prism/nametags/Kavrenoo/frame_8.png"},
        kavrenoo_frame9 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_9.png", path = "prism/nametags/Kavrenoo/frame_9.png"},
        kavrenoo_frame10 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_10.png", path = "prism/nametags/Kavrenoo/frame_10.png"},
        kavrenoo_frame11 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_11.png", path = "prism/nametags/Kavrenoo/frame_11.png"},
        kavrenoo_frame12 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_12.png", path = "prism/nametags/Kavrenoo/frame_12.png"},
        kavrenoo_frame13 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_13.png", path = "prism/nametags/Kavrenoo/frame_13.png"},
        kavrenoo_frame14 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_14.png", path = "prism/nametags/Kavrenoo/frame_14.png"},
        kavrenoo_frame15 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_15.png", path = "prism/nametags/Kavrenoo/frame_15.png"},
        kavrenoo_frame16 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_16.png", path = "prism/nametags/Kavrenoo/frame_16.png"},
        kavrenoo_frame17 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_17.png", path = "prism/nametags/Kavrenoo/frame_17.png"},
        kavrenoo_frame18 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_18.png", path = "prism/nametags/Kavrenoo/frame_18.png"},
        kavrenoo_frame19 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_19.png", path = "prism/nametags/Kavrenoo/frame_19.png"},
        kavrenoo_frame20 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_20.png", path = "prism/nametags/Kavrenoo/frame_20.png"},
        kavrenoo_frame21 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_21.png", path = "prism/nametags/Kavrenoo/frame_21.png"},
        kavrenoo_frame22 = {url = "https://raw.githubusercontent.com/qrft/Prism-Public/main/nametags/Kavrenoo/frame_22.png", path = "prism/nametags/Kavrenoo/frame_22.png"},
    },
}

-- Nametag configuration
PrismNametags.NAMETAG_CONFIG = {
    kavrenoo = {
        userIds = {7275889224, 5712636024},
        imagePath = nil,
        borderColor = Color3.fromRGB(255, 255, 255),
        gradientColor = Color3.fromRGB(255, 255, 255),
        gradientSpinColor = Color3.fromRGB(245, 245, 245),
        typingText = "Owner",
        distanceLabel = "P",
        isAnimated = true,
        frameBasePath = "prism/nametags/Kavrenoo/frame_",
        frameCount = 23,
        frameTime = 0.1
    },
}

-- State
local nametagEnabled = true
local nametagGui = nil
local nametagConnection = nil
local otherNametags = {}
local autoSyncEnabled = true
local autoSyncInterval = 2
local originalDisplayTypes = {}
local typingEffectConnections = {}
local frameAnimationConnections = {}
local frameLabelsRegistry = {} -- Store frame labels separately
local API_ENDPOINT = "https://prismscript.vercel.app/api/prism"

-- Check if user has a custom nametag
local function getNametagConfig(userId)
    for personName, config in pairs(PrismNametags.NAMETAG_CONFIG) do
        for _, id in ipairs(config.userIds) do
            if id == userId then
                return config
            end
        end
    end
    return nil
end

-- File download functions
function PrismNametags.downloadFile(category, name)
    local file = PrismNametags.FileRegistry[category] and PrismNametags.FileRegistry[category][name]
    if not file then
        return false, "File not found in registry"
    end

    local success, imageData
    if httprequest then
        success, imageData = pcall(function()
            local response = httprequest({
                Url = file.url,
                Method = "GET",
                Headers = {
                    ["Content-Type"] = "application/octet-stream"
                }
            })
            return response.Body or response
        end)
    else
        success, imageData = pcall(function()
            return game:HttpGet(file.url)
        end)
    end

    if not success or not imageData or imageData == "" then
        return false, imageData
    end

    local folderPath = file.path:match("^(.-)/[^/]+$")
    if folderPath and makefolder and not isfolder(folderPath) then
        makefolder(folderPath)
    end

    local successWrite = pcall(function()
        writefile(file.path, imageData)
    end)

    if not successWrite then
        return false, "Failed to write file"
    end

    return true, file.path
end

function PrismNametags.downloadCategory(category)
    local categoryFiles = PrismNametags.FileRegistry[category]
    if not categoryFiles then
        return false, "Category not found"
    end

    local results = {}
    for name, file in pairs(categoryFiles) do
        local success, result = PrismNametags.downloadFile(category, name)
        results[name] = {success = success, result = result}
    end
    return true, results
end

function PrismNametags.loadAsset(category, name)
    local file = PrismNametags.FileRegistry[category] and PrismNametags.FileRegistry[category][name]
    if not file then
        return nil
    end

    if waxgetcustomasset then
        local success, result = pcall(function()
            return waxgetcustomasset(file.path)
        end)
        if success and result and result ~= "" then
            return result
        end
    end
    return nil
end

function PrismNametags.isDownloaded(category, name)
    local file = PrismNametags.FileRegistry[category] and PrismNametags.FileRegistry[category][name]
    if not file then
        return false
    end
    return isfile(file.path)
end

function PrismNametags.downloadAllFiles()
    for category, files in pairs(PrismNametags.FileRegistry) do
        for name, file in pairs(files) do
            task.spawn(function()
                local success, result = PrismNametags.downloadFile(category, name)
            end)
        end
    end
end

-- Typing effect system
local function startTypingEffect(textLabel, displayName, typingText)
    if typingEffectConnections[textLabel] then
        for _, connection in ipairs(typingEffectConnections[textLabel]) do
            connection:Disconnect()
        end
    end
    
    local connections = {}
    local targetText = displayName .. "  " .. (typingText or "Owner")
    local dotChar = "•"
    local visibleLength = 0
    local isHiding = false
    local showCursor = true
    local lastCursorToggle = tick()
    local lastUpdate = tick()
    local lastCycleStart = tick()
    local dotPosition = #displayName + 2
    
    local heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
        local now = tick()
        
        if now - lastCursorToggle >= 0.5 then
            showCursor = not showCursor
            lastCursorToggle = now
        end
        
        if now - lastCycleStart >= 5 then
            isHiding = true
            lastCycleStart = now
        end
        
        if now - lastUpdate >= 0.05 then
            if isHiding then
                if visibleLength > 0 then
                    visibleLength = visibleLength - 1
                else
                    isHiding = false
                end
            else
                if visibleLength < #targetText then
                    visibleLength = visibleLength + 1
                end
            end
            lastUpdate = now
        end
        
        local displayText = targetText:sub(1, visibleLength)
        local dotVisible = not isHiding and visibleLength >= dotPosition
        
        if dotVisible then
            local beforeDot = displayText:sub(1, dotPosition - 1)
            local afterDot = displayText:sub(dotPosition)
            displayText = beforeDot .. dotChar .. afterDot
        end
        
        local cursor = showCursor and "|" or ""
        textLabel.Text = displayText .. cursor
    end)
    
    table.insert(connections, heartbeatConnection)
    typingEffectConnections[textLabel] = connections
end

local function stopTypingEffect(textLabel)
    if typingEffectConnections[textLabel] then
        for _, connection in ipairs(typingEffectConnections[textLabel]) do
            connection:Disconnect()
        end
        typingEffectConnections[textLabel] = nil
    end
end

-- Frame animation system
local function startFrameAnimation(parentFrame, config)
    if not config.isAnimated or config.frameCount <= 1 then
        return
    end

    local frameLabels = {}
    local frameCount = config.frameCount or 1
    local frameBasePath = config.frameBasePath or ""

    for i = 0, frameCount - 1 do
        local framePath = frameBasePath .. i .. ".png"
        if isfile and isfile(framePath) then
            local frameAsset = waxgetcustomasset and waxgetcustomasset(framePath)
            if frameAsset then
                local frameLabel = Instance.new("ImageLabel")
                frameLabel.Name = "Frame_" .. i
                frameLabel.Size = UDim2.new(1, 0, 1, 0)
                frameLabel.Position = UDim2.new(0, 0, 0, 0)
                frameLabel.BackgroundTransparency = 1
                frameLabel.Image = frameAsset
                frameLabel.ImageTransparency = 0
                frameLabel.ScaleType = Enum.ScaleType.Stretch
                frameLabel.Visible = (i == 0)
                frameLabel.ZIndex = -1
                frameLabel.Parent = parentFrame

                local bgCorner = Instance.new("UICorner")
                bgCorner.CornerRadius = UDim.new(0, 8)
                bgCorner.Parent = frameLabel

                frameLabels[i] = frameLabel
            end
        end
    end

    if #frameLabels == 0 then
        return
    end

    -- Store frame labels in registry instead of on the frame itself
    frameLabelsRegistry[parentFrame] = frameLabels

    local currentFrame = 0
    local lastFrameUpdate = tick()
    local frameTime = config.frameTime or 0.1

    local heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
        local now = tick()

        if now - lastFrameUpdate >= frameTime then
            if frameLabels[currentFrame] then
                frameLabels[currentFrame].Visible = false
            end

            currentFrame = (currentFrame + 1) % frameCount
            lastFrameUpdate = now

            if frameLabels[currentFrame] then
                frameLabels[currentFrame].Visible = true
            end
        end
    end)

    frameAnimationConnections[parentFrame] = {heartbeatConnection}
end

local function stopFrameAnimation(parentFrame)
    if frameAnimationConnections[parentFrame] then
        for _, connection in ipairs(frameAnimationConnections[parentFrame]) do
            connection:Disconnect()
        end
        frameAnimationConnections[parentFrame] = nil
    end

    -- Clean up frame labels from registry
    local frameLabels = frameLabelsRegistry[parentFrame]
    if frameLabels then
        for _, frameLabel in pairs(frameLabels) do
            pcall(function() frameLabel:Destroy() end)
        end
        frameLabelsRegistry[parentFrame] = nil
    end

    -- Also clean up any remaining frame children
    for _, child in ipairs(parentFrame:GetChildren()) do
        if child.Name:sub(1, 6) == "Frame_" then
            pcall(function() child:Destroy() end)
        end
    end
end

-- Nametag functions
function PrismNametags.clearAllNametags()
    local player = Players.LocalPlayer
    local playerGui = player:FindFirstChild("PlayerGui")

    for textLabel, _ in pairs(typingEffectConnections) do
        stopTypingEffect(textLabel)
    end

    for imageLabel, _ in pairs(frameAnimationConnections) do
        stopFrameAnimation(imageLabel)
    end
    
    if playerGui then
        for _, child in ipairs(playerGui:GetChildren()) do
            if child.Name == "PrismNametag" then
                pcall(function() child:Destroy() end)
            end
        end
    end
    
    if playerGui then
        for _, child in ipairs(playerGui:GetChildren()) do
            if child.Name:sub(1, 13) == "PrismNametag_" then
                pcall(function() child:Destroy() end)
            end
        end
    end
    
    if player.Character then
        local head = player.Character:FindFirstChild("Head")
        if head then
            for _, child in ipairs(head:GetChildren()) do
                if child.Name == "PrismNametag" then
                    pcall(function() child:Destroy() end)
                end
            end
        end
    end
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                for _, child in ipairs(head:GetChildren()) do
                    if child.Name:sub(1, 13) == "PrismNametag_" then
                        pcall(function() child:Destroy() end)
                    end
                end
            end
        end
    end
    
    for userId, tagData in pairs(otherNametags) do
        if tagData.connection then
            tagData.connection:Disconnect()
        end
    end
    otherNametags = {}
    
    if nametagConnection then
        nametagConnection:Disconnect()
        nametagConnection = nil
    end
    nametagGui = nil
end

function PrismNametags.createNametag()
    local player = Players.LocalPlayer
    if not player.Character then return end
    
    local head = player.Character:FindFirstChild("Head")
    if not head then return end
    
    if nametagConnection then
        nametagConnection:Disconnect()
        nametagConnection = nil
    end
    
    if nametagGui then
        pcall(function() nametagGui:Destroy() end)
        nametagGui = nil
    end
    
    for _, child in ipairs(head:GetChildren()) do
        if child.Name == "PrismNametag" then
            pcall(function() child:Destroy() end)
        end
    end
    
    local userId = player.UserId
    local config = getNametagConfig(userId)
    local hasCustomTag = config ~= nil and (config.imagePath ~= nil or config.isAnimated == true)
    
    local userBgColor = nil
    local userBorderColor = config and config.borderColor or C.sep
    local userGradientColor = config and config.gradientColor or nil
    local userGradientSpinColor = config and config.gradientSpinColor or nil

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PrismNametag"
    billboard.Size = UDim2.new(0, 150, 0, 50)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 9999
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    billboard.ClipsDescendants = false
    billboard.ResetOnSpawn = false
    billboard.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local bgFrame = Instance.new("Frame")
    bgFrame.Name = "BgFrame"
    bgFrame.Size = UDim2.new(1, 4, 1, 4)
    bgFrame.Position = UDim2.new(0, -2, 0, -2)
    bgFrame.BackgroundColor3 = userBorderColor
    bgFrame.BackgroundTransparency = 0
    bgFrame.BorderSizePixel = 0
    bgFrame.Parent = billboard
    
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 10)
    bgCorner.Parent = bgFrame
    
    local bgGradient = Instance.new("UIGradient")
    if hasCustomTag and userGradientColor and userGradientSpinColor then
        bgGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, userGradientSpinColor),
            ColorSequenceKeypoint.new(0.25, userGradientColor),
            ColorSequenceKeypoint.new(0.5, userGradientSpinColor),
            ColorSequenceKeypoint.new(0.75, userGradientColor),
            ColorSequenceKeypoint.new(1, userGradientSpinColor),
        })
    else
        bgGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.25, C.sep),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 20, 20)),
            ColorSequenceKeypoint.new(0.75, C.sep),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
        })
    end
    bgGradient.Parent = bgFrame
    
    local frame = Instance.new("Frame")
    frame.Name = "TagFrame"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = userBgColor or C.card
    frame.BackgroundTransparency = (userBgColor and 1) or (hasCustomTag and config.isAnimated and 1) or 0.1
    frame.BorderSizePixel = 0
    frame.Parent = billboard

    if hasCustomTag then
        if config.isAnimated then
            startFrameAnimation(frame, config)
        elseif config.imagePath then
            if isfile and isfile(config.imagePath) then
                local customAsset = waxgetcustomasset and waxgetcustomasset(config.imagePath)
                if customAsset then
                    local bgImage = Instance.new("ImageLabel")
                    bgImage.Name = "BgImage"
                    bgImage.Size = UDim2.new(1, 0, 1, 0)
                    bgImage.Position = UDim2.new(0, 0, 0, 0)
                    bgImage.BackgroundTransparency = 1
                    bgImage.Image = customAsset
                    bgImage.ImageTransparency = 0
                    bgImage.ScaleType = Enum.ScaleType.Stretch
                    bgImage.ZIndex = -1
                    bgImage.Parent = frame

                    local bgCorner = Instance.new("UICorner")
                    bgCorner.CornerRadius = UDim.new(0, 8)
                    bgCorner.Parent = bgImage
                end
            end
        end
    end

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local displayNameLabel = Instance.new("TextLabel")
    displayNameLabel.Name = "DisplayName"
    displayNameLabel.Size = UDim2.new(1, -10, 0, 20)
    displayNameLabel.Position = UDim2.new(0, 5, 0, 5)
    displayNameLabel.BackgroundTransparency = 1
    displayNameLabel.Text = (hasCustomTag and config.typingText and config.typingText ~= "") and "" or player.DisplayName
    displayNameLabel.TextColor3 = C.text
    displayNameLabel.TextSize = 14
    displayNameLabel.Font = Enum.Font.GothamBold
    displayNameLabel.TextXAlignment = Enum.TextXAlignment.Center
    displayNameLabel.Parent = frame
    
    if hasCustomTag and config.typingText and config.typingText ~= "" then
        startTypingEffect(displayNameLabel, player.DisplayName, config.typingText)
    end
    
    local usernameLabel = Instance.new("TextLabel")
    usernameLabel.Name = "Username"
    usernameLabel.Size = UDim2.new(1, -10, 0, 16)
    usernameLabel.Position = UDim2.new(0, 5, 0, 25)
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Text = "@ " .. player.Name
    usernameLabel.TextColor3 = hasCustomTag and C.text or C.textDim
    usernameLabel.TextSize = 11
    usernameLabel.Font = Enum.Font.Gotham
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Center
    usernameLabel.Parent = frame
    
    local smallLabel = Instance.new("TextLabel")
    smallLabel.Name = "SmallLabel"
    smallLabel.Size = UDim2.new(1, 0, 1, 0)
    smallLabel.BackgroundTransparency = 1
    smallLabel.Text = hasCustomTag and config.distanceLabel or "P"
    smallLabel.TextColor3 = C.text
    smallLabel.TextSize = 20
    smallLabel.Font = Enum.Font.GothamBold
    smallLabel.TextXAlignment = Enum.TextXAlignment.Center
    smallLabel.TextYAlignment = Enum.TextYAlignment.Center
    smallLabel.Visible = false
    smallLabel.Parent = frame
    
    nametagConnection = RunService.Heartbeat:Connect(function(dt)
        if not billboard or not billboard.Parent then return end
        if bgGradient and bgGradient.Parent then
            bgGradient.Rotation = (bgGradient.Rotation + 120 * dt) % 360
        end
        
        local currentHead = player.Character and player.Character:FindFirstChild("Head")
        if currentHead then
            billboard.Adornee = currentHead
            billboard.Enabled = nametagEnabled
        else
            billboard.Enabled = false
        end
    end)
    
    nametagGui = billboard
end

function PrismNametags.removeNametag()
    if nametagGui then
        local displayNameLabel = nametagGui:FindFirstChild("TagFrame") and nametagGui.TagFrame:FindFirstChild("DisplayName")
        if displayNameLabel then
            stopTypingEffect(displayNameLabel)
        end

        local tagFrame = nametagGui:FindFirstChild("TagFrame")
        if tagFrame and frameAnimationConnections[tagFrame] then
            stopFrameAnimation(tagFrame)
        end

        if nametagGui.AnimationConnections then
            for _, connection in ipairs(nametagGui.AnimationConnections) do
                connection:Disconnect()
            end
            nametagGui.AnimationConnections = nil
        end
    end
    
    if nametagConnection then
        nametagConnection:Disconnect()
        nametagConnection = nil
    end
    if nametagGui then
        pcall(function() nametagGui:Destroy() end)
        nametagGui = nil
    end
end

function PrismNametags.hideDefaultNametag(plr)
    if not plr.Character then return end
    local humanoid = plr.Character:FindFirstChildWhichIsA("Humanoid")
    if humanoid then
        originalDisplayTypes[plr.UserId] = humanoid.DisplayDistanceType
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end
end

function PrismNametags.restoreDefaultNametag(plr)
    if not plr.Character then return end
    local humanoid = plr.Character:FindFirstChildWhichIsA("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = originalDisplayTypes[plr.UserId] or Enum.HumanoidDisplayDistanceType.Viewer
        originalDisplayTypes[plr.UserId] = nil
    end
end

function PrismNametags.toggle()
    nametagEnabled = not nametagEnabled
    if nametagEnabled then
        if nametagGui then
            nametagGui.Enabled = true
        else
            PrismNametags.createNametag()
        end
        for userId, tagData in pairs(otherNametags) do
            if tagData.gui then
                tagData.gui.Enabled = true
            end
        end
        PrismNametags.hideDefaultNametag(Players.LocalPlayer)
        for userId, tagData in pairs(otherNametags) do
            local plr = Players:GetPlayerByUserId(userId)
            if plr then
                PrismNametags.hideDefaultNametag(plr)
            end
        end
    else
        if nametagGui then
            nametagGui.Enabled = false
        end
        for userId, tagData in pairs(otherNametags) do
            if tagData.gui then
                tagData.gui.Enabled = false
            end
        end
        PrismNametags.restoreDefaultNametag(Players.LocalPlayer)
        for userId, tagData in pairs(otherNametags) do
            local plr = Players:GetPlayerByUserId(userId)
            if plr then
                PrismNametags.restoreDefaultNametag(plr)
            end
        end
    end
    return nametagEnabled
end

function PrismNametags.isEnabled()
    return nametagEnabled
end

-- API functions
local function readFromAPI()
    local requestFunction = request or (HttpService and HttpService.request) or http_request or (fluxus and fluxus.request)
    
    if not requestFunction then
        return nil
    end
    
    local requestTable = {
        Url = API_ENDPOINT,
        Method = "GET"
    }
    
    local success, result = pcall(function()
        return requestFunction(requestTable)
    end)
    
    if not success then
        return nil
    end
    
    local responseBody = result.Body or result.body or result
    
    if responseBody then
        local responseSuccess, responseData = pcall(function()
            return HttpService:JSONDecode(responseBody)
        end)
        
        if responseSuccess and responseData.success then
            return responseData.data
        end
    end
    
    return nil
end

local function getUserInfo()
    local player = Players.LocalPlayer
    if not player then
        return nil
    end
    
    local userId = player.UserId
    local username = player.Name
    local displayName = player.DisplayName or username
    local jobId = game.JobId
    local gameName = "Unknown"
    
    pcall(function()
        local success, result = pcall(function()
            return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        end)
        if success and result then
            gameName = result.Name or "Unknown"
        end
    end)
    
    return {
        username = username,
        displayName = displayName,
        userId = tostring(userId),
        jobid = jobId,
        gameName = gameName
    }
end

local function sendToAPI(userInfo)
    local requestFunction = request or (HttpService and HttpService.request) or http_request or (fluxus and fluxus.request)
    
    if not requestFunction then
        return false, "No HTTP function available"
    end
    
    local requestBody = HttpService:JSONEncode(userInfo)
    local requestTable = {
        Url = API_ENDPOINT,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = requestBody
    }
    
    local success, result = pcall(function()
        return requestFunction(requestTable)
    end)
    
    if not success then
        return false, result
    end
    
    local responseBody = result.Body or result.body or result
    
    if responseBody then
        local responseSuccess, responseData = pcall(function()
            return HttpService:JSONDecode(responseBody)
        end)
        
        if responseSuccess then
            if responseData.success then
                return true, responseData
            else
                return false, responseData.error
            end
        else
            return false, "Parse error"
        end
    else
        return false, "No response"
    end
end

local function deleteFromAPI(userId)
    local requestFunction = request or (HttpService and HttpService.request) or http_request or (fluxus and fluxus.request)
    
    if not requestFunction then
        return false, "No HTTP function available"
    end
    
    local requestBody = HttpService:JSONEncode({userId = tostring(userId)})
    local requestTable = {
        Url = API_ENDPOINT,
        Method = "DELETE",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = requestBody
    }
    
    local success, result = pcall(function()
        return requestFunction(requestTable)
    end)
    
    if not success then
        return false, result
    end
    
    local responseBody = result.Body or result.body or result
    
    if responseBody then
        local responseSuccess, responseData = pcall(function()
            return HttpService:JSONDecode(responseBody)
        end)
        
        if responseSuccess then
            if responseData.success then
                return true, responseData
            else
                return false, responseData.error
            end
        else
            return false, "Parse error"
        end
    else
        return false, "No response"
    end
end

function PrismNametags.updateOtherNametags()
    local data = readFromAPI()
    if not data or not data.users then return end
    
    local myUserId = Players.LocalPlayer.UserId
    
    local prismUsers = {}
    for _, user in ipairs(data.users) do
        if tostring(user.userId) ~= tostring(myUserId) then
            prismUsers[user.userId] = user
        end
    end
    
    for userId, userData in pairs(prismUsers) do
        local plrObj = Players:GetPlayerByUserId(tonumber(userId))
        if plrObj and not otherNametags[tonumber(userId)] then
            if plrObj.Character then
                PrismNametags.createOtherNametag(plrObj)
            else
                plrObj.CharacterAdded:Connect(function(char)
                    task.wait(0.5)
                    if prismUsers[userId] and not otherNametags[tonumber(userId)] then
                        PrismNametags.createOtherNametag(plrObj)
                    end
                end)
            end
        end
    end
    
    local currentPlayers = {}
    for _, plrObj in ipairs(Players:GetPlayers()) do
        currentPlayers[plrObj.UserId] = true
    end

    for userId, tagData in pairs(otherNametags) do
        if not currentPlayers[userId] then
            PrismNametags.removeOtherNametag(userId)
        end
    end
end

function PrismNametags.createOtherNametag(plrObj)
    if not plrObj.Character then return end
    
    local head = plrObj.Character:FindFirstChild("Head")
    if not head then return end
    
    if otherNametags[plrObj.UserId] then
        if otherNametags[plrObj.UserId].connection then
            otherNametags[plrObj.UserId].connection:Disconnect()
        end
        pcall(function() otherNametags[plrObj.UserId].gui:Destroy() end)
        otherNametags[plrObj.UserId] = nil
    end
    
    for _, child in ipairs(head:GetChildren()) do
        if child.Name == "PrismNametag_" .. plrObj.UserId then
            pcall(function() child:Destroy() end)
        end
    end
    
    local userId = plrObj.UserId
    local config = getNametagConfig(userId)
    
    local data = readFromAPI()
    local isInAPI = false
    if data and data.users then
        for _, user in ipairs(data.users) do
            if tostring(user.userId) == tostring(userId) then
                isInAPI = true
                break
            end
        end
    end
    
    local hasCustomTag = config ~= nil and isInAPI and (config.imagePath ~= nil or config.isAnimated == true)
    
    local userBgColor = nil
    local userBorderColor = config and config.borderColor or C.sep
    local userGradientColor = config and config.gradientColor or nil
    local userGradientSpinColor = config and config.gradientSpinColor or nil
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PrismNametag_" .. plrObj.UserId
    billboard.Size = UDim2.new(0, 150, 0, 50)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 9999
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    billboard.Active = true
    billboard.ClipsDescendants = false
    billboard.ResetOnSpawn = false
    billboard.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local bgFrame = Instance.new("Frame")
    bgFrame.Name = "BgFrame"
    bgFrame.Size = UDim2.new(1, 4, 1, 4)
    bgFrame.Position = UDim2.new(0, -2, 0, -2)
    bgFrame.BackgroundColor3 = userBorderColor
    bgFrame.BackgroundTransparency = 0
    bgFrame.BorderSizePixel = 0
    bgFrame.Parent = billboard
    
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 10)
    bgCorner.Parent = bgFrame
    
    local bgGradient = Instance.new("UIGradient")
    if hasCustomTag and userGradientColor and userGradientSpinColor then
        bgGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, userGradientSpinColor),
            ColorSequenceKeypoint.new(0.25, userGradientColor),
            ColorSequenceKeypoint.new(0.5, userGradientSpinColor),
            ColorSequenceKeypoint.new(0.75, userGradientColor),
            ColorSequenceKeypoint.new(1, userGradientSpinColor),
        })
    else
        bgGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.25, C.sep),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 20, 20)),
            ColorSequenceKeypoint.new(0.75, C.sep),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
        })
    end
    bgGradient.Parent = bgFrame
    
    local frame = Instance.new("Frame")
    frame.Name = "TagFrame"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = userBgColor or C.card
    frame.BackgroundTransparency = (userBgColor and 1) or (hasCustomTag and config.isAnimated and 1) or 0.1
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = billboard

    if hasCustomTag then
        if config.isAnimated then
            startFrameAnimation(frame, config)
        elseif config.imagePath then
            if isfile and isfile(config.imagePath) then
                local customAsset = waxgetcustomasset and waxgetcustomasset(config.imagePath)
                if customAsset then
                    local bgImage = Instance.new("ImageLabel")
                    bgImage.Name = "BgImage"
                    bgImage.Size = UDim2.new(1, 0, 1, 0)
                    bgImage.Position = UDim2.new(0, 0, 0, 0)
                    bgImage.BackgroundTransparency = 1
                    bgImage.Image = customAsset
                    bgImage.ImageTransparency = 0
                    bgImage.ScaleType = Enum.ScaleType.Stretch
                    bgImage.ZIndex = -1
                    bgImage.Parent = frame

                    local bgCorner = Instance.new("UICorner")
                    bgCorner.CornerRadius = UDim.new(0, 8)
                    bgCorner.Parent = bgImage
                end
            end
        end
    end

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local displayNameLabel = Instance.new("TextLabel")
    displayNameLabel.Name = "DisplayName"
    displayNameLabel.Size = UDim2.new(1, -10, 0, 20)
    displayNameLabel.Position = UDim2.new(0, 5, 0, 5)
    displayNameLabel.BackgroundTransparency = 1
    displayNameLabel.Text = (hasCustomTag and config.typingText and config.typingText ~= "") and "" or plrObj.DisplayName
    displayNameLabel.TextColor3 = C.text
    displayNameLabel.TextSize = 14
    displayNameLabel.Font = Enum.Font.GothamBold
    displayNameLabel.TextXAlignment = Enum.TextXAlignment.Center
    displayNameLabel.Parent = frame
    
    if hasCustomTag and config.typingText and config.typingText ~= "" then
        startTypingEffect(displayNameLabel, plrObj.DisplayName, config.typingText)
    end
    
    local usernameLabel = Instance.new("TextLabel")
    usernameLabel.Name = "Username"
    usernameLabel.Size = UDim2.new(1, -10, 0, 16)
    usernameLabel.Position = UDim2.new(0, 5, 0, 25)
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Text = "@ " .. plrObj.Name
    usernameLabel.TextColor3 = hasCustomTag and C.text or C.textDim
    usernameLabel.TextSize = 11
    usernameLabel.Font = Enum.Font.Gotham
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Center
    usernameLabel.Parent = frame
    
    local smallLabel = Instance.new("TextLabel")
    smallLabel.Name = "SmallLabel"
    smallLabel.Size = UDim2.new(1, 0, 1, 0)
    smallLabel.BackgroundTransparency = 1
    smallLabel.Text = hasCustomTag and config.distanceLabel or "P"
    smallLabel.TextColor3 = C.text
    smallLabel.TextSize = 20
    smallLabel.Font = Enum.Font.GothamBold
    smallLabel.TextXAlignment = Enum.TextXAlignment.Center
    smallLabel.TextYAlignment = Enum.TextYAlignment.Center
    smallLabel.Visible = false
    smallLabel.Parent = frame
    
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local myChar = Players.LocalPlayer.Character
            local targetChar = plrObj.Character
            if myChar and myChar:FindFirstChild("HumanoidRootPart") and targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
                local myHRP = myChar.HumanoidRootPart
                local targetHRP = targetChar.HumanoidRootPart
                local behind = targetHRP.CFrame * CFrame.new(0, 0, 3)
                myHRP.CFrame = CFrame.new(behind.Position, behind.Position + targetHRP.CFrame.LookVector)
            end
        end
    end)
    
    local connection = RunService.Heartbeat:Connect(function(dt)
        if not billboard or not billboard.Parent then return end
        if bgGradient and bgGradient.Parent then
            bgGradient.Rotation = (bgGradient.Rotation + 120 * dt) % 360
        end
        
        local targetHead = plrObj.Character and plrObj.Character:FindFirstChild("Head")
        if targetHead then
            billboard.Adornee = targetHead
            billboard.Enabled = nametagEnabled
        else
            billboard.Enabled = false
            return
        end
        
        local myChar = Players.LocalPlayer.Character
        local targetChar = plrObj.Character
        if myChar and myChar:FindFirstChild("HumanoidRootPart") and targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
            local myHRP = myChar.HumanoidRootPart
            local targetHRP = targetChar.HumanoidRootPart
            local dist = (myHRP.Position - targetHRP.Position).Magnitude
            local isFar = dist > 50
            
            displayNameLabel.Visible = not isFar
            usernameLabel.Visible = not isFar
            smallLabel.Visible = isFar
            
            if isFar then
                tween(billboard, 0.1, {Size = UDim2.new(0, 40, 0, 40)})
            else
                tween(billboard, 0.1, {Size = UDim2.new(0, 150, 0, 50)})
            end
        end
    end)
    
    otherNametags[plrObj.UserId] = {
        gui = billboard,
        connection = connection
    }
    
    if nametagEnabled then
        PrismNametags.hideDefaultNametag(plrObj)
    end
    
    plrObj.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if nametagEnabled then
            PrismNametags.hideDefaultNametag(plrObj)
        end
    end)
end

function PrismNametags.removeOtherNametag(userId)
    if otherNametags[userId] then
        if otherNametags[userId].gui then
            local displayNameLabel = otherNametags[userId].gui:FindFirstChild("TagFrame") and otherNametags[userId].gui.TagFrame:FindFirstChild("DisplayName")
            if displayNameLabel then
                stopTypingEffect(displayNameLabel)
            end

            local tagFrame = otherNametags[userId].gui:FindFirstChild("TagFrame")
            if tagFrame and frameAnimationConnections[tagFrame] then
                stopFrameAnimation(tagFrame)
            end
        end

        if otherNametags[userId].connection then
            otherNametags[userId].connection:Disconnect()
        end
        pcall(function() otherNametags[userId].gui:Destroy() end)
        otherNametags[userId] = nil
    end
    local plr = Players:GetPlayerByUserId(userId)
    if plr then
        PrismNametags.restoreDefaultNametag(plr)
    end
end

local function sendNametagData()
    local userInfo = getUserInfo()
    if not userInfo then
        return
    end
    
    local success, result = sendToAPI(userInfo)
    
    if success then
        PrismNametags.updateOtherNametags()
    end
end

local function startAutoSync()
    while autoSyncEnabled and RunService.Heartbeat:Wait() do
        task.wait(autoSyncInterval)
        if autoSyncEnabled then
            sendNametagData()
        end
    end
end

function PrismNametags.cleanup()
    for textLabel, _ in pairs(typingEffectConnections) do
        stopTypingEffect(textLabel)
    end

    for imageLabel, _ in pairs(frameAnimationConnections) do
        stopFrameAnimation(imageLabel)
    end

    autoSyncEnabled = false

    PrismNametags.restoreDefaultNametag(Players.LocalPlayer)
    for userId, tagData in pairs(otherNametags) do
        local plr = Players:GetPlayerByUserId(userId)
        if plr then
            PrismNametags.restoreDefaultNametag(plr)
        end
    end

    PrismNametags.clearAllNametags()

    if nametagConnection then
        nametagConnection:Disconnect()
        nametagConnection = nil
    end

    for userId, tagData in pairs(otherNametags) do
        if tagData.connection then
            tagData.connection:Disconnect()
        end
    end
    otherNametags = {}

    local player = Players.LocalPlayer
    if player then
        task.spawn(function()
            deleteFromAPI(player.UserId)
        end)
    end

    nametagGui = nil
    nametagEnabled = false
    originalDisplayTypes = {}
end

function PrismNametags.initialize()
    PrismNametags.clearAllNametags()
    local player = Players.LocalPlayer
    if player.Character then
        PrismNametags.createNametag()
        if nametagEnabled then
            PrismNametags.hideDefaultNametag(player)
        end
    end

    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if nametagGui and char:FindFirstChild("Head") then
            nametagGui.Adornee = char.Head
        elseif nametagEnabled then
            PrismNametags.createNametag()
        end
        if nametagEnabled then
            PrismNametags.hideDefaultNametag(player)
        end
        for userId, tagData in pairs(otherNametags) do
            local plrObj = Players:GetPlayerByUserId(userId)
            if plrObj and plrObj.Character and plrObj.Character:FindFirstChild("Head") then
                tagData.gui.Adornee = plrObj.Character.Head
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(leavingPlayer)
        PrismNametags.removeOtherNametag(leavingPlayer.UserId)
        task.spawn(function()
            local data = readFromAPI()
            if data and data.users then
                for _, user in ipairs(data.users) do
                    if tostring(user.userId) == tostring(leavingPlayer.UserId) then
                        deleteFromAPI(leavingPlayer.UserId)
                        break
                    end
                end
            end
        end)
    end)

    task.wait(1)
    PrismNametags.updateOtherNametags()

    task.spawn(function()
        while autoSyncEnabled do
            task.wait(2)
            pcall(function()
                local currentPlayers = {}
                for _, plrObj in ipairs(Players:GetPlayers()) do
                    currentPlayers[plrObj.UserId] = true
                end
                
                for userId, tagData in pairs(otherNametags) do
                    if not currentPlayers[userId] then
                        PrismNametags.removeOtherNametag(userId)
                    end
                end
            end)
        end
    end)

    sendNametagData()
    task.spawn(startAutoSync)
end

-- Auto-download all registered files
task.spawn(function()
    PrismNametags.downloadAllFiles()
end)

-- Initialize the nametag system when script runs
repeat task.wait() until Players.LocalPlayer
PrismNametags.initialize()

return PrismNametags
