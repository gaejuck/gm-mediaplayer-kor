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
		base_url = "https://gaejuck.github.io/gm-mediaplayer-kor/"

	},

	---
	-- Request menu
	--
	request = {

		---
		-- URL of the request menu.
		-- @type String
		--
		url = "https://gaejuck.github.io/gm-mediaplayer-kor/request.html"

	},

	---
	-- YoutTube player
	--
	youtube = {

		---
		-- URL where the YouTube player is located.
		-- @type String
		--
		url = "https://gaejuck.github.io/gm-mediaplayer-kor/youtube.html",
		url_meta = "https://gaejuck.github.io/gm-mediaplayer-kor/youtube_meta.html",

	}

})
