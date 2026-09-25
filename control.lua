local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- ============================================================
-- BASE PLATE / MAP SETUP
-- ============================================================

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local SIZE = 40000
local THICKNESS = 10
local PART_SIZE = 2048
local GRID = math.ceil(SIZE / PART_SIZE)

local DECAL_SIZE = 300

local BASE_CFRAME = CFrame.new(8, -10, -482.000031, 1, 0, 0, 0, 1, 0, 0, 0, 1)
local BASE_POS = BASE_CFRAME.Position
local BASE_Y = BASE_POS.Y
local BASE_HEIGHT_OFFSET = THICKNESS / 2

local old = Workspace:FindFirstChild("Baseplate")
if old then
	old:Destroy()
end

for _, obj in ipairs(Workspace:GetChildren()) do
	if obj:IsA("BasePart") and (obj.Name:match("^BaseplateSection_") or obj.Name == "CenterDecalPart") then
		obj:Destroy()
	end
end

local mapFolder = Workspace:FindFirstChild("Map") or Workspace:FindFirstChild("map")
if mapFolder then
	local middleFolder = mapFolder:FindFirstChild("Middle") or mapFolder:FindFirstChild("middle")
	if middleFolder then
		for _, child in ipairs(middleFolder:GetChildren()) do
			child:Destroy()
		end
		print("Cleared Workspace.Map.Middle")
	end

	local extraRoom = mapFolder:FindFirstChild("extra_room")
	if extraRoom then
		for _, child in ipairs(extraRoom:GetChildren()) do
			child:Destroy()
		end
		print("Cleared Workspace.map.extra_room")
	end
end

for x = 0, GRID - 1 do
	for z = 0, GRID - 1 do
		local part = Instance.new("Part")
		part.Name = "BaseplateSection_" .. x .. "_" .. z
		part.Size = Vector3.new(PART_SIZE, THICKNESS, PART_SIZE)

		local posX = BASE_POS.X + (x * PART_SIZE) - (SIZE / 2) + (PART_SIZE / 2)
		local posZ = BASE_POS.Z + (z * PART_SIZE) - (SIZE / 2) + (PART_SIZE / 2)
		local posY = BASE_Y + BASE_HEIGHT_OFFSET

		part.CFrame = CFrame.new(posX, posY, posZ) * BASE_CFRAME.Rotation
		part.Anchored = true
		part.CanCollide = true
		part.Material = Enum.Material.Asphalt
		part.Color = Color3.new(0, 0, 0)
		part.Parent = Workspace
	end
end

print("Loaded Baseplate " .. (GRID * GRID) .. " parts")

local centerPart = Instance.new("Part")
centerPart.Name = "CenterDecalPart"
centerPart.Size = Vector3.new(PART_SIZE, THICKNESS, PART_SIZE)
centerPart.CFrame = CFrame.new(BASE_POS.X, BASE_Y + BASE_HEIGHT_OFFSET, BASE_POS.Z) * BASE_CFRAME.Rotation
centerPart.Anchored = true
centerPart.CanCollide = true
centerPart.Material = Enum.Material.Asphalt
centerPart.Color = Color3.new(0, 0, 0)
centerPart.Parent = Workspace

local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "DecalGui"
surfaceGui.Face = Enum.NormalId.Top
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfaceGui.PixelsPerStud = 1
surfaceGui.CanvasSize = Vector2.new(PART_SIZE, PART_SIZE)
surfaceGui.AlwaysOnTop = false
surfaceGui.Parent = centerPart

local imageLabel = Instance.new("ImageLabel")
imageLabel.Name = "DecalImage"
imageLabel.Image = ""
imageLabel.Size = UDim2.new(0, DECAL_SIZE, 0, DECAL_SIZE)
imageLabel.Position = UDim2.new(0.5, -DECAL_SIZE / 2, 0.5, -DECAL_SIZE / 2)
imageLabel.BackgroundTransparency = 1
imageLabel.Parent = surfaceGui

print("Loaded " .. DECAL_SIZE .. " × " .. DECAL_SIZE .. " studs")

-- ============================================================
-- EMOTE / CHAT SCRIPT
-- ============================================================

local env = (getgenv and getgenv()) or _G

if env.__fScriptConn then
	pcall(function() env.__fScriptConn:Disconnect() end)
	env.__fScriptConn = nil
