AddCSLuaFile "shared.lua"
include "shared.lua"

local urllib = url

function SERVICE:GetMetadata( callback )

	if self._metadata then
		callback( self._metadata )
		return
	end

	local channel = self:GetTwitchChannel()
	local metadata = {
		title = ("Twitch.TV Stream: %s"):format(channel),
		thumbnail = ("https://static-cdn.jtvnw.net/previews-ttv/live_user_%s-1280x720.jpg"):format(channel)
	}

	self:SetMetadata(metadata, true)

	callback(self._metadata)

end