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
		var player = document.querySelector("video#player_one_html5_api");
		var playBtn = document.querySelector(".vjs-big-play-button.vjs-bp-block");

		if (!!playBtn) {
			playBtn.click();
			return;
		}

		if (!playBtn && !!player && player.readyState == 4) {
			clearInterval(checkerInterval);

			window.MediaPlayer = player;
		}
	}, 50);
]]

function SERVICE:GetURL()
	local videoId = self:GetBitChuteVideoId()
	return ("https://www.bitchute.com/embed/%s"):format( videoId )
end

function SERVICE:OnBrowserReady( browser )

	-- Resume paused player
	if self._BCPaused then
		self.Browser:RunJavascript( JS_Play )
		self._BCPaused = nil
		return
	end

	BaseClass.OnBrowserReady( self, browser )

	local url = self:GetURL()

	browser:OpenURL( url )
	browser.OnDocumentReady = function(pnl)
		browser:QueueJavascript( JS_Interface )
	end

end

function SERVICE:Pause()
	BaseClass.Pause( self )

	if IsValid(self.Browser) then
		self.Browser:RunJavascript(JS_Pause)
		self._BCPaused = true
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