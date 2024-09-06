-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Imports
local Flux = require(ReplicatedStorage.Shared.Flux)

local t = require(Flux.Packages.t)
local Timer = require(Flux.Packages.Timer)
local Trove = require(Flux.Packages.Trove)

-- Types
type Batch = { BatchEntry }
type BatchEntry = {
	Key: any,
	Payload: any,
	LastUpdate: number,
}

-- Instances

-- Variables
local tCommRemote = t.interface({
	Fire = t.callback,
})

------------------------------------------------------------

local CommEventBatcher = {}
CommEventBatcher.__index = CommEventBatcher

local tCommEventBatcher = t.tuple(tCommRemote, t.numberMin(0))
function CommEventBatcher.new(commRemote: any, batchFrequency: number): { [string]: any }
	assert(tCommEventBatcher(commRemote, batchFrequency))

	local self = setmetatable({}, CommEventBatcher)
	self._Trove = Trove.new()

	self._batch = {} :: { [Player]: Batch }

	self._Trove:Construct(Timer.Simple, batchFrequency, function()
		for player: Player, batch: Batch in self._batch do
			table.sort(batch, function(a: BatchEntry, b: BatchEntry): boolean
				return a.LastUpdate < b.LastUpdate
			end)

			if t.ActivePlayer(player) then
				commRemote:Fire(player, batch)
			end
			self._batch[player] = nil
		end
	end)

	return self
end

local tSetInPlayerBatch = t.tuple(t.ActivePlayer, t.any, t.optional(t.any))
function CommEventBatcher:SetInPlayerBatch(player: Player, key: any, payload: any?)
	assert(tSetInPlayerBatch(player, key, payload))

	local batch = (self._batch[player] or {}) :: Batch
	self._batch[player] = batch

	for _, batchEntry: BatchEntry in batch do
		if batchEntry.Key == key then
			batchEntry.Payload = payload
			batchEntry.LastUpdate = os.clock()
			return
		end
	end

	table.insert(batch, {
		Key = key,
		Payload = payload,
		LastUpdate = os.clock(),
	})
end

local tAddToPlayerBatch = t.tuple(t.ActivePlayer, t.any)
function CommEventBatcher:AddToPlayerBatch(player: Player, payload: any): string?
	assert(tAddToPlayerBatch(player, payload))

	local batchId: string = HttpService:GenerateGUID(false)
	self:SetInPlayerBatch(player, batchId, payload)

	return batchId
end

function CommEventBatcher:Destroy()
	self._batch = nil
	self._Trove:Destroy()
end

return CommEventBatcher
