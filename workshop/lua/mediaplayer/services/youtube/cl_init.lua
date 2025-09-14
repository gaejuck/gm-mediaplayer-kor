include "shared.lua"

DEFINE_BASECLASS( "mp_service_browser" )

--[[
	Workaround with a Metadata parser made by veitikka (https://github.com/veitikka)
	Src: https://github.com/samuelmaddock/gm-mediaplayer/pull/34
--]]

local JS_Pause = [[
	if(window.MediaPlayer) {
		MediaPlayer.pause()
		mp_paused = true
	} 
]]
local JS_Play = [[
	if(window.MediaPlayer) {
		MediaPlayer.play();
		mp_paused = false
	} 
]]
local JS_Volume = [[
	if (window.MediaPlayer) {
		MediaPlayer.volume = %s;
	}
]]

local JS_Seek = [[
	if (window.MediaPlayer) {
		var seekTime = %s;
		var curTime = window.MediaPlayer.currentTime;

		var diffTime = Math.abs(curTime - seekTime);
		if (diffTime > 5) {
			window.MediaPlayer.currentTime = seekTime
		}
	}
]]

local WATCH_URL = "https://purrcoding-mediaplayer.pages.dev/youtube.html?v=%s"
local API_URL = "https://www.youtube.com/watch?v=%s"

---
-- Helper function for converting ISO 8601 time strings, this is the formatting
-- used for duration specified in the YouTube v3 API.
--
-- http://stackoverflow.com/a/22149575/1490006
--
local function convertISO8601Time( duration )
	local a = {}

	for part in string.gmatch(duration, "%d+") do
	   table.insert(a, part)
	end

	if duration:find('M') and not (duration:find('H') or duration:find('S')) then
		a = {0, a[1], 0}
	end

	if duration:find('H') and not duration:find('M') then
		a = {a[1], 0, a[2]}
	end

	if duration:find('H') and not (duration:find('M') or duration:find('S')) then
		a = {a[1], 0, 0}
	end

	duration = 0

	if #a == 3 then
		duration = duration + tonumber(a[1]) * 3600
		duration = duration + tonumber(a[2]) * 60
		duration = duration + tonumber(a[3])
	end

	if #a == 2 then
		duration = duration + tonumber(a[1]) * 60
		duration = duration + tonumber(a[2])
	end

	if #a == 1 then
		duration = duration + tonumber(a[1])
	end

	return duration
end

---
-- Get the value for an attribute from a html element
--
local function ParseElementAttribute( element, attribute )
	if not element then return end
	-- Find the desired attribute
	local output = string.match( element, attribute .. "%s-=%s-%b\"\"" )
	if not output then return end
	-- Remove the 'attribute=' part
	output = string.gsub( output, attribute .. "%s-=%s-", "" )
	-- Trim the quotes around the value string
	return string.sub( output, 2, -2 )
end

---
-- Get the contents of a html element by removing tags
-- Used as fallback for when title cannot be found
--
local function ParseElementContent( element )
	if not element then return end
	-- Trim start
	local output = string.gsub( element, "^%s-<%w->%s-", "" )
	-- Trim end
	return string.gsub( output, "%s-</%w->%s-$", "" )
end

-- Lua search patterns to find metadata from the html
local patterns = {
	["title"] = "<meta%sproperty=\"og:title\"%s-content=%b\"\">",
	["title_fallback"] = "<title>.-</title>",
	["duration"] = "<meta%sitemprop%s-=%s-\"duration\"%s-content%s-=%s-%b\"\">",
	["live"] = "<meta%sitemprop%s-=%s-\"isLiveBroadcast\"%s-content%s-=%s-%b\"\">",
	["live_enddate"] = "<meta%sitemprop%s-=%s-\"endDate\"%s-content%s-=%s-%b\"\">",
	["age_restriction"] = "<meta%sproperty=\"og:restrictions:age\"%s-content=%b\"\">"
}

---
-- Function to parse video metadata straight from the html instead of using the API
--
local function ParseMetaDataFromHTML( html )
	--MetaData table to return when we're done
	local metadata, html = {}, html

	-- Fetch title, with fallbacks if needed
	metadata.title = ParseElementAttribute(html:match(patterns["title"]), "content")
		or ParseElementContent(html:match(patterns["title_fallback"]))

	-- Parse HTML entities in the title into symbols
	metadata.title = url.htmlentities_decode(metadata.title)

	metadata.familyfriendly = ParseElementAttribute(html:match(patterns["age_restriction"]), "content") or ""

	-- See if the video is an ongoing live broadcast
	-- Set duration to 0 if it is, otherwise use the actual duration
	local isLiveBroadcast = tobool(ParseElementAttribute(html:match(patterns["live"]), "content"))
	local broadcastEndDate = html:match(patterns["live_enddate"])
	if isLiveBroadcast and not broadcastEndDate then
		-- Mark as live video
		metadata.duration = 0
	else
		local durationISO8601 = ParseElementAttribute(html:match(patterns["duration"]), "content")
		if isstring(durationISO8601) then
			metadata.duration = math.max(1, convertISO8601Time(durationISO8601))
		end
	end

	return metadata
end

function SERVICE:OnBrowserReady( browser )

	-- Resume paused player
	if self._YTPaused then
		self.Browser:RunJavascript( JS_Play )
		self._YTPaused = nil
		return
	end

	BaseClass.OnBrowserReady( self, browser )

	local videoId = self:GetYouTubeVideoId()
	local curTime = self:CurrentTime()
	local url = WATCH_URL:format(videoId)

	-- Add start time to URL if the video didn't just begin
	-- if self:IsTimed() and curTime > 3 then
	-- 	url = url .. "&t=" .. math.Round(curTime)
	-- end

	browser:OpenURL( url )

end

function SERVICE:Pause()
	BaseClass.Pause( self )

	if IsValid(self.Browser) then
		self.Browser:RunJavascript(JS_Pause)
		self._YTPaused = true
	end

end

function SERVICE:SetVolume( volume )
	local js = JS_Volume:format( volume )
	self.Browser:RunJavascript(js)
end

function SERVICE:Sync()

	local seekTime = self:CurrentTime()
	if IsValid(self.Browser) and self:IsTimed() and seekTime > 0 then
		self.Browser:RunJavascript(JS_Seek:format(seekTime))
	end
end

function SERVICE:IsMouseInputEnabled()
	return IsValid( self.Browser )
end

do	-- Metadata Prefech
	function SERVICE:PreRequest( callback )

		local videoId = self:GetYouTubeVideoId()

		http.Fetch(API_URL:format(videoId), function(body, length, headers, code)
			if not body or code ~= 200 then
				callback(("Not expected response received from YouTube (Code: %d)"):format(code))
				return
			end

			local status, metadata = pcall(ParseMetaDataFromHTML, body)
			if not status  then
				callback("Failed to parse MetaData from YouTube")
				return
			end

			self._metaTitle = metadata.title
			self._metaDuration = metadata.duration
			callback()
		end, function(error)
			callback(("YouTube Error: %s"):format(error))
		end, {})
	end

	function SERVICE:NetWriteRequest()
		net.WriteString( self._metaTitle )
		net.WriteUInt( self._metaDuration, 16 )
	end
end
