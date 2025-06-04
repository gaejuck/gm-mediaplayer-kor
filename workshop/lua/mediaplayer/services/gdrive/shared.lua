DEFINE_BASECLASS( "mp_service_base" )

SERVICE.Name 	= "Google Drive"
SERVICE.Id 		= "gd"
SERVICE.Base 	= "browser"

SERVICE.PrefetchMetadata = true

function SERVICE:New( url )
	local obj = BaseClass.New(self, url)
	obj._data = obj:GetGoogleDriveId()
	return obj
end

function SERVICE:Match( url )
	return url:match("drive.google.com")
end

function SERVICE:IsTimed()
	if self._istimed == nil then
		self._istimed = self:Duration() > 0
	end

	return self._istimed
end

function SERVICE:GetGoogleDriveId()

	local videoId

	if self.videoId then

		videoId = self.videoId

	elseif self.urlinfo then

		local url = self.urlinfo

		-- https://drive.google.com/file/d/(fileId)
		if url.path and url.path:match("^/file/d/([%a%d-_]+)/") then
			videoId = url.path:match("^/file/d/([%a%d-_]+)/")
		end

		self.videoId = videoId

	end

	return videoId

end
