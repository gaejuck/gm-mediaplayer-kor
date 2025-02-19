SERVICE.Name 	= "Resource"
SERVICE.Id 		= "res"
SERVICE.Base 	= "browser"
SERVICE.Abstract = true

SERVICE.FileExtensions = {}

function SERVICE:Match( url )
	-- check supported file extensions
	local ext = string.GetExtensionFromFilename(url)
	if ext and ext:match("(.[^?]+)") then
		ext = ext:match("(.[^?]+)")

		for _, ext2 in pairs(self.FileExtensions) do
			if ext == ext2 then
				return true
			end
		end
	end

	return false
end

function SERVICE:IsTimed()
	return false
end
