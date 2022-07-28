include "shared.lua"

DEFINE_BASECLASS( "mp_service_browser" )

function SERVICE:GetURL()
	local videoId = self:GetDailymotionVideoId()
	return ("https://www.dailymotion.com/embed/video/%s?rel=0&autoplay=1"):format( videoId )
end

do -- Media Hook
	local JS_Interface = [[
		var checkerInterval = setInterval(function() {
			if (document.querySelector(".np_DialogConsent-accept")) {
				document.querySelector(".np_DialogConsent-accept").click();
			}

			var player = document.querySelector("video#dmp_Video");
			if (!!player && player.paused == false && player.readyState == 4) {
				clearInterval(checkerInterval);

				window.MediaPlayer = player;
			}
		}, 50)
	]]

	function SERVICE:OnBrowserReady( browser )

		BaseClass.OnBrowserReady( self, browser )

		browser:OpenURL( self:GetURL() )
		browser.OnDocumentReady = function(pnl)
			browser:RunJavascript( JS_Interface )
		end

	end
end

do	-- Media Controls
	local JS_Pause = "if(window.MediaPlayer) MediaPlayer.pause();"
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
end