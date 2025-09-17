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
		base_url = "https://gm-mediaplayer.netlify.app/"

	},

	---
	-- Request menu
	--
	request = {

		---
		-- URL of the request menu.
		-- @type String
		--
		url = "https://gm-mediaplayer.netlify.app/request.html"

	},

	---
	-- YoutTube player
	--
	youtube = {

		---
		-- URL where the YouTube player is located.
		-- @type String
		--
		url = "https://gm-mediaplayer.netlify.app/youtube.html"

	}

})
