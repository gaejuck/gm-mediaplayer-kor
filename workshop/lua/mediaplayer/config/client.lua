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
		base_url = "https://gaejuck.github.io/gm-mediaplayer-kor/public/"

	},

	---
	-- Request menu
	--
	request = {

		---
		-- URL of the request menu.
		-- @type String
		--
		url = "https://gaejuck.github.io/gm-mediaplayer-kor/public/request.html"

	},

	---
	-- YoutTube player
	--
	youtube = {

		---
		-- URL where the YouTube player is located.
		-- @type String
		--
		url = "https://gaejuck.github.io/gm-mediaplayer-kor/public/youtube.html",
		url_meta = "https://gaejuck.github.io/gm-mediaplayer-kor/public/youtube_meta.html",

	}

})