end

if env.__fFollowConn then
	pcall(function() env.__fFollowConn:Disconnect() end)
	env.__fFollowConn = nil
end

if env.__fScriptEnabled == nil then
	env.__fScriptEnabled = true
end

local localPlayer = Players.LocalPlayer
local EMOTE_ID = 104327975123706
local EMOTE_NAME = "kawaii pleading beg kitty sitting idle"

local TELEPORT_COOLDOWN = 1

-- Offset relative to the holder's root.
-- X = left/right, Y = up/down, Z = forward/back.
-- (0, -1, -2) = 1 stud down (towards waist), 2 studs forward.
-- Same orientation as holder -> our back is to them.
local HOLD_OFFSET = CFrame.new(0, -1, -2)

local lastTeleport = 0

local function getRootPart(player)
	local character = player.Character
	if not character then
		character = player.CharacterAdded:Wait()
	end
	return character:WaitForChild("HumanoidRootPart")
end

-- ===== EMOTE =====
-- Loads the emote via the Animator at the highest priority so nothing
-- else can override it, and loops it.
local function playEmoteOn(humanoid)
	if not humanoid then return nil end
	if humanoid.RigType == Enum.HumanoidRigType.R6 then return nil end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. tostring(EMOTE_ID)

	local track
	local ok = pcall(function()
		track = animator:LoadAnimation(animation)
	end)

	if not ok or not track then
		return nil
	end

	pcall(function()
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action4
		track:Play(0.1, 1, 1)
	end)

	return track
end

-- Disabling the default Animate LocalScript is what actually stops
-- run/walk/jump/fall/idle from appearing. Stopping tracks alone is not
-- enough because Animate just replays them every state change.
local function freezeAnimateScript(character, disable)
	if not character then return end
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("BaseScript") then
		pcall(function()
			animate.Disabled = disable
		end)
	end
end

local function playEmote()
	local character = localPlayer.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	playEmoteOn(humanoid)
end

-- ===== .f : we tp in front of them, we face them, they face us =====
local function teleportTo(targetPlayer)
	if targetPlayer == localPlayer then return end

	local now = tick()
	if now - lastTeleport < TELEPORT_COOLDOWN then
		return
	end
	lastTeleport = now

	local myCharacter = localPlayer.Character
	if not myCharacter then return end

	local targetRoot = getRootPart(targetPlayer)
	if not targetRoot then return end

	local targetPos = targetRoot.Position
	local myPos = targetPos + targetRoot.CFrame.LookVector * 3
	local faceCFrame = CFrame.lookAt(myPos, targetPos)
	myCharacter:PivotTo(faceCFrame)

	task.wait(0.1)

	local theirCharacter = targetPlayer.Character
	if theirCharacter then
		local theirRoot = theirCharacter:FindFirstChild("HumanoidRootPart")
		local myRoot = myCharacter:FindFirstChild("HumanoidRootPart")
		if theirRoot and myRoot then
			local lookCFrame = CFrame.lookAt(theirRoot.Position, myRoot.Position)
			pcall(function()
				theirCharacter:PivotTo(lookCFrame)
			end)
		end
	end

	task.wait(0.15)
	playEmote()
end

-- ===== .h : we tp to them, latch onto their waist, back to them =====
local holdTarget = nil
local holdTrack = nil
local savedWalkSpeed = nil
local savedJumpPower = nil
local savedJumpHeight = nil
local savedUseJumpPower = nil

local function isOurEmote(track)
	return track ~= nil and track == holdTrack
end

local function stopOtherAnimations(humanoid)
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	local ok, tracks = pcall(function()
		return animator:GetPlayingAnimationTracks()
	end)
	if not ok or not tracks then return end
	for _, t in ipairs(tracks) do
		if not isOurEmote(t) then
			pcall(function() t:Stop(0) end)
		end
	end
end

local function applyMovementLock(humanoid)
	if not humanoid then return end
	if savedWalkSpeed == nil then
		savedWalkSpeed = humanoid.WalkSpeed
		savedJumpPower = humanoid.JumpPower
		savedJumpHeight = humanoid.JumpHeight
		savedUseJumpPower = humanoid.UseJumpPower
	end
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
end

