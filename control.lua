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
local CHAT_COOLDOWN = 3

-- User IDs and their custom replies
local MOMMY_USER_ID = 8147002194        -- types .f/.i -> "yes mama?" (only if responder is 1733619112)
local RESPONDER_USER_ID = 1733619112    -- the only user whose script replies "yes mama?" AND the only user who can use .c
local DADA_USER_ID = 8051317045         -- types .f -> "im here dada"; types .i -> "geeg"

-- .h offset: at root level (waist), 2 studs forward (back to them)
local HOLD_OFFSET = CFrame.new(0, 0, -2)

-- .y config: fast back-and-forth straight in front of the holder.
local Y_BASE_Z = -1.5      -- centered 1.5 studs in front
local Y_AMPLITUDE = 0.6    -- swing ±0.6 studs (tight)
local Y_SPEED = 20         -- rad/sec (higher = faster)

local lastTeleport = 0
local lastChat = 0

local function sendChatMessage(text, force)
	local now = tick()
	if not force and now - lastChat < CHAT_COOLDOWN then
		return
	end
	lastChat = now

	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if channel then
			pcall(function()
				channel:SendAsync(text)
			end)
		end
	end
end

local function getRootPart(player)
	local character = player.Character
	if not character then
		character = player.CharacterAdded:Wait()
	end
	return character:WaitForChild("HumanoidRootPart")
end

-- Shared name resolver: exact username, then prefix on Name OR DisplayName.
local function findPlayerByName(name)
	if not name or name == "" then return nil end
	name = name:gsub("^@", ""):gsub("%s+$", "")
	if name == "" then return nil end

	-- Exact username
	local target = Players:FindFirstChild(name)
	if target then return target end

	local lower = name:lower()
	local len = #lower

	-- Prefix match on Name, then prefix match on DisplayName, then exact DisplayName
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1, len) == lower then
			return p
		end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p.DisplayName:lower():sub(1, len) == lower then
			return p
		end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p.DisplayName:lower() == lower then
			return p
		end
	end

	return nil
end

-- ===== EMOTE =====
local function playEmoteOn(humanoid)
	if not humanoid then return nil end
	if humanoid.RigType == Enum.HumanoidRigType.R6 then return nil end

	local track
	local ok = pcall(function()
		track = humanoid:PlayEmoteAndGetAnimTrackById(EMOTE_ID)
	end)

	if not ok or not track then
		local description = humanoid:FindFirstChildOfClass("HumanoidDescription")
		if not description then
			description = Instance.new("HumanoidDescription")
			description.Parent = humanoid
		end
		pcall(function()
			description:AddEmote(EMOTE_NAME, EMOTE_ID)
			track = humanoid:PlayEmoteAndGetAnimTrackById(EMOTE_ID)
		end)
	end

	if track then
		pcall(function()
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Action4
			track:Play()
		end)
	end

	return track
end

local function playEmote()
	local character = localPlayer.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	return playEmoteOn(humanoid)
end

local function freezeAnimateScript(character, disable)
	if not character then return end
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("BaseScript") then
		pcall(function()
			animate.Disabled = disable
		end)
	end
end

-- ============================================================
-- STATE
-- ============================================================

local holdTarget = nil
local holdTrack = nil
local holdMode = nil
local holdStartTick = 0
local savedWalkSpeed = nil
local savedJumpPower = nil
local savedJumpHeight = nil
local savedUseJumpPower = nil

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

-- ===== .f : tp in front, face each other, emote once, optional chat =====
local function teleportTo(targetPlayer, customMessage)
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

	if customMessage then
		sendChatMessage(customMessage, false)
	end
end

-- ===== .to <player> : tp in front, no emote, no chat =====
local function teleportToByName(name)
	local target = findPlayerByName(name)
	if not target or target == localPlayer then return end

	local now = tick()
	if now - lastTeleport < TELEPORT_COOLDOWN then
		return
	end
	lastTeleport = now

	local myCharacter = localPlayer.Character
	if not myCharacter then return end

	local targetRoot = getRootPart(target)
	if not targetRoot then return end

	local targetPos = targetRoot.Position
	local myPos = targetPos + targetRoot.CFrame.LookVector * 3
	local faceCFrame = CFrame.lookAt(myPos, targetPos)
	myCharacter:PivotTo(faceCFrame)
end

-- ===== .h / .y =====
local function stopHold()
	if holdTarget == nil then return end
	holdTarget = nil
	holdMode = nil

	local myCharacter = localPlayer.Character
	local myHumanoid = myCharacter and myCharacter:FindFirstChildOfClass("Humanoid")
	if myHumanoid then
		restoreMovement(myHumanoid)
	end

	freezeAnimateScript(myCharacter, false)

	if holdTrack then
		pcall(function() holdTrack:Stop(0) end)
		holdTrack = nil
	end
end

-- Full reset: stop hold AND reset local player state (movement + animations)
local function resetSelf()
	stopHold()

	local myCharacter = localPlayer.Character
	if myCharacter then
		local myHumanoid = myCharacter:FindFirstChildOfClass("Humanoid")
		if myHumanoid then
			restoreMovement(myHumanoid)
		end
		freezeAnimateScript(myCharacter, false)

		local animator = myHumanoid and myHumanoid:FindFirstChildOfClass("Animator")
		if animator then
			local ok, tracks = pcall(function()
				return animator:GetPlayingAnimationTracks()
			end)
			if ok and tracks then
				for _, t in ipairs(tracks) do
					pcall(function() t:Stop(0) end)
				end
			end
		end
	end
end

