include "shared.lua"

DEFINE_BASECLASS( "mp_service_browser" )

local TwitchUrl = "https://player.twitch.tv/?channel=%s&parent=pixeltailgames.com"

-- JS Snippet taken from the Cinema (Fixed Edition)
-- https://github.com/FarukGamer/cinema
local JS_Inferface = [[
	function testSelector(elem, dataStr) {
		var data = document.querySelectorAll( elem + "[data-test-selector]")
		for (let i=0; i<data.length; i++) {
			var selector = data[i].dataset.testSelector
			if (!!selector && selector === dataStr) {
				return data[i]
				break
			}
		}
	}

	function target(dataStr) {
		var data = document.querySelectorAll( "button[data-a-target]")
		for (let i=0; i<data.length; i++) {
			var selector = data[i].dataset.aTarget
			if (!!selector && selector === dataStr) {
				return data[i]
				break
			}
		}
	}

	function check() {
		var mature = target("player-overlay-mature-accept")
		if (!!mature) {mature.click(); return;}

		var player = document.getElementsByTagName('video')[0];
		if (!testSelector("div", "sad-overlay") && !!player && player.paused == false && player.readyState == 4) {
			clearInterval(checkerInterval);

			window.MediaPlayer = player;
		}
	}
	var checkerInterval = setInterval(check, 50);
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
		self.Browser:RunJavascript("if(window.MediaPlayer) MediaPlayer.pause();")
		self._YTPaused = true
	end

end

function SERVICE:SetVolume( volume )
	local js = ("if(window.MediaPlayer) MediaPlayer.volume = %s;"):format( MediaPlayer.Volume() )
	self.Browser:RunJavascript(js)
end