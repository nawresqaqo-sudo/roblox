--!strict
-- Access to the game's RemoteEvents. The server creates them; the client waits for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(script.Parent.Remotes)

-- Unusual name on purpose so it never collides with a "Remotes" folder already in the place.
local FOLDER_NAME = "BattlegroundsRemotes"

local Net = {}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		for _, name in Remotes do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = created
		end
		created.Parent = ReplicatedStorage
		folder = created
		return created
	end
	local found = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	folder = found
	return found
end

function Net.remote(name: Remotes.RemoteName): RemoteEvent
	return getFolder():WaitForChild(name) :: RemoteEvent
end

return Net
