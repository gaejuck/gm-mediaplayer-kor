include "shared.lua"

DEFINE_BASECLASS( "mp_service_browser" )

local TwitchUrl = "https://player.twitch.tv/?channel=%s&parent=pixeltailgames.com"

local JS_Pause = "if(window.MediaPlayer) MediaPlayer.pause();"
local JS_Volume = "if(window.MediaPlayer) MediaPlayer.volume = %s;"

-- JS Snippet taken from the Cinema (Fixed Edition)
-- https://github.com/FarukGamer/cinema
local JS_Inferface = [[
	var checkerInterval = setInterval(function() {
		var matureAccept = document.querySelectorAll("[data-a-target=\"player-overlay-mature-accept\"]")[0]
		if (!!matureAccept) {matureAccept.click(); return;}

		var player = document.getElementsByTagName('video')[0];
		var adOverlay = document.querySelectorAll("[data-test-selector=\"sad-overlay\"]")[0]

		if (!adOverlay && !!player && player.paused == false && player.readyState == 4) {
			clearInterval(checkerInterval);

			window.MediaPlayer = player;
		}
	}, 50)
]]

function SERVICE:OnBrowserReady( browser )

	BaseClass.OnBrowserReady( self, browser )

	local channel = self:GetTwitchChannel()
	local url = TwitchUrl:format(channel)

	browser:OpenURL( url )
	browser.OnDocumentReady = function(pnl)
		browser:QueueJavascript( JS_Inferface )
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