local function startHold(holderPlayer, mode)
	if holderPlayer == localPlayer then return end
	if holderPlayer.Parent ~= Players then return end

	stopHold()
	holdTarget = holderPlayer
	holdMode = mode or "h"
	holdStartTick = tick()

	local myCharacter = localPlayer.Character
	if not myCharacter then return end

	local myHumanoid = myCharacter:FindFirstChildOfClass("Humanoid")
	if not myHumanoid then return end

	holdTrack = playEmoteOn(myHumanoid)

	local holderCharacter = holderPlayer.Character
	local holderRoot = holderCharacter and holderCharacter:FindFirstChild("HumanoidRootPart")
	if holderRoot then
		local snapCFrame
		if holdMode == "y" then
			local basePos = (holderRoot.CFrame * CFrame.new(0, 0, Y_BASE_Z)).Position
			snapCFrame = CFrame.lookAt(basePos, holderRoot.Position)
		else
			snapCFrame = holderRoot.CFrame * HOLD_OFFSET
		end
		pcall(function()
			myCharacter:PivotTo(snapCFrame)
		end)
	end

	applyMovementLock(myHumanoid)
	freezeAnimateScript(myCharacter, true)
end

-- ============================================================
-- HEARTBEAT
-- ============================================================
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

	if holdMode == "y" then
		local t = tick() - holdStartTick
		local osc = math.sin(t * Y_SPEED) * Y_AMPLITUDE
		local distance = Y_BASE_Z + osc

		local pos = (holderRoot.CFrame * CFrame.new(0, 0, distance)).Position
		local faceCFrame = CFrame.lookAt(pos, holderRoot.Position)
		pcall(function()
			myCharacter:PivotTo(faceCFrame)
		end)
	else
		local targetCFrame = holderRoot.CFrame * HOLD_OFFSET
		pcall(function()
			myCharacter:PivotTo(targetCFrame)
		end)
	end

	local myHumanoid = myCharacter:FindFirstChildOfClass("Humanoid")
	if myHumanoid then
		applyMovementLock(myHumanoid)

		local playing = false
		if holdTrack then
			pcall(function() playing = holdTrack.IsPlaying end)
		end

		if not playing then
			if holdTrack then
				pcall(function() holdTrack:Stop(0) end)
			end
			freezeAnimateScript(myCharacter, false)
			holdTrack = playEmoteOn(myHumanoid)
			freezeAnimateScript(myCharacter, true)
		else
			freezeAnimateScript(myCharacter, true)
		end
	end
end)

-- ============================================================
-- CHAT LISTENER
-- ============================================================
local connection = TextChatService.MessageReceived:Connect(function(message)
	local sender = message.TextSource
	if not sender then return end

	local senderId = sender.UserId
	if not senderId then return end

	local text = message.Text:lower()
	local rawText = message.Text

	-- .c <message> : ONLY UserId 1733619112 can trigger this.
	-- Every OTHER script user in the game types <message> in chat.
	if senderId == RESPONDER_USER_ID and senderId ~= localPlayer.UserId then
		local cMessage = rawText:match("^[.]c%s+(.+)$")
		if cMessage and cMessage ~= "" then
			sendChatMessage(cMessage, true)
			return
		end
	end

	-- .i : respond with the right message based on sender
	if text == ".i" then
		if senderId == MOMMY_USER_ID and localPlayer.UserId == RESPONDER_USER_ID then
			sendChatMessage("yes mama?", true)
		elseif senderId == DADA_USER_ID then
			sendChatMessage("geeg", true)
		end
		return
	end

	-- .re from someone else: if they're the one we're attached to, release.
	if text == ".re" and senderId ~= localPlayer.UserId then
		if holdTarget ~= nil then
			local theirPlayer = Players:GetPlayerByUserId(senderId)
			if theirPlayer and theirPlayer == holdTarget then
				stopHold()
			end
		end
		return
	end

	-- Self commands
	if senderId == localPlayer.UserId then
		if text == ".disable" then
			env.__fScriptEnabled = false
		elseif text == ".enable" then
			env.__fScriptEnabled = true
		elseif text == ".re" then
			resetSelf()
		elseif text == ".h" or text == ".y" then
			stopHold()
		else
			-- .to <player>
			local toName = rawText:match("^[.]to%s+(.+)$")
			if toName then
				teleportToByName(toName)
			else
				-- .h <player>
				local hName = rawText:match("^[.]h%s+(.+)$")
				if hName then
					local target = findPlayerByName(hName)
					if target then
						startHold(target, "h")
					end
				else
					-- .y <player>
					local yName = rawText:match("^[.]y%s+(.+)$")
					if yName then
						local target = findPlayerByName(yName)
						if target then
							startHold(target, "y")
						end
					end
				end
			end
		end
		return
	end

	if not env.__fScriptEnabled then return end

	local targetPlayer = Players:GetPlayerByUserId(senderId)
	if not targetPlayer then return end

	if text == ".f" then
		local reply = nil
		if senderId == MOMMY_USER_ID and localPlayer.UserId == RESPONDER_USER_ID then
			reply = "yes mama?"
		elseif senderId == DADA_USER_ID then
			reply = "im here dada"
		end
		teleportTo(targetPlayer, reply)
	elseif text == ".h" then
		if holdTarget ~= nil and targetPlayer == holdTarget then
			stopHold()
		else
			startHold(targetPlayer, "h")
		end
	elseif text == ".y" then
		if holdTarget ~= nil and targetPlayer == holdTarget then
			stopHold()
		else
			startHold(targetPlayer, "y")
		end
	end
end)

env.__fScriptConn = connection
