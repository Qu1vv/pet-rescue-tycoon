local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
local Validation = require(script.Parent.Parent.Common.Validation)
local PadService = {}
local started = false

-- Watches character-root entry into claim, purchase and upgrade zones, with per-player debounce.
function PadService.Start(shelter)
	if started then return end
	started = true
	local pads = {}
	for _, plot in shelter.GetWorld().Plots do
		table.insert(pads, { Plot = plot, Zone = plot.ClaimZone, Kind = "Claim", Inside = {}, Last = {} })
		table.insert(pads, { Plot = plot, Zone = plot.PurchaseZone, Kind = "Purchase", Inside = {}, Last = {} })
		for branch, pad in plot.UpgradePads do
			table.insert(pads, { Plot = plot, Zone = pad.Zone, Kind = "Upgrade", Branch = branch, Inside = {}, Last = {} })
		end
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Config.PadInterval then return end
		elapsed = 0
		local players = Players:GetPlayers()
		for _, pad in pads do
			local inside = {}
			for _, player in players do
				local root = Validation.Root(player)
				-- Check the character root, not arbitrary touching limbs/accessories.
				-- Loading is not an attempted entry: a player already on the pad must
				-- activate it once their profile is ready, without stepping off first.
				if root and player:GetAttribute("ProfileReady") == true and Validation.InZone(root.Position, pad.Zone) then
					inside[player] = true
					local active = pad.Kind == "Claim" or (pad.Kind == "Purchase" and not pad.Plot.Purchased)
						or (pad.Kind == "Upgrade" and pad.Plot.Purchased and Config.Upgrades[pad.Branch][pad.Plot.Upgrades[pad.Branch] + 1] ~= nil)
					if active and not pad.Inside[player] and os.clock() - (pad.Last[player] or -math.huge) >= Config.PurchaseCooldown then
						pad.Last[player] = os.clock()
						local _, reason
						if pad.Kind == "Claim" then
							-- Crossing your own entrance is an ordinary trip home.
							if pad.Plot.Owner ~= player then _, reason = shelter.TryClaim(player, pad.Plot.Id) end
						elseif pad.Kind == "Upgrade" then
							_, reason = shelter.TryUpgrade(player, pad.Plot.Id, pad.Branch)
						else
							_, reason = shelter.TryPurchase(player, pad.Plot.Id)
						end
						if reason then shelter.Notify(player, reason) end
					end
				end
			end
			pad.Inside = inside
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, pad in pads do
			pad.Inside[player], pad.Last[player] = nil, nil
		end
	end)
end

return PadService
