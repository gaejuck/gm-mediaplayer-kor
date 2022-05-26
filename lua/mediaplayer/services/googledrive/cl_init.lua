include "shared.lua"

DEFINE_BASECLASS( "mp_service_browser" )

function SERVICE:GetURL()
	local fileId = self:GetGoogleDriveFileId()
	return ("https://drive.google.com/uc?export=open&confirm=yTib&id=%s"):format( fileId )
end

do -- Media Hook
	local JS_Interface = [[
		var checkerInterval = setInterval(function() {
			var player = document.getElementsByTagName('video')[0];
			if (!!player && player.paused == false && player.readyState == 4) {
				clearInterval(checkerInterval);

				document.body.style.backgroundColor = "black";
				window.MediaPlayer = player;
			}
		}, 50)
	]]

	function SERVICE:OnBrowserReady( browser )

		BaseClass.OnBrowserReady( self, browser )

		browser:OpenURL( self:GetURL() )
		browser.OnDocumentReady = function( pnl )
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

do	-- Metadata Prefech
	function SERVICE:PreRequest( callback )
		MediaPlayerUtils.GatherVideoDuration(self:GetURL(), function(success, response)
			if success then
				self._metaDuration = response
				callback()

				return
			end

			callback(response or "Something went wrong during Gathering.")
		end)
	end

	function SERVICE:NetWriteRequest()
		net.WriteUInt( self._metaDuration, 16 )
	end
end