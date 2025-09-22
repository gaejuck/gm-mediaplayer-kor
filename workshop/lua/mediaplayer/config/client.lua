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
		base_url = "http://gaez.uk/gm-mediaplayer-kor/"

	},

	---
	-- Request menu
	--
	request = {

		---
		-- URL of the request menu.
		-- @type String
		--
		url = "http://gaez.uk/gm-mediaplayer-kor/request.html"

	},

	---
	-- YoutTube player
	--
	youtube = {

		---
		-- URL where the YouTube player is located.
		-- @type String
		--
		url = "http://gaez.uk/gm-mediaplayer-kor/youtube.html",
		url_meta = "http://gaez.uk/gm-mediaplayer-kor/youtube_meta.html",

	}

})
