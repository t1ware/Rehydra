-- made by zwag

if not Settings.Enable then 
    return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local KADebounce = false

setthreadidentity(2)
local require = require(ReplicatedStorage.Framework.Nevermore)

local Network = require("@Network")
local DataHandler = require("@DataHandler")
local WeaponMetadata = require("@WeaponMetadata")
local MeleeWeaponClient = require("@MeleeWeaponClient")
local RagdollableClient = require("@RagdollableClient")
local SpawnHandlerClient = require("@SpawnHandlerClient")
setthreadidentity(7)

function GetWeapon(Player)
	local Player = Player or LocalPlayer
	local Character = Player.Character or Player.CharacterAdded:Wait()

	for i,v in Character:GetChildren() do
		if not v:IsA("Tool") then 
            continue
        end
		if v:GetAttribute("ItemType") == "weapon" and WeaponMetadata[v:GetAttribute("ItemId")].class:lower():match("melee") then
			return v, MeleeWeaponClient.getObj(v)
		end
	end
    return
end

function InMenu(Player)
    local IsMenu = true
    if not Player.Character then 
        return IsMenu 
    end
    for i, v in Player.Character:GetChildren() do
        if v:GetAttribute("ParryShieldId") then
            IsMenu = false
        end
    end
    return IsMenu
end

function GetSessionData(Player)
    return DataHandler.getSessionDataRoduxStoreForPlayer(Player or LocalPlayer)
end