local function restoreMovement(humanoid)
	if not humanoid then return end
	if savedWalkSpeed ~= nil then
		humanoid.WalkSpeed = savedWalkSpeed
		humanoid.JumpPower = savedJumpPower
		humanoid.JumpHeight = savedJumpHeight
		if savedUseJumpPower ~= nil then
			humanoid.UseJumpPower = savedUseJumpPower
		end
	end
	savedWalkSpeed = nil
	savedJumpPower = nil
	savedJumpHeight = nil
	savedUseJumpPower = nil
end

local function stopHold()
	if holdTarget == nil then return end
	holdTarget = nil

	local myCharacter = localPlayer.Character
	local myHumanoid = myCharacter and myCharacter:FindFirstChildOfClass("Humanoid")
	if myHumanoid then
		restoreMovement(myHumanoid)
	end

	-- Re-enable the default Animate script so normal animations resume
	freezeAnimateScript(myCharacter, false)

	if holdTrack then
		pcall(function() holdTrack:Stop(0) end)
		holdTrack = nil
	end
end

local function startHold(holderPlayer)
	if holderPlayer == localPlayer then return end
	if holderPlayer.Parent ~= Players then return end

	stopHold()
	holdTarget = holderPlayer

	local myCharacter = localPlayer.Character
	if not myCharacter then return end

	-- Immediate snap so we don't wait a frame
	local holderCharacter = holderPlayer.Character
	local holderRoot = holderCharacter and holderCharacter:FindFirstChild("HumanoidRootPart")
	if holderRoot then
		pcall(function()
			myCharacter:PivotTo(holderRoot.CFrame * HOLD_OFFSET)
		end)
	end

	local myHumanoid = myCharacter:FindFirstChildOfClass("Humanoid")
	if myHumanoid then
		applyMovementLock(myHumanoid)
		freezeAnimateScript(myCharacter, true)  -- kill default walk/run/idle/jump/fall
		holdTrack = playEmoteOn(myHumanoid)      -- same emote path as .f
		stopOtherAnimations(myHumanoid)
	end
end

env.__fFollowConn = RunService.Heartbeat:Connect(function()
	if not holdTarget then return end

	if holdTarget.Parent ~= Players then
		stopHold()
		return
	end

	local holderCharacter = holdTarget.Character
	local holderRoot = holderCharacter and holderCharacter:FindFirstChild("HumanoidRootPart")
	local myCharacter = localPlayer.Character
	local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")

	if not holderRoot or not myCharacter or not myRoot then return end

	-- Stick to holder's waist, same orientation (our back to them)
	local targetCFrame = holderRoot.CFrame * HOLD_OFFSET
	pcall(function()
		myCharacter:PivotTo(targetCFrame)
	end)

	local myHumanoid = myCharacter:FindFirstChildOfClass("Humanoid")
	if myHumanoid then
		applyMovementLock(myHumanoid)
		freezeAnimateScript(myCharacter, true)

		-- Keep the emote alive (replay if it somehow stops)
		local playing = false
		if holdTrack then
			pcall(function() playing = holdTrack.IsPlaying end)
		end
		if not playing then
			if holdTrack then
				pcall(function() holdTrack:Stop(0) end)
			end
			holdTrack = playEmoteOn(myHumanoid)
		end

		-- Belt-and-suspenders: stop anything that isn't our emote
		stopOtherAnimations(myHumanoid)
	end
end)

local connection = TextChatService.MessageReceived:Connect(function(message)
	local sender = message.TextSource
	if not sender then return end

	local senderId = sender.UserId
	if not senderId then return end

	local text = message.Text:lower()

	-- Self commands (silent)
	if senderId == localPlayer.UserId then
		if text == ".disable" then
			env.__fScriptEnabled = false
		elseif text == ".enable" then
			env.__fScriptEnabled = true
		elseif text == ".h" then
			-- We (the held one) type .h -> release
			stopHold()
		end
		return
	end

	if not env.__fScriptEnabled then return end

	local targetPlayer = Players:GetPlayerByUserId(senderId)
	if not targetPlayer then return end

	if text == ".f" then
		teleportTo(targetPlayer)
	elseif text == ".h" then
		-- If the person typing .h is the one currently holding us -> release
		if holdTarget ~= nil and targetPlayer == holdTarget then
			stopHold()
		else
			startHold(targetPlayer)
		end
	end
end)

env.__fScriptConn = connection
