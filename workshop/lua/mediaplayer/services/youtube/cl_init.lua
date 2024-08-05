include "shared.lua"

DEFINE_BASECLASS( "mp_service_browser" )

local JS_Pause = "if(window.MediaPlayer) MediaPlayer.pause();"
local JS_Play = "if(window.MediaPlayer) MediaPlayer.play();"
local JS_Volume = "if(window.MediaPlayer) MediaPlayer.volume = %s;"
local JS_Seek = [[
	if (window.MediaPlayer) {
		var seekTime = %s;
		var curTime = window.MediaPlayer.currentTime;

		var diffTime = Math.abs(curTime - seekTime);
		if (diffTime > 5) {
			window.MediaPlayer.currentTime = seekTime
		}
	}
]]

local JS_Interface = [[
	var checkerInterval = setInterval(function() {
		var player = document.getElementsByTagName("VIDEO")[0]
		if (!!player) {
			if (player.paused) {player.play();}
			if (player.paused === false && player.readyState === 4) {
				clearInterval(checkerInterval);

				window.MediaPlayer = player;
				player.style = "width:100%; height: 100%;";
			}
		}
	}, 50);
]]

function SERVICE:OnBrowserReady( browser )

	-- Resume paused player
	if self._YTPaused then
		self.Browser:RunJavascript( JS_Play )
		self._YTPaused = nil
		return
	end

	BaseClass.OnBrowserReady( self, browser )

	local videoId = self:GetYouTubeVideoId()
	local hostname = GetConVar("mediaplayer_invidious_instance"):GetString()
	local url = ("https://%s/embed/%s"):format(hostname, videoId)

	local curTime = self:CurrentTime()

	-- Add start time to URL if the video didn't just begin
	if self:IsTimed() and curTime > 3 then
		url = url .. "?t=" .. math.Round(curTime)
	end

	browser:OpenURL( url )
	browser.OnDocumentReady = function(pnl)
		browser:QueueJavascript( JS_Interface )
	end

end

function SERVICE:Pause()
	BaseClass.Pause( self )

	if IsValid(self.Browser) then
		self.Browser:RunJavascript(JS_Pause)
		self._YTPaused = true
	end

end

function SERVICE:SetVolume( volume )
	local js = JS_Volume:format( MediaPlayer.Volume() )
	self.Browser:RunJavascript(js)
end

function SERVICE:Sync()

	local seekTime = self:CurrentTime()
	if self:IsTimed() and seekTime > 0 then
		self.Browser:RunJavascript(JS_Seek:format(seekTime))
	end
end

function SERVICE:IsMouseInputEnabled()
	return IsValid( self.Browser )
end

do	-- Metadata Prefech
	function SERVICE:PreRequest( callback )

		local videoId = self:GetYouTubeVideoId()
		local hostname = GetConVar("mediaplayer_invidious_instance"):GetString()
		local url = ("https://%s/api/v1/videos/%s"):format(hostname, videoId)

		http.Fetch(url, function(body, length, headers, code)
			if not body or code ~= 200 then
				callback("Not expected response received from API (Try diffrent Instance)")
				return
			end

			local response = util.JSONToTable(body)
			if not response then
				callback("Failed to parse MetaData from YouTube")
				return
			end

			self._metaTitle = response.title
			self._metaDuration = response.lengthSeconds
			callback()

		end, function(error)
			callback(("YouTube Error: %s, Try diffrent Instance"):format(error))
		end, {})
	end

	function SERVICE:NetWriteRequest()
		net.WriteString( self._metaTitle )
		net.WriteUInt( self._metaDuration, 16 )
	end
end

do	-- YouTube/Invidious Instance Switcher
	local instances, description = {}, "Invidious is a de-googled alternative to YouTube, it allows you to watch videos without ads and restrictions. It reduces the data sent to Google when watching videos."
	local cInstance = CreateClientConVar("mediaplayer_invidious_instance", "invidious.fdn.fr", true, false)

	hostname = cInstance:GetString()

	cvars.AddChangeCallback(cInstance:GetName(), function(convar, oldValue, newValue)
		hostname = newValue
	end, cInstance:GetName())

	do -- Invidious Switcher menu
		local function switcher()
			local Frame = vgui.Create( "DFrame" )
			Frame:SetTitle("(YouTube) Invidious Instance Switcher")
			Frame:SetSize( 500, 500 )
			Frame:Center()
			Frame:MakePopup()

			do -- Top Box
				local SettingsBox = vgui.Create( "DPanel", Frame )
				SettingsBox:Dock(TOP)
				SettingsBox:SetHeight(50)
				SettingsBox:SetBackgroundColor(Color(255,255,255, 0))

				local Description = vgui.Create( "RichText", SettingsBox )
				Description:Dock(FILL)
				Description:SetText( description )
			end

			do -- Instance list
				local InstanceList = vgui.Create( "DListView", Frame )
				InstanceList:Dock( FILL )
				InstanceList:SetMultiSelect( false )
				InstanceList:SetSortable( true )

				InstanceList:AddColumn( "Instance" )
				InstanceList:AddColumn( "Users" )
				InstanceList:AddColumn( "Location" )
				InstanceList:AddColumn( "Health" )

				function InstanceList:DoDoubleClick(lineID, line)
					cInstance:SetString( line:GetColumnText(1) )

					Derma_Message("Switch the media player off and on again to make the change", "Instance Changed", "OK")
				end

				local lines = {}
				for host,tbl in pairs(instances) do
					if tbl["api"] then
						lines[host] = InstanceList:AddLine(host, tbl["users"], tbl["region"], tbl["uptime"])
					end
				end

				InstanceList:SortByColumn( 2, true ) -- Sort by Users count

				if IsValid(lines[hostname]) then
					InstanceList:SelectItem( lines[hostname] )
				end

			end

		end
		concommand.Add("mediaplayer_invidious_switch", switcher, nil, "Switch the Invidious instance")
	end

	do -- Instance fetcher & updater
		local function fetchInstances()
			local function onSuccess(body, length, headers, code)
				if not body or code ~= 200 then return end

				local response = util.JSONToTable(body)
				if not response then return end

				instances = {} -- Clear instance list

				for k,v in pairs(response) do
					local name, tbl = v[1], v[2]

					if tbl.type ~= "https" then
						continue
					end

					local api = tbl["api"]
					local region = tbl["region"]
					local users = (tbl["stats"] and tbl["stats"]["usage"] and tbl["stats"]["usage"]["users"] and tbl["stats"]["usage"]["users"]["total"] or "-")
					local uptime = (tbl["monitor"] and tbl["monitor"]["uptime"] and tbl["monitor"]["uptime"] or "-")

					instances[name] = {
						api = api,
						region = region,
						users = users,
						uptime = uptime,
					}

				end
			end

			local function onFailure(message)
				print("[Invidious API]: " .. message)
			end

			http.Fetch("https://api.invidious.io/instances.json?sort_by=type,users", onSuccess, onFailure, {
				["Accept-Encoding"] = "gzip, deflate",
				["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4692.99 Safari/537.36",
			})
		end
		fetchInstances()

		if timer.Exists("Mediaplayer.Invidious.Update") then timer.Remove("Mediaplayer.Invidious.Update") end
		timer.Create("Mediaplayer.Invidious.Update", 300, 0, fetchInstances)
	end
end