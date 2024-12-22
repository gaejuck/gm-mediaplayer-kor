include "shared.lua"

DEFINE_BASECLASS( "mp_service_browser" )

local JS_Pause = "if(window.MediaPlayer) MediaPlayer.pause();"
local JS_Play = "if(window.MediaPlayer) MediaPlayer.play();"
local JS_Volume = "if(window.MediaPlayer) MediaPlayer.volume = %s;"
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

local JS_Interface = [[
	var checkerInterval = setInterval(function() {
		var player = document.getElementById("movie_player") || document.getElementsByClassName("html5-video-player")[0];

		if (!!player) {
			clearInterval(checkerInterval);

			{ // Native video controll
				player.volume = 0;
				player.currentTime = 0;
				player.duration = player.getDuration();

				Object.defineProperty(player, "volume", {
					get() {
						return player.getVolume();
					},
					set(volume) {
						if (player.isMuted()) {
							player.unMute();
						}
						player.setVolume(volume * 100);
					},
				});

				Object.defineProperty(player, "currentTime", {
					get() {
						return Number(player.getCurrentTime());
					},
					set(time) {
						player.seekTo(time, true);
					},
				});
			}

			{ // Player resizer
				document.body.appendChild(player);

				player.style.backgroundColor = "#000";
				player.style.height = "100vh";
				player.style.left = '0px';
				player.style.width = '100%';

				let countAmt = 0
				let resizeTimer = setInterval(function() {

					for (const elem of document.getElementsByClassName("watch-skeleton")) { elem.remove(); }
					for (const elem of document.getElementsByTagName("ytd-app")) { elem.remove(); }
					for (const elem of document.getElementsByClassName("skeleton")) { elem.remove(); }

					player.setInternalSize("100vw", "100vh");
					document.body.style.overflow = "hidden";

					countAmt++;

					if (countAmt > 100) {
						clearInterval(resizeTimer);
					}
       			}, 10);
			}

			window.MediaPlayer = player;
		}
	}, 50);
]]

