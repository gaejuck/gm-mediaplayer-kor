DEFINE_BASECLASS( "mp_service_base" )

SERVICE.Name 	= "Internet Archive"
SERVICE.Id 		= "ia"
SERVICE.Base 	= "browser"

function SERVICE:New( url )
	local obj = BaseClass.New(self, url)
	obj._data = obj:GetArchiveVideoId()
	return obj
end

function SERVICE:Match( url )
	return string.find( url, "archive.org" )
end

function SERVICE:GetArchiveVideoId()

	local videoId

	if self.videoId then

		videoId = self.videoId

	elseif self.urlinfo then

		local url = self.urlinfo

		local identifier = url.path:match("^/details/([%w%-%._]+)")
		if identifier then
			local file = ("^/details/%s/([%%w%%-%%.%%/%%+%%&_]+)"):format(identifier)
			file = url.path:match(file)

			self.videoId = ("%s%s"):format(identifier, file and "," .. file or "")
		end

	end

	return videoId

end
