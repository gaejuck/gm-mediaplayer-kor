DEFINE_BASECLASS( "mp_service_base" )

SERVICE.Name 	= "Odysee"
SERVICE.Id 		= "odysee"
SERVICE.Base 	= "browser"

function SERVICE:New( url )
	local obj = BaseClass.New(self, url)
	obj._data = obj:GetOdyseeVideoId()
	return obj
end

function SERVICE:Match( url )
	return string.match( url, "odysee%.com" ) ~= nil
end

function SERVICE:GetOdyseeVideoId()
	local path = self.urlinfo.path or ""

	-- Extract claim name from URL patterns like:
	-- https://odysee.com/@channel:1/video-title:a
	-- https://odysee.com/video-title:a
	local claimName = string.match(path, "/([^/]+)$")

	if claimName then
		return claimName
	end

	return ""
end

function SERVICE:GetOdyseeChannel()
	return string.match( self.url, "odysee%.com/@([^/]+)/" )
end

function SERVICE:IsTimed()
	return self._metadata and self._metadata.duration and self._metadata.duration > 0
end