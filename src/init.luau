-- Roblox Services
local HttpService = game:GetService("HttpService")

-- Imports
local packages = script.Parent

local t = require(packages.t)
local Timer = require(packages.Timer)
local Trove = require(packages.Trove)

-- Types
type Batch = { [any]: any }

-- Instances

-- Variables
local tCommRemote = t.interface({
	Fire = t.callback,
})

------------------------------------------------------------

local CommEventBatcher = {}
CommEventBatcher.__index = CommEventBatcher

local tCommEventBatcher = t.tuple(tCommRemote, t.numberMin(0))
function CommEventBatcher.new(commRemote: any, batchFrequency: number)
	assert(tCommEventBatcher(commRemote, batchFrequency))

	local self = setmetatable({}, CommEventBatcher)
	self._Trove = Trove.new()

	self._batch = {} :: { [Player]: Batch }

	self._Trove:Construct(Timer.Simple, batchFrequency, function()
		for player: Player, batch: Batch in self._batch do
			if t.ActivePlayer(player) then
				commRemote:Fire(player, batch)
			end
			self._batch[player] = nil
		end
	end)

	return self
end

local tSetInPlayerBatch = t.tuple(t.Player, t.any, t.optional(t.any))
function CommEventBatcher:SetInPlayerBatch(player: Player, key: any, payload: any?)
	assert(tSetInPlayerBatch(player, key, payload))

	local batch = self._batch[player] or {}
	self._batch[player] = batch

	batch[key] = payload
end

local tAddToPlayerBatch = t.tuple(t.Player, t.any)
function CommEventBatcher:AddToPlayerBatch(player: Player, payload: any): string?
	assert(tAddToPlayerBatch(player, payload))

	local batch = self._batch[player] or {}
	self._batch[player] = batch

	local batchId: string = HttpService:GenerateGUID(false)
	batch[batchId] = payload

	return batchId
end

function CommEventBatcher:Destroy()
	self._batch = nil
	self._Trove:Destroy()
end

return CommEventBatcher
