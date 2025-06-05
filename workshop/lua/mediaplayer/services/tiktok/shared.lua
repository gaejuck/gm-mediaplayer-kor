DEFINE_BASECLASS( "mp_service_base" )

SERVICE.Name 	= "TikTok"
SERVICE.Id 		= "tt"
SERVICE.Base 	= "browser"

SERVICE.PrefetchMetadata = true

function SERVICE:New( url )
	local obj = BaseClass.New(self, url)
	obj._data = obj:GetMediaID()
	return obj
end

function SERVICE:Match( url )
	return url:match("tiktok.com")
end

function SERVICE:IsTimed()
	if self._istimed == nil then
		self._istimed = self:Duration() > 0
	end

	return self._istimed
end

function SERVICE:GetMediaID()

	local videoId

	if self.videoId then

		videoId = self.videoId

	elseif self.urlinfo then

		local url = self.urlinfo

		-- https://drive.google.com/file/d/(fileId)
		if url.path and url.path:match("/@[%a%w%d%_%.]+/video/(%d+)$") then
			videoId = url.path:match("/@[%a%w%d%_%.]+/video/(%d+)$")
		end

		self.videoId = videoId

	end

	return videoId

end
