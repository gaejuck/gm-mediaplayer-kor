AddCSLuaFile "shared.lua"
include "shared.lua"

local MetadataUrl = "https://archive.org/metadata/%s/files/"
local DownloadUrl = "https://cors.archive.org/download/%s/%s"
local FallbackThumbnail = "https://cataas.com/cat?width=1280&height=720"

local VALID_FORMATS = {
	["MPEG4"] = true,
	["h.264"] = true,
	["h.264 IA"] = true,
	["Ogg Video"] = true,
}

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
		metadata.thumbnail = cache.thumbnail

		self:SetMetadata(metadata)
		MediaPlayer.Metadata:Save(self)

		callback(self._metadata)
	else
		local dataID = string.Explode(",", self:GetArchiveVideoId())
		local identifier, file = dataID[1], ( dataID[2] and dataID[2] or nil )

		local function GetThumbnail(response, file)
			local thumbnail

			for k, v in pairs(response) do
				if not thumbnail and (v.format == "Thumbnail" and v.original == file) then
					thumbnail = v.name
					break
				end
			end

			return thumbnail
		end

		local function onReceive ( body, length, headers, code )
			if not body or code ~= 200 then
				return callback( false, "API request did not succeed." )
			end

			local response = util.JSONToTable(body)
			if not response or not response.result then
				return callback( false, "Failed to parse video's metadata response." )
			end

			response = response.result
			local name, duration

			if file then
				oFile = file
				file = file:Replace("+", " ")
			end

			for k, v in pairs(response) do

				if file then

					if (v.original and v.original == file and VALID_FORMATS[v.format]) then
						name, duration = v.name, v.length
						break
					end

					if (v.name and v.name == oFile and VALID_FORMATS[v.format]) then
						name, duration = v.name, v.length
					end

				else
					if (v.format and VALID_FORMATS[v.format]) then
						name, duration = v.name, v.length
						break
					end
				end
			end

			if not name or not duration then -- Do we have everything that we want?
				return callback( false, "Failed to gather video's dependencies." )
			end

			local metadata, thumbnail = {}, GetThumbnail(response, file or name)
			metadata.title = name
			metadata.duration = math.Round(duration)
			metadata.thumbnail = thumbnail and DownloadUrl:format(identifier, thumbnail) or FallbackThumbnail

			self:SetMetadata(metadata)
			MediaPlayer.Metadata:Save(self)

			callback(self._metadata)
		end

		local apiurl = MetadataUrl:format( identifier )
		self:Fetch(apiurl, onReceive, function( code )
			callback(false, "Failed to load Vimeo [" .. tostring(code) .. "]")
		end)
	end
end
