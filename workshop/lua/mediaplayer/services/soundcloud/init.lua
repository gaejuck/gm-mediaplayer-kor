AddCSLuaFile "shared.lua"
include "shared.lua"

function SERVICE:GetMetadata( callback )
	if self._metadata then
		callback( self._metadata )
		return
	end

	local cache = MediaPlayer.Metadata:Query(self)

	if MediaPlayer.DEBUG then
		print("MediaPlayer.GetMetadata Cache results:")
		PrintTable(cache or {})
	end

	if cache then

		local metadata = {}
		metadata.title = cache.title
		metadata.duration = tonumber(cache.duration)

		self:SetMetadata(metadata)
		MediaPlayer.Metadata:Save(self)

		callback(self._metadata)

	else

		local metadata = {}

		-- Title & Duration is taken from Client via PreRequest
		metadata.title = self._metaTitle
		metadata.duration = self._metaDuration

		self:SetMetadata(metadata, true)
		MediaPlayer.Metadata:Save(self)

		callback(self._metadata)
	end
end

function SERVICE:NetReadRequest()

	if not self.PrefetchMetadata then return end

	self._metaTitle = net.ReadString()
	self._metaDuration = net.ReadUInt( 16 )

end