function GetClosest(Distance,Priority,CheckFunction)
    local function n(Player)
        if (Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChild("Humanoid") and Player.Character.Humanoid.Health ~= 0) then
            return true
        end
        return
    end

	local Distance = Distance or math.huge
	local CheckFunction = CheckFunction or n
	local Player = {}
	
	for i,v in Players:GetPlayers() do
		if v == LocalPlayer or not CheckFunction(v) or InMenu(v) then continue end

		local HRP = v.Character.HumanoidRootPart
		local Magnitude = (HRP.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
		
		if Magnitude < Distance  then
			Distance = Magnitude
			Player[v.Name] = v.Character.Humanoid.Health
		end
	end

    if Priority then
	    table.sort(Player)  
    end
	
	return Player
end

function Teleport(CF)
    LocalPlayer.Character.HumanoidRootPart.CFrame = CF
    task.wait(1)
    repeat RunService.Heartbeat:Wait() until LocalPlayer.Character.HumanoidRootPart.ReceiveAge == 0
    task.wait()
    LocalPlayer.Character.HumanoidRootPart.CFrame = CF
end

do
    RagdollableClient.attemptToggleActualRagdollClient = function(...)
        return
    end

    if LocalPlayer.Name ~= Settings.Settings.Main then
        if Settings.Settings.MuteAudio then
            UserSettings().GameSettings.MasterVolume = 0
        end
    
        if Settings.Settings.FPScap >= 1 then
            setfpscap(Settings.Settings.FPScap)
        end
    
        if Settings.Settings.DisableGPU then
            RunService:Set3dRenderingEnabled(false)
        end    
    end

    task.spawn(function()
        if Settings.Settings.ResetEvery then
            while RunService.RenderStepped:Wait() do
                if InMenu(LocalPlayer) then
                    local kdrvalue = tonumber(string.match(LocalPlayer.PlayerGui.RoactUI.MainMenu.PagesScreenGuiContainer.PlayPage.MiddleViewFrameContainer.PlayerInfoFrameContainer.TextFrameContainer.StatsFrameContainer.KDR.Text, "KDR: (%d+%.%d+)"))
                    if kdrvalue and kdrvalue <= Settings.Settings.Reset.KDR then
                        continue
                    end
                else
                    local killstreakvalue = tonumber(LocalPlayer.PlayerGui.RoactUI.BottomStatusIndicators.FrameContainer.BackpackFrame.HotbarFrame.KillStreakTextFrame.NumberText.Text)
                    if killstreakvalue and killstreakvalue >= Settings.Settings.KillStreak then
                        Network:FireServer("SelfDamage", -1, {ignoreForceField = true})
                    end
                end
                Network:FireServer("SelfDamage", -1, {ignoreForceField = true})
            end
        end
    end)

    task.spawn(function()
        if Settings.Settings.AutoGlory then
            while RunService.RenderStepped:Wait() do
                task.wait(.5)
                local closest = GetClosest(25, true)
                local tool = GetWeapon() 
                if tool and closest and next(closest) then 
                    local targetPlayer = Players:FindFirstChild(next(closest))
                    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") and targetPlayer.Character.Humanoid.Health <= 20 then
                        Network:FireServer("StartGloryKill", tool, targetPlayer.Character, CFrame.new(), Vector3.new())
                    end
                end
            end
        end
    end)
end

RunService.RenderStepped:Connect(function()
    GetSessionData():getState().fallDamageClient.isDisabled = true

    if LocalPlayer.Name == Settings.Settings.Main then
        if InMenu(LocalPlayer) then
            setthreadidentity(2)
            SpawnHandlerClient.spawnCharacter(true)
            setthreadidentity(7)
            task.wait(0.5)
            Teleport(CFrame.new(22, -111, 4007))
        end

        local weapon, metadata = GetWeapon()
        if not weapon then
            for _,v in pairs(LocalPlayer.Backpack:GetChildren()) do
                if v:IsA("Tool") and (v:FindFirstChild("Hitboxes") or v:GetAttribute("IsRangedWeapon")) then
                    LocalPlayer.Character.Humanoid:EquipTool(v)
                    break
                end
            end
        end
        
        if weapon and metadata and not KADebounce then
            local closest = GetClosest(15, true)
            if closest and next(closest) then
                KADebounce = true
                local onCooldown = false
                local usecd = true
                if usecd then
                    onCooldown = metadata._cooldownProgressTimer:getValue() < 0.75
                end

                if not onCooldown then 
                    if not Settings.Settings.PlayAnimation then
                        local slash = math.random(1, #metadata._itemConfig.slashMetadata)
                        metadata._cooldownProgressTimer:setValue(0)
                        metadata:setSlashCount(slash)
                        Network:FireServer("MeleeSwing", weapon, slash)
                        metadata._lastSlashTick = tick()
                        weapon:SetAttribute("LastSlashTick", metadata._lastSlashTick)
                        task.wait(0.1)
                        for i, v in metadata.meleeHitboxes do
                            for playerName, health in closest do
                                local targetPlayer = Players:FindFirstChild(playerName)

                                if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Head") and health ~= 0 then
                                    local character = targetPlayer.Character
                                    local data = metadata._humanoidsAlreadyHit[character]
                                    if not data then
                                        metadata._humanoidsAlreadyHit[character] = {
                                            ["hitDetectionStage"] = 0,
                                            ["amountOfTimesHit"] = 0,
                                            ["lastHitTick"] = 0
                                        }
                                        data = metadata._humanoidsAlreadyHit[character]
                                    end

                                    Network:FireServer("MeleeDamage", 
                                        weapon, 
                                        character.Head, 
                                        i, 
                                        character.Head.Position, 
                                        character.Head.CFrame:ToObjectSpace(CFrame.new(character.Head.Position)), 
                                        metadata._character.HumanoidRootPart.CFrame.LookVector, 
                                        (character.Head.Position - character.Head.Position).Unit, 
                                        Vector3.yAxis, 
                                        tick() - metadata._lastSlashTick
                                    )

                                    data.hitDetectionStage = metadata.hitDetectionStage or 1
                                    data.amountOfTimesHit += 1
                                    data.lastHitTick = tick()
                                end
                            end
                            break
                        end
                    else
                        if metadata:getShouldSlash() then
                            metadata._activateSignal:Fire()

                            for i, v in metadata.meleeHitboxes do
                                v.HitboxStopTime = 1
                                for playerName, health in closest do
                                    local targetPlayer = Players:FindFirstChild(playerName)
    
                                    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Head") and health ~= 0 then
                                        local character = targetPlayer.Character
                                        v.OnHit:Fire(character.Head, character.Humanoid, {
                                            Distance = 1,
                                            Instance = character.Head,
                                            Material = Enum.Material.SmoothPlastic,
                                            Position = character.Head.Position,
                                            Normal = Vector3.yAxis
                                        }, character.Head.Position, character.Head.Position)
                                    end
                                end
                            end
                        end
                    end
                end

                KADebounce = false
            end
        end
    elseif LocalPlayer.Name ~= Settings.Settings.Main then
        local Character = LocalPlayer.Character
        if Character then
            local Humanoid = Character:FindFirstChild("Humanoid")
            if Humanoid and Humanoid.Health == 0 then
                Network:FireServer("StartFastRespawn")
                Network:InvokeServer("CompleteFastRespawn")
            end
        end

        if InMenu(LocalPlayer) then
            setthreadidentity(2)
            SpawnHandlerClient.spawnCharacter(true)
            task.wait(0.5)
            Teleport(CFrame.new(19, -111, 4007))
            setthreadidentity(7)
        end
    end
end)
