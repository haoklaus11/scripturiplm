warn("hi klaus, enjoy! 07/12/24 :3")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local places = { 17503543197 }

if not table.find(places, game.PlaceId) then
	return
end

task.wait(5)

_G.test = not _G.test

local FarmSettings = {
	PetsPerCoin = 3, -- set to 3 once we know it works
	Area = "Doodle Oasis",
	Egg = "Doodle Tropical Egg",
}

local orb = require(game.ReplicatedStorage.Library.Client.OrbCmds.Orb)
local eggCmds = require(game.ReplicatedStorage.Library.Client:FindFirstChild("EggCmds", true))
orb.CollectDistance = 9e9
orb.CombineDelay = 0
orb.DefaultPickupDistance = 9e9
orb.CombineDistance = 9e9
game:GetService("Players").LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"].Disabled = true

local Player = game.Players.LocalPlayer
local Pets_SetTargetBulk = game:GetService("ReplicatedStorage").Network.Pets_SetTargetBulk
local Breakables_JoinPetBulk = game:GetService("ReplicatedStorage").Network.Breakables_JoinPetBulk
local Damage_Event = game.ReplicatedStorage.Network.Breakables_PlayerDealDamage
Player.PlayerScripts.Scripts.Game.Pets.PetAI.Enabled = false

local Requires = {
	["MapCmds"] = require(game.ReplicatedStorage.Library:FindFirstChild("MapCmds", true)),
	["PlayerPet"] = require(game.ReplicatedStorage.Library:FindFirstChild("PlayerPet", true)),
	["ZonesUtil"] = require(game.ReplicatedStorage.Library:FindFirstChild("ZonesUtil", true)),
	["BreakablesUtil"] = require(game.ReplicatedStorage.Library:FindFirstChild("BreakablesUtil", true)),
	["Zones"] = require(game.ReplicatedStorage.Library.Directory:FindFirstChild("Zones")),
}

local Senv = {
	Save = getsenv(game.ReplicatedStorage.Library:FindFirstChild("Save", true)),
	["Breakables Frontend"] = getsenv(Player.PlayerScripts.Scripts.Game.Breakables["Breakables Frontend"]),
}

local Upvalues = {
	CurrentZone = debug.getupvalue(Requires.MapCmds.GetCurrentZone, 1),
	Save = debug.getupvalue(Senv.Save.Update, 1),
	Coins = debug.getupvalue(Senv["Breakables Frontend"].getBreakable, 1),
}

