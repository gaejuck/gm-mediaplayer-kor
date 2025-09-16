--[[----------------------------------------------------------------------------
	Media Player client configuration
------------------------------------------------------------------------------]]
MediaPlayer.SetConfig({

	---
	-- HTML content
	--
	html = {

		---
		-- Base URL where HTML content is located.
		-- @type String
		--
		base_url = "https://purrcoding-mediaplayer.duckdns.org/"

	},

	---
	-- Request menu
	--
	request = {

		---
		-- URL of the request menu.
		-- @type String
		--
		url = "https://purrcoding-mediaplayer.duckdns.org/request.html"

	},

	---
	-- YoutTube player
	--
	youtube = {

		---
		-- URL where the YouTube player is located.
		-- @type String
		--
		url = "https://purrcoding-mediaplayer.duckdns.org/youtube.html"

	}

})
