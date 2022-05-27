DEFINE_BASECLASS( "mp_service_base" )

SERVICE.Name 	= "Dailymotion"
SERVICE.Id 		= "dm"
SERVICE.Base 	= "browser"

function SERVICE:New( url )
	local obj = BaseClass.New(self, url)
	obj._data = obj:GetDailymotionVideoId()
	return obj
end

function SERVICE:Match( url )
	return string.find( url, "dailymotion.com/video/([%a%d-_]+)")
end

function SERVICE:GetDailymotionVideoId()

	local videoId

	if self.videoId then

		videoId = self.videoId

	elseif self.urlinfo then

		local url = self.urlinfo

		-- https://www.dailymotion.com/(videoId)
		videoId = string.match(url.path, "^/video/([%a%d-_]+)")

		self.videoId = videoId

	end

	return videoId

end