local Utils = {
	GetCurrentZone = function(self)
		return getupvalue(Requires.MapCmds.GetCurrentZone, 1)
	end,
	GetEquippedPetsDict = function(self)
		return Requires.PlayerPet.GetAll()
	end,
	GetEquippedPetsArray = function(self)
		local equippedPets = {}

		for _, pet in self:GetEquippedPetsDict() do
			table.insert(equippedPets, pet)
		end

		return equippedPets
	end,
	SplitEquippedPetsInTeams = function(self, teamsAmount)
		local petTeams = {}

		for i, v in self:GetEquippedPetsArray() do
			local teamPos = math.floor((i - 1) / teamsAmount) + 1
			if not petTeams[teamPos] then
				table.insert(petTeams, {})
			end

			table.insert(petTeams[teamPos], v.euid)
		end

		return petTeams
	end,
	CreateUIDStringFromTeam = function(self, petTeam)
		local uid = ""

		for _, petUID in petTeam do
			uid ..= petUID
		end

		return uid
	end,
	GetCoinsForZoneDic = function(self, zone)
		for _, v in Upvalues.Coins do
			if not rawget(Requires.Zones, v.parentID) then
				zone = v.parentID
				break
			end
		end

		local filteredCoins = {}
		for i, v in Upvalues.Coins do
			if v.parentID == zone then
				filteredCoins[i] = v
			end
		end

		return filteredCoins
	end,
	GetCoinsForZoneArr = function(self, zone)
		local gameCoinsArr = {}
		for _, v in self:GetCoinsForZoneDic(zone) do
			table.insert(gameCoinsArr, v)
		end

		return gameCoinsArr
	end,
	GetCoinsForZoneWithTeams = function(self, zone, petTeams)
		local coins = {}

		local gameCoinsArr = self:GetCoinsForZoneArr(zone)

		if #petTeams < 1 then
			return
		end

		for run = 1, math.ceil(#gameCoinsArr / #petTeams) do
			table.insert(coins, {})
		end

		for run, runTable in coins do
			for coinIndex = 1, #petTeams do
				local petTeam = petTeams[coinIndex]

				local difference = (FarmSettings.PetsPerCoin * run) - FarmSettings.PetsPerCoin
				local coinPos = coinIndex + difference
				local overLimit = #gameCoinsArr - ((coinPos - 1) % #gameCoinsArr + 1) + 1
				local coin = gameCoinsArr[coinPos] or gameCoinsArr[overLimit]

				runTable[petTeam] = coin.uid
			end
		end

		return coins
	end,
	CountDictionary = function(self, dic)
		local count = 0
		for _ in dic do
			count += 1
		end

		return count
	end,
}

local coinDebounce = {}
task.spawn(function()
	while _G.test and task.wait() do
		local petTeams = Utils:SplitEquippedPetsInTeams(FarmSettings.PetsPerCoin)
		local coins = Utils:GetCoinsForZoneArr(Utils:GetCurrentZone())

		if #petTeams < 1 then
			continue
		end

		if #coins < 1 then
			continue
		end

		local bulkTable = {}
		for petTeamIndex, petTeam in petTeams do
			local coinPos = (petTeamIndex - 1) % #coins + 1
			local teamUID = Utils:CreateUIDStringFromTeam(petTeam)
			local coin = coinDebounce[teamUID] ~= coins[coinPos].uid and coins[coinPos] or coins[coinPos % #coins + 1]

			coinDebounce[teamUID] = coin.uid

			Damage_Event:FireServer(coin.uid)

			for _, pet in petTeam do
				bulkTable[pet] = {
					["v"] = coin.uid,
				}
			end
		end

		Pets_SetTargetBulk:FireServer(bulkTable)

		local joinPetTable = {}
		for i, v in bulkTable do
			local target = v.v

			if not joinPetTable[target] then
				joinPetTable[target] = {}
			end

			table.insert(joinPetTable[target], i)
		end

		for target, petTable in joinPetTable do
			local formatTable = {}
			for _, pet in petTable do
				formatTable[pet] = target
			end
			Breakables_JoinPetBulk:FireServer(formatTable)
		end

		task.wait(0.2)
	end
end)

local replicatedStorage = cloneref(game.ReplicatedStorage)
local collectionService = cloneref(game:GetService("CollectionService"))
local httpService = cloneref(game:GetService("HttpService"))
local rs = cloneref(game:GetService("RunService"))

local client = game.Players.LocalPlayer

for _, conn in getconnections(client.Idled) do
	conn:Disable()
end

local clientScripts = client.PlayerScripts:WaitForChild("Scripts")
local gameScripts = clientScripts:WaitForChild("Game")
local machineScripts = gameScripts:WaitForChild("Machines")
local guiScripts = clientScripts:WaitForChild("GUIs")

local coreLibrary = require(replicatedStorage:WaitForChild("Library"))
local library = replicatedStorage:WaitForChild("Library")
local types = library:WaitForChild("Types")
local directory = library:WaitForChild("Directory")
local clientLibrary = library:WaitForChild("Client")
local coreDirectory = require(library.Directory)
local potion_directory = replicatedStorage:WaitForChild("__DIRECTORY").Potions

local clientSave = require(library:WaitForChild("Client").Save).Get()

local modules = {

	-- requires
	mapCmds = require(clientLibrary:FindFirstChild("MapCmds", true)),
	fruitCmds = require(clientLibrary:FindFirstChild("FruitCmds", true)),
	clientPets = require(clientLibrary:FindFirstChild("PlayerPet", true)),
	masteryCmds = require(clientLibrary:FindFirstChild("MasteryCmds", true)),

	-- client envs
	clientBreakables = getsenv(gameScripts:FindFirstChild("Breakables Frontend", true)),
	ultimates = getsenv(guiScripts:FindFirstChild("Ultimates HUD", true)),
}

local network = {}
do
	local _network = require(replicatedStorage.Library.Client.Network)

	function network.FireServer(name, ...)
		_network.Fire(name, ...)
	end

	function network.InvokeServer(name, ...)
		return _network.Invoke(name, ...)
	end
end

--[[
local vec3 = Vector3.new(1037.497802734375, 16.71531867980957, -14306.9453125)

local boosts = { "Luck", "Drops", "Diamonds" }

local thread = task.spawn(function()
	while true do
		task.wait()

		--		client.RequestStreamAroundAsync(client, vec3)
		task.spawn(client.RequestStreamAroundAsync, client, vec3)
		client.Character:PivotTo(CFrame.new(vec3))
		client.Character.PrimaryPart.Velocity = Vector3.zero

		for _, boost in boosts do
			network.InvokeServer("BoostExchange_AddTime", boost, 100)
		end
	end
end)

task.wait(10)

task.cancel(thread)
--]]

do
	task.spawn(function()
		while true do
			task.wait()

			local inventory = clientSave.Inventory

			for uid, fruit in inventory.Fruit do
				if not fruit.id then
					continue
				end

				local activeFruits = clientSave.Fruits

				if not activeFruits then
					continue
				end

				local fruitAmount = fruit._am
				local fruitTable = activeFruits[fruit.id]

				setthreadidentity(8)
				local powerLimit = modules.fruitCmds.ComputeFruitPowerLimit() or 20
				--setthreadcaps(8)
				local fruitLeft = not fruitTable and 0 or #fruitTable

				if fruitLeft == powerLimit and fruitTable[1] <= 10 then
					fruitLeft -= 1
				end

				if not powerLimit or not fruitLeft or not fruitAmount then
					continue
				end

				local consumeAmount = math.clamp(powerLimit - fruitLeft, 0, fruitAmount)

				if consumeAmount < 1 then
					continue
				end

				network.FireServer("Fruits: Consume", uid, consumeAmount)

				task.wait(1)
			end
		end
	end)
end

do
	task.spawn(function()
		while true do
			task.wait()

			if modules.mapCmds.GetCurrentZone() == FarmSettings.Area then
				local inventory = clientSave.Inventory.Misc

				for uid, item in inventory do
					local id = item.id

					if id:lower():find("sprinkler") then
						network.InvokeServer("Sprinklers: Consume", "Breakable Sprinkler", uid)
					end

					if id:lower():find("fortune") then
						local flag_name = id

						network.InvokeServer("Flags: Consume", flag_name, uid)
					end

					if id == "Comet" then
						network.InvokeServer("Comet_Spawn", uid)
					end

					if id == "Mini Lucky Block" then
						network.InvokeServer("MiniLuckyBlock_Consume", uid)
					end
				end
			end
		end
	end)
end

do
	task.spawn(function()
		while true do
			task.wait(0.5)

			if not modules.mapCmds.IsInDottedBox() then
				continue
			end

			if modules.mapCmds.GetCurrentZone() == FarmSettings.Area then
				modules.ultimates.activateUltimate()
			end
		end
	end)
end

do
	local getZoneFolder = function(zoneName)
		for _, zone in coreDirectory.Zones do
			local name = zone.ZoneName

			if name == zoneName then
				local folder = zone.ZoneFolder

				if folder then
					return folder
				end
			end
		end
	end

	local getMiddle = function(folder)
		local breakable_spawns = folder:FindFirstChild("BREAKABLE_SPAWNS", true)

		if not breakable_spawns then
			repeat
				task.wait()
				local teleport = folder:FindFirstChild("Teleport", true)

				if teleport then
					breakable_spawns = folder:FindFirstChild("BREAKABLE_SPAWNS", true)
					client.Character:PivotTo(teleport.CFrame + Vector3.new(0, 3, 0))
					client.Character.PrimaryPart.Velocity = Vector3.zero
				end

			until breakable_spawns
		end

		local main = breakable_spawns:FindFirstChild("Main")

		if main then
			return main
		end
	end

	task.spawn(function()
		while true do
			task.wait()

			local area = FarmSettings.Area

			if not area then
				continue
			end

			local folder = getZoneFolder(area)

			if not folder then
				continue
			end

			local middle = getMiddle(folder)

			if not middle then
				continue
			end

			network.InvokeServer("Eggs_RequestPurchase", FarmSettings.Egg, eggCmds.GetMaxHatch())

			if client:DistanceFromCharacter(middle.Position) > 10 then
				client.Character:PivotTo(middle.CFrame + Vector3.new(0, 3, 0))
				client.Character.PrimaryPart.Velocity = Vector3.zero
			end
		end
	end)
end

if client.PlayerScripts.Scripts.Core:FindFirstChild("Idle Tracking") then
	client.PlayerScripts.Scripts.Core["Idle Tracking"]:Destroy()
end

do
	task.spawn(function()
		while true do
			task.wait(1)

			for _, pet in modules.clientPets.GetAll() do
				if pet.cpet then
					pet.cpet:Destroy()
				end
			end
		end
	end)
end

local getBreakable = modules.clientBreakables.getBreakable

do
	local function getTarget()
		local list = debug.getupvalue(getBreakable, 1)

		for _, object in list do
			local health = object.health

			if not (health and health > 0) then
				continue
			end

			local area = object.parentID

			if area and area == FarmSettings.Area then
				return object
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait()

			local target = getTarget()

			if target then
				network.FireServer("Breakables_PlayerDealDamage", target.uid)
			end
		end
	end)
end

local blunder = game.ReplicatedFirst:WaitForChild("Blunder", 5)

if blunder then
	blunder:Destroy()
end

if not game.ReplicatedStorage.Network:FindFirstChild("Orbs: Create") then
	repeat
		task.wait()

	until game.ReplicatedStorage.Network:FindFirstChild("Orbs: Create")
end

if game.ReplicatedStorage.Network:FindFirstChild("Orbs: Create") then
	hookfunction(getconnections(game.ReplicatedStorage.Network["Orbs: Create"].OnClientEvent)[1].Function, function(t)
		local collect = {}
		for _, v in t do
			table.insert(collect, v.id)
		end

		game.ReplicatedStorage.Network["Orbs: Collect"]:FireServer(collect)
	end)
end

setfpscap(12)

local initial = client.leaderstats:FindFirstChild("💎 Diamonds").Value

task.spawn(function()
	while true do
		task.wait(60)

		local new = client.leaderstats:FindFirstChild("💎 Diamonds").Value

		print(`The last 60 seconds: {new - initial}`)
		initial = new
	end
end)

local getPotionID = function(name)
	for id, entry in clientSave.Inventory.Potion do
		if entry.id == name then
			return id
		end
	end

	return nil
end

task.spawn(function()
	while true do
		task.wait()

		for id, data in clientSave.Potions do
			if id == "The Cocktail" then
				if not data["1"] then
					repeat
						task.wait()
						local uid = getPotionID("The Cocktail")

						if not uid then
							continue
						end

						network.FireServer("Potions: Consume", uid)

					until data["1"]
				end
			end
		end
	end
end)

--[[

local consume = {
	["Damage"] = true,
	["Treasure Hunter"] = true,
	["Diamonds"] = true,
	["Lucky"] = true,
}

rs.Heartbeat:Connect(function()
	for uid, data in clientSave.Inventory.Potion do
		if data.id == "Coins" and data.tn > 5 then
			network.FireServer("Potions: Consume", uid)
		end

		if consume[data.id] and data.tn > 7 then
			network.FireServer("Potions: Consume", uid)
		end
	end
end)
	
--]]

local ranks_cmds = require(game.ReplicatedStorage.Library.Client.RankCmds)
local save = require(game.ReplicatedStorage.Library.Client.Save).Get()

local ranks_util = require(game.ReplicatedStorage.Library.Util.RanksUtil)

local claimRewards = function()
	if not ranks_cmds.AllRewardsRedeemed() then
		local rank = save.Rank
		local stars = save.RankStars
		local rank_rewards = save.RedeemedRankRewards

		local rank_id = ranks_util.RankIDFromNumber(rank)

		local rank_info = coreDirectory.Ranks[rank_id]

		local stars_count = 0

		for idx, value in rank_info.Rewards do
			stars_count += value.StarsRequired

			local state = stars_count <= stars
			local claimed = rank_rewards[tostring(idx)] ~= nil
			local bool = not (state or claimed)

			if bool then
				if stars_count - value.StarsRequired <= stars then
					bool = stars < stars_count
				else
					bool = false
				end
			end

			if claimed then
				continue
			end

			network.FireServer("Ranks_ClaimReward", tonumber(idx))
		end
	end
end

local a = require(game:GetService("ReplicatedStorage").Library.Client.HoverboardCmds)

if a.IsEquipped() then
	a.RequestUnequip()
end

rs.Heartbeat:Connect(claimRewards)

--local gist =
--	"https://gist.githubusercontent.com/kalasthrowaway/f837e9a41fcb11694441edc33b1e05c9/raw/d53d0d188b2de53e743f6898ea703f23ddc14a9d/optimize.lua"
--loadstring(game:HttpGet(gist))()

local getMinimum = function(rarity)
	local default = 10

	if rarity == "Gold" then
		if modules.masteryCmds.HasPerk("Pets", "GoldReduction") then
			default += -modules.masteryCmds.GetPerkPower("Pets", "GoldReduction")
		end
	end

	if rarity == "Rainbow" then
		if modules.masteryCmds.HasPerk("Pets", "RainbowReduction") then
			default += -modules.masteryCmds.GetPerkPower("Pets", "RainbowReduction")
		end
	end

	return default
end

task.spawn(function()
	while true do
		task.wait()

		pcall(function()
			for uid, pet in modules.save.Inventory.Pet do
				if pet.id:lower():find("huge") then
					continue
				end

				if pet.id:lower():find("titanic") then
					continue
				end

				if pet.id:lower():find("exclusive") then
					continue
				end

				local amount = pet._am or 0
				local pet_type = pet.pt or 0

				if amount == 0 then
					continue
				end

				if pet_type ~= 0 then
					continue
				end

				local gold_minimum = getMinimum("Gold")

				if amount < gold_minimum then
					continue
				end

				network.InvokeServer("GoldMachine_Activate", uid, math.floor(amount / gold_minimum))
			end

			for uid, pet in modules.save.Inventory.Pet do
				if pet.id:lower():find("huge") then
					continue
				end

				if pet.id:lower():find("titanic") then
					continue
				end

				if pet.id:lower():find("exclusive") then
					continue
				end

				local amount = pet._am or 0
				local pet_type = pet.pt or 0

				if pet_type ~= 1 then
					continue
				end

				if amount == 0 then
					continue
				end

				local rainbow_minimum = getMinimum("Rainbow")

				if amount < rainbow_minimum then
					continue
				end

				network.InvokeServer("RainbowMachine_Activate", uid, math.floor(amount / rainbow_minimum))
			end
		end)
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
repeat
	wait()
until game.Players
repeat
	wait()
until game.Players.LocalPlayer
repeat
	wait()
until game.Players.LocalPlayer.Character
repeat
	wait()
until game.Players.LocalPlayer.Character.HumanoidRootPart
repeat
	wait()
until game.ReplicatedStorage
repeat
	wait()
until game.ReplicatedStorage.Library

task.wait(15)

for i, v in pairs(getconnections(game.Players.LocalPlayer.Idled)) do
	v:Disable()
end

local Senv = {
	Save = getsenv(game.ReplicatedStorage.Library:FindFirstChild("Save", true)),
}

local Upvalues = {
	Save = getupvalue(Senv.Save.Update, 1),
}

local Player = game.Players.LocalPlayer

local Inventory = {
	Pets = {},
}
function make_inventory()
	local Current_Inv = Upvalues.Save[Player].Inventory.Pet

	for i, v in Current_Inv do
		if v._am then
			Inventory.Pets[i] = v._am
		elseif Inventory.Pets[i] then
			Inventory.Pets[i] += 1
		else
			Inventory.Pets[i] = 1
		end
	end
end
make_inventory()

function get_inventory()
	local Current_Inv = Upvalues.Save[Player].Inventory.Pet
	local Sorted_Inv = {}

	for i, v in Current_Inv do
		if v._am then
			Sorted_Inv[i] = v._am
		elseif Sorted_Inv[i] then
			Sorted_Inv[i] += 1
		else
			Sorted_Inv[i] = 1
		end
	end
	return Sorted_Inv
end

function check_inventory()
	local Current_Inv = get_inventory()
	local New_Pets = {}

	for i, v in Current_Inv do
		if not Inventory.Pets[i] then
			local current_invetory = Upvalues.Save[Player].Inventory.Pet
			local Name = (current_invetory[i].sh == true and "Shiny " or "")
				.. (current_invetory[i].pt == 1 and "Golden " or current_invetory[i].pt == 2 and "Rainbow " or "")
				.. Upvalues.Save[Player].Inventory.Pet[i].id
			New_Pets[Name] = Upvalues.Save[Player].Inventory.Pet[i].id
		end
	end

	return New_Pets
end

function SendWebhookLog(Table, WebhookUrl)
	local Body = game:GetService("HttpService"):JSONEncode(Table)
	local req = request or http.request
	if req ~= nil then
		local Result = req({
			Url = WebhookUrl,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
			},
			Body = Body,
		})

		return Result
	end
end

task.spawn(function()
	while task.wait(10) do
		for i, v in check_inventory() do
			if string.find(i, "Huge") then
				local image_id = nil

				for _, Pet in game:GetService("ReplicatedStorage").__DIRECTORY.Pets:GetDescendants() do
					if Pet.Name == v then
						if string.find(i, "Golden ") then
							image_id = string.gsub(require(Pet).goldenThumbnail, "%D", "")
						else
							image_id = string.gsub(require(Pet).thumbnail, "%D", "")
						end
					end
				end
				SendWebhookLog(
					{
						content = "<@259067182690992128> WAKEY WAKEY ",
						embeds = {
							{
								--	["title"] = "Obtained a " .. i,
								["title"] = `{Player.Name} hatched a {i}`,
								["color"] = 16771840,
								["thumbnail"] = {
									["url"] = "https://biggamesapi.io/image/" .. image_id,
								},
							},
						},
					},
					"https://discord.com/api/webhooks/1257771164491710636/LulWqH1iRgvy7ee_OYzbEMSetFxgdKGO1ZBXnWjSgGPJtFs0UrW9aJI-EhYCOVSFjN0d"
				)

				make_inventory()
			end
		end
	end
end)

local vu = cloneref(game:GetService("VirtualUser"))
game.Players.LocalPlayer.Idled:Connect(function()
	vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	task.wait(1)
	vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

task.spawn(function()
	game:GetService("RunService"):Set3dRenderingEnabled(false)
end)

task.spawn(function()
	while true do
		task.wait(1)
		game:GetService("ReplicatedStorage").Network["Hype Wheel: Claim"]:InvokeServer()
	end
end)
