AddCSLuaFile "shared.lua"
include "shared.lua"

local APIUrl = "https://api.bitchute.com/api/beta/video"

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
		MediaPlayer.Metadata:Save(self)
		callback(self._metadata)
	else
		local videoId = self:GetBitChuteVideoId()

		self:FetchVideoAPI( videoId, callback )
	end
end

function SERVICE:FetchVideoAPI( videoId, callback )
	local postData = util.TableToJSON({
		video_id = videoId
	})

	local request = {
		url = APIUrl,
		method = "POST",
		body = postData,
		type = "application/json",

		success = function( code, body, headers )
			if MediaPlayer.DEBUG then
				print("BitChute Video API Results["..code.."]:", APIUrl)
				print(body)
			end

			local response = util.JSONToTable( body )
			if not response then
				callback(false, "Failed to parse BitChute API response")
				return
			end

			local metadata = self:ParseVideoAPIResponse(response)

			if not metadata.title then
				callback(false, "Failed to get video metadata from BitChute API")
				return
			end

			self:SetMetadata(metadata, true)
			MediaPlayer.Metadata:Save(self)
			callback(self._metadata)
		end,

		failed = function( err )
			callback(false, "Failed to fetch BitChute video metadata: " .. tostring(err))
		end
	}

	request.headers = {
		["Content-Type"] = "application/json",
		["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
	}

	if MediaPlayer.DEBUG then
		print("BitChute Video API Request for ID:", videoId)
		PrintTable(request)
	end

	HTTP(request)
end

function SERVICE:ParseDuration( timeStr )
	if not timeStr or timeStr == "" then
		return -1
	end

	local tbl = {}

	-- Extract numeric fragments in reverse order
	for fragment in string.gmatch(timeStr, ":?(%d+)") do
		table.insert(tbl, 1, tonumber(fragment) or 0)
	end

	if #tbl == 0 then
		return -1
	end

	local seconds = 0

	-- Convert to seconds using powers of 60
	for i = 1, #tbl do
		seconds = seconds + tbl[i] * math.max(60 ^ (i-1), 1)
	end

	return seconds
end

function SERVICE:ParseVideoAPIResponse( response )
	local metadata = {}

	if response.video_name then
		metadata.title = response.video_name
	end

	if response.thumbnail_url then
		metadata.thumbnail = response.thumbnail_url
	end

	if response.duration and isstring(response.duration) then
		metadata.duration = self:ParseDuration(response.duration)
	end

	return metadata
end