local EMBED_URL = "https://www.youtube.com/watch?v=%s"
local ADBLOCK_JS = "" -- see end of file (https://github.com/Vendicated/Vencord/blob/main/src/plugins/youtubeAdblock.desktop/adguard.js - #d199603)

---
-- Helper function for converting ISO 8601 time strings; this is the formatting
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
	local output = string.match( element, attribute.."%s-=%s-%b\"\"" )
	if not output then return end
	-- Remove the 'attribute=' part
	output = string.gsub( output, attribute.."%s-=%s-", "" )
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
	local url = EMBED_URL:format(videoId)

	-- Add start time to URL if the video didn't just begin
	if self:IsTimed() and curTime > 3 then
		url = url .. "&t=" .. math.Round(curTime)
	end

	browser:OpenURL( url )
	browser.OnDocumentReady = function(pnl)
		browser:RunJavascript(ADBLOCK_JS)

		browser:QueueJavascript( JS_Interface )
	end

end

function SERVICE:Pause()
	BaseClass.Pause( self )

	if IsValid(self.Browser) then
		self.Browser:RunJavascript(JS_Pause)
		self._YTPaused = true
	end

end

function SERVICE:SetVolume( volume )
	local js = JS_Volume:format( MediaPlayer.Volume() )
	self.Browser:RunJavascript(js)
end

function SERVICE:Sync()

	local seekTime = self:CurrentTime()
	if self:IsTimed() and seekTime > 0 then
		self.Browser:RunJavascript(JS_Seek:format(seekTime))
	end
end

function SERVICE:IsMouseInputEnabled()
	return IsValid( self.Browser )
end

do	-- Metadata Prefech
	function SERVICE:PreRequest( callback )

		local videoId = self:GetYouTubeVideoId()

		http.Fetch(EMBED_URL:format(videoId), function(body, length, headers, code)
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

ADBLOCK_JS = [[
const hiddenCSS=["#__ffYoutube1","#__ffYoutube2","#__ffYoutube3","#__ffYoutube4","#feed-pyv-container","#feedmodule-PRO","#homepage-chrome-side-promo","#merch-shelf","#offer-module",'#pla-shelf > ytd-pla-shelf-renderer[class="style-scope ytd-watch"]',"#pla-shelf","#premium-yva","#promo-info","#promo-list","#promotion-shelf","#related > ytd-watch-next-secondary-results-renderer > #items > ytd-compact-promoted-video-renderer.ytd-watch-next-secondary-results-renderer","#search-pva","#shelf-pyv-container","#video-masthead","#watch-branded-actions","#watch-buy-urls","#watch-channel-brand-div","#watch7-branded-banner","#YtKevlarVisibilityIdentifier","#YtSparklesVisibilityIdentifier",".carousel-offer-url-container",".companion-ad-container",".GoogleActiveViewElement",'.list-view[style="margin: 7px 0pt;"]',".promoted-sparkles-text-search-root-container",".promoted-videos",".searchView.list-view",".sparkles-light-cta",".watch-extra-info-column",".watch-extra-info-right",".ytd-carousel-ad-renderer",".ytd-compact-promoted-video-renderer",".ytd-companion-slot-renderer",".ytd-merch-shelf-renderer",".ytd-player-legacy-desktop-watch-ads-renderer",".ytd-promoted-sparkles-text-search-renderer",".ytd-promoted-video-renderer",".ytd-search-pyv-renderer",".ytd-video-masthead-ad-v3-renderer",".ytp-ad-action-interstitial-background-container",".ytp-ad-action-interstitial-slot",".ytp-ad-image-overlay",".ytp-ad-overlay-container",".ytp-ad-progress",".ytp-ad-progress-list",'[class*="ytd-display-ad-"]','[layout*="display-ad-"]','a[href^="http://www.youtube.com/cthru?"]','a[href^="https://www.youtube.com/cthru?"]',"ytd-action-companion-ad-renderer","ytd-banner-promo-renderer","ytd-compact-promoted-video-renderer","ytd-companion-slot-renderer","ytd-display-ad-renderer","ytd-promoted-sparkles-text-search-renderer","ytd-promoted-sparkles-web-renderer","ytd-search-pyv-renderer","ytd-single-option-survey-renderer","ytd-video-masthead-ad-advertiser-info-renderer","ytd-video-masthead-ad-v3-renderer","YTM-PROMOTED-VIDEO-RENDERER"],hideElements=()=>{if(!hiddenCSS)return;const e=hiddenCSS.join(", ")+" { display: none!important; }",r=document.createElement("style");r.textContent=e,document.head.appendChild(r)},observeDomChanges=e=>{new MutationObserver((r=>{e(r)})).observe(document.documentElement,{childList:!0,subtree:!0})},hideDynamicAds=()=>{const e=document.querySelectorAll("#contents > ytd-rich-item-renderer ytd-display-ad-renderer");0!==e.length&&e.forEach((e=>{if(e.parentNode&&e.parentNode.parentNode){const r=e.parentNode.parentNode;"ytd-rich-item-renderer"===r.localName&&(r.style.display="none")}}))},autoSkipAds=()=>{if(document.querySelector(".ad-showing")){const e=document.querySelector("video");e&&e.duration&&(e.currentTime=e.duration,setTimeout((()=>{const e=document.querySelector("button.ytp-ad-skip-button");e&&e.click()}),100))}},overrideObject=(e,r,t)=>{if(!e)return!1;let o=!1;for(const d in e)e.hasOwnProperty(d)&&d===r?(e[d]=t,o=!0):e.hasOwnProperty(d)&&"object"==typeof e[d]&&overrideObject(e[d],r,t)&&(o=!0);return o},jsonOverride=(e,r)=>{const t=JSON.parse;JSON.parse=(...o)=>{const d=t.apply(this,o);return overrideObject(d,e,r),d},Response.prototype.json=new Proxy(Response.prototype.json,{async apply(...t){const o=await Reflect.apply(...t);return overrideObject(o,e,r),o}})};jsonOverride("adPlacements",[]),jsonOverride("playerAds",[]),hideElements(),hideDynamicAds(),autoSkipAds(),observeDomChanges((()=>{hideDynamicAds(),autoSkipAds()}));
]]