DEFINE_BASECLASS( "mp_service_base" )

SERVICE.Name = "BitChute"
SERVICE.Id = "bitchute"
SERVICE.Base = "browser"

function SERVICE:New( url )
	local obj = BaseClass.New(self, url)
	obj._data = obj:GetBitChuteVideoId()
	return obj
end

function SERVICE:Match( url )
	return string.match( url, "www%.bitchute%.com/video/([%w%-_]+)" ) ~= nil
end

function SERVICE:GetBitChuteVideoId()
	return string.match( self.url, "www%.bitchute%.com/video/([%w%-_]+)" )
end

function SERVICE:IsTimed()
	return true
end