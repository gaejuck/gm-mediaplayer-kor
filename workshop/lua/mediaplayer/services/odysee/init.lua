AddCSLuaFile "shared.lua"
include "shared.lua"

function SERVICE:GetMetadata( callback )
	if self._metadata then
		callback( self._metadata )
		return
	end

	local cache = MediaPlayer.Metadata:Query(self)

	if cache then
		local metadata = {}
		metadata.title = cache.title
		metadata.duration = tonumber(cache.duration)
		metadata.thumbnail = cache.thumbnail

		self:SetMetadata(metadata)

		if self:IsTimed() then
			MediaPlayer.Metadata:Save(self)
		end

		callback(self._metadata)
	else
		-- First try to fetch HTML for video metadata
		self:Fetch( self.url,
			function( body, length, headers, code )
				local status, metadata = pcall(self.ParseOdyseeHTML, self, body)

				if status and metadata.title then
					-- Successfully parsed video metadata
					self:SetMetadata(metadata, true)

					if self:IsTimed() then
						MediaPlayer.Metadata:Save(self)
					end

					callback(self._metadata)
				else
					-- Failed to parse HTML, try oEmbed (likely a livestream)
					self:FetchOEmbedMetadata(callback)
				end
			end,
			function( reason )
				-- HTML fetch failed, try oEmbed as fallback
				self:FetchOEmbedMetadata(callback)
			end
		)
	end
end

function SERVICE:ParseOdyseeHTML( html )
	-- Try to find the JSON-LD script tag first (for videos)
	local jsonLdPattern = '<script type="application/ld%+json">(.-)</script>'
	local jsonData = string.match(html, jsonLdPattern)

	if jsonData then
		-- Parse video metadata from JSON-LD (for regular videos)
		local videoData = util.JSONToTable(jsonData)
		if videoData and videoData["@type"] == "VideoObject" then
			local metadata = {}

			metadata.title = videoData.name or "Odysee Video"
			metadata.title = string.gsub(metadata.title, "&quot;", '"')
			metadata.title = string.gsub(metadata.title, "&amp;", '&')
			metadata.title = string.gsub(metadata.title, "&lt;", '<')
			metadata.title = string.gsub(metadata.title, "&gt;", '>')

			if videoData.duration then
				metadata.duration = self:ParseISO8601Duration(videoData.duration)
			else
				metadata.duration = -1
			end

			metadata.thumbnail = videoData.thumbnailUrl or ""
			metadata.embedUrl = videoData.embedUrl or ""

			return metadata
		end
	end

	-- If no JSON-LD found, this is likely a livestream - use oEmbed
	error("No JSON-LD found, attempting oEmbed")
end

function SERVICE:FetchOEmbedMetadata( callback )
	local oembedUrl = "https://odysee.com/$/oembed?url=" .. self.url .. "&format=json"

	self:Fetch( oembedUrl,
		function( body, length, headers, code )
			local status, metadata = pcall(self.ParseOEmbedMetadata, self, body)

			if not status or not metadata.title then
				callback(false, "Failed to parse Odysee oEmbed metadata: " .. tostring(metadata))
				return
			end

			self:SetMetadata(metadata, true)
			callback(self._metadata)
		end,
		function( reason )
			callback(false, "Failed to fetch Odysee oEmbed metadata [reason="..tostring(reason).."]")
		end
	)
end

function SERVICE:ParseOEmbedMetadata( body )
	local response = util.JSONToTable( body )
	if not response then
		error("Invalid oEmbed JSON response")
	end

	local metadata = {}
	metadata.title = response.title or "Odysee Livestream"
	metadata.thumbnail = response.thumbnail_url or ""
	metadata.duration = 0 -- Livestreams have no duration (infinite)

	return metadata
end

function SERVICE:ParseISO8601Duration( duration )
	if not duration or not string.match(duration, "^PT") then
		return -1
	end

	local totalSeconds = 0

	-- Extract hours, minutes, seconds
	local hours = string.match(duration, "(%d+)H")
	local minutes = string.match(duration, "(%d+)M")
	local seconds = string.match(duration, "(%d+)S")

	if hours then totalSeconds = totalSeconds + (tonumber(hours) * 3600) end
	if minutes then totalSeconds = totalSeconds + (tonumber(minutes) * 60) end
	if seconds then totalSeconds = totalSeconds + tonumber(seconds) end

	return totalSeconds > 0 and totalSeconds or -1
end