local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")

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

-- Offset relative to the holder's root: 1.5 studs down (waist) and
-- 1.5 studs forward. Same orientation as holder -> our back is to them.
local HOLD_OFFSET = CFrame.new(0, -1.5, -1.5)

local lastTeleport = 0

local function getRootPart(player)
	local character = player.Character
	if not character then
		character = player.CharacterAdded:Wait()
	end
	return character:WaitForChild("HumanoidRootPart")
end

local function playEmoteOn(humanoid)
	if not humanoid then return nil end
	if humanoid.RigType == Enum.HumanoidRigType.R6 then return nil end

	local track
	local success = pcall(function()
		track = humanoid:PlayEmoteAndGetAnimTrackById(EMOTE_ID)
	end)

	if not success or not track then
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

	-- Stand 3 studs in front of them, facing them
	local targetPos = targetRoot.Position
	local myPos = targetPos + targetRoot.CFrame.LookVector * 3
	local faceCFrame = CFrame.lookAt(myPos, targetPos)
	myCharacter:PivotTo(faceCFrame)

	task.wait(0.1)

	-- Make THEM look at US
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
-- The holder is the player who typed ".h"; we follow them.
local holdTarget = nil
local holdTrack = nil

local function stopHold()
	holdTarget = nil
	if holdTrack then
		pcall(function() holdTrack:Stop() end)
		holdTrack = nil
	end
end

local function startHold(holderPlayer)
	if holderPlayer == localPlayer then return end
	if holderPlayer.Parent ~= Players then return end

	stopHold()
	holdTarget = holderPlayer

	-- Immediate snap so we don't wait a frame
	local holderCharacter = holderPlayer.Character
	local holderRoot = holderCharacter and holderCharacter:FindFirstChild("HumanoidRootPart")
	local myCharacter = localPlayer.Character
	if holderRoot and myCharacter then
		pcall(function()
			myCharacter:PivotTo(holderRoot.CFrame * HOLD_OFFSET)
		end)
	end

	local myHumanoid = myCharacter and myCharacter:FindFirstChildOfClass("Humanoid")
	if myHumanoid then
		holdTrack = playEmoteOn(myHumanoid)
	end
end

env.__fFollowConn = RunService.Heartbeat:Connect(function()
	if not holdTarget then return end

	-- Holder left
	if holdTarget.Parent ~= Players then
		stopHold()
		return
	end

	local holderCharacter = holdTarget.Character
	local holderRoot = holderCharacter and holderCharacter:FindFirstChild("HumanoidRootPart")
	local myCharacter = localPlayer.Character
	local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")

	if not holderRoot or not myCharacter or not myRoot then return end

	-- Stick to holder's waist, same orientation as them (our back to them)
	local targetCFrame = holderRoot.CFrame * HOLD_OFFSET
	pcall(function()
		myCharacter:PivotTo(targetCFrame)
	end)

	-- Keep ourselves locked in the emote
	local myHumanoid = myCharacter:FindFirstChildOfClass("Humanoid")
	if myHumanoid then
		local playing = false
		if holdTrack then
			pcall(function() playing = holdTrack.IsPlaying end)
		end
		if not playing then
			holdTrack = playEmoteOn(myHumanoid)
		end
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
		elseif text == ".release" then
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
		startHold(targetPlayer)
	end
end)

env.__fScriptConn = connection
