local config = require("tptmp.server.config")
local util   = require("tptmp.server.util")

local room_owner_i = {}

function room_owner_i:is_owner(client)
	if not client:guest() then
		local room_info = self:server():dconf():root().rooms[self:name()]
		if room_info then
			return util.array_find(room_info.owners, client:uid()) and true
		end
	end
	return self.temp_owner_ == client
end

function room_owner_i:owner_count()
	local room_info = self:server():dconf():root().rooms[self:name()]
	return room_info and #room_info.owners or 0
end

function room_owner_i:set_temp_owner_(client)
	if self.temp_owner_ then
		self.temp_owner_:send_server("* You are no longer the owner of this temporary room")
	end
	self.temp_owner_ = client
	if self.temp_owner_ then
		self.temp_owner_:send_server("* You are now the owner of this temporary room, use /register to make it permanent")
	end
end

function room_owner_i:is_reserved()
	local room_info = self:server():dconf():root().rooms[self:name()]
	return room_info and room_info.reserved
end

function room_owner_i:is_temporary()
	return not self:server():dconf():root().rooms[self:name()]
end

function room_owner_i:uid_insert_owner_(uid)
	local server = self:server()
	local dconf = server:dconf()
	local rooms = dconf:root().rooms
	local room_info = rooms[self:name()]
	local idx = room_info and util.array_find(room_info.owners, uid)
	if not idx then
		if not room_info then
			room_info = {
				owners = {},
			}
			rooms[self:name()] = room_info
		end
		table.insert(room_info.owners, uid)
		room_info.owners[0] = #room_info.owners
		dconf:commit()
		server:phost():call_hook("room_insert_owner", self, uid)
	end
end

function room_owner_i:uid_owns_(src)
	if type(src) ~= "number" then
		if src:guest() then
			return false
		end
		src = src:uid()
	end
	local server = self:server()
	local dconf = server:dconf()
	local rooms = dconf:root().rooms
	local room_info = rooms[self:name()]
	return room_info and util.array_find(room_info.owners, src)
end

function room_owner_i:uid_remove_owner_(uid)
	local server = self:server()
	local dconf = server:dconf()
	local rooms = dconf:root().rooms
	local room_info = rooms[self:name()]
	local idx = room_info and util.array_find(room_info.owners, uid)
	if idx then
		table.remove(room_info.owners, idx)
		room_info.owners[0] = #room_info.owners
		if #room_info.owners == 0 then
			rooms[self:name()] = nil
		end
		dconf:commit()
	end
end

local server_owner_i = {}

function server_owner_i:uid_rooms_owned_(src)
	if type(src) ~= "number" then
		src = src:uid()
	end
	local count = 0
	for _, room in pairs(self:dconf():root().rooms) do
		for _, uid in pairs(room.owners) do
			if uid == src then
				count = count + 1
			end
		end
	end
	return count
end

return {
	commands = {
		register = {
			func = function(client, message, words, offsets)
				local room = client:room()
				local server = client:server()
				if room:is_reserved() then
					client:send_server("* This room is reserved")
					return true
				end
				if not room:is_temporary() then
					client:send_server("* This room is already registered")
					return true
				end
				if client:guest() then
					client:send_server("* Guests cannot register rooms")
					return true
				end
				if server:uid_rooms_owned_(client:uid()) >= config.max_rooms_per_owner then
					client:send_server("* You own too many rooms, use /owner remove to disown one")
					return true
				end
				room:set_temp_owner_(nil)
				room:uid_insert_owner_(client:uid())
				client:send_server("* Room successfully registered")
				room:log("$ registered the room and gained room ownership", client:nick())
				server:rconlog({
					event = "room_register",
					client_name = client:name(),
					room_name = room:name(),
				})
				server:rconlog({
					event = "room_owner_add",
					client_name = client:name(),
					room_name = room:name(),
					other_nick = client:nick(),
				})
				return true
			end,
			help = "/register, no arguments: registers and claims ownership of the room",
		},
		owner = {
			func = function(client, message, words, offsets)
				if not words[3] then
					return false
				end
				local room = client:room()
				local server = client:server()
				local other_uid, other_nick = server:offline_user_by_nick(words[3])
				local other = server:client_by_nick(words[3])
				if other then
					if not other_uid then
						other_nick = other:nick()
					end
					other_uid = other
				end
				if not other_uid then
					client:send_server(("* No user named %s"):format(words[3]))
					return true
				end
				if words[2] == "check" then
					if room:uid_owns_(other_uid) then
						client:send_server(("* %s currently owns this room"):format(other_nick))
					elseif room:is_temporary() and type(other_uid) ~= "number" and room:is_owner(other_uid) then
						client:send_server(("* %s temporarily owns this room"):format(other_nick))
					else
						client:send_server(("* %s does not currently own this room"):format(other_nick))
					end
					return true
				end
				if words[2] ~= "add" and words[2] ~= "remove" and words[2] ~= "temp" then
					return false
				end
				if not room:is_owner(client) then
					client:send_server("* You are not an owner of this room")
					return true
				end
				if words[2] == "temp" then
					if not room:is_temporary() then
						client:send_server("* This is not a temporary room, use /owner remove to disown it")
						return true
					end
					if not (type(other_uid) ~= "number" and other_uid:room() == room) then
						client:send_server(("* %s is not present in this room"):format(other_nick))
						return true
					end
					room:set_temp_owner_(other_uid)
				elseif words[2] == "add" then
					if room:is_temporary() then
						client:send_server("* This is a temporary room, use /register to make it permanent")
						return true
					end
					if not (type(other_uid) ~= "number" and other_uid:room() == room) then
						client:send_server(("* %s is not present in this room"):format(other_nick))
						return true
					end
					if room:owner_count() >= config.max_owners_per_room then
						client:send_server("* The room has too many owners, have one of them use /disown to disown it")
						return true
					end
					if server:uid_rooms_owned_(other_uid) >= config.max_rooms_per_owner then
						client:send_server(("* %s owns too many rooms, have them use /disown to disown one"):format(other_nick))
						return true
					end
					if room:uid_owns_(other_uid) then
						client:send_server(("* %s already owns this room"):format(other_nick))
						return true
					end
					local client_to_notify
					local src = other_uid
					if type(src) ~= "number" then
						client_to_notify = src
						src = src:uid()
					end
					room:uid_insert_owner_(src)
					room:log("$ shared room ownership with $", client:nick(), other_nick)
					server:rconlog({
						event = "room_owner_add",
						client_name = client:name(),
						room_name = room:name(),
						other_nick = other_nick,
					})
					client:send_server("* Room ownership successfully shared")
					if client_to_notify then
						client_to_notify:send_server("* You now have shared ownership of this room")
					end
				elseif words[2] == "remove" then
					if room:is_temporary() then
						client:send_server("* This is a temporary room, use /register to make it permanent")
						return true
					end
					if not room:uid_owns_(other_uid) then
						client:send_server(("* %s does not currently own this room"):format(other_nick))
						return true
					end
					local client_to_notify
					local src = other_uid
					if type(src) ~= "number" then
						client_to_notify = src
						src = src:uid()
					end
					room:uid_remove_owner_(src)
					room:log("$ stripped $ of room ownership", client:nick(), other_nick)
					server:rconlog({
						event = "room_owner_remove",
						client_name = client:name(),
						room_name = room:name(),
						other_nick = other_nick,
					})
					if room:is_temporary() then
						client_to_notify:send_server("* Room successfully unregistered")
						room:set_temp_owner_(client)
						server:rconlog({
							event = "room_unregister",
							client_name = client:name(),
							room_name = room:name(),
						})
					end
					if client_to_notify and client_to_notify:room() == room then
						if not room:is_temporary() then
							client_to_notify:send_server("* You no longer have shared ownership of this room")
						end
					end
				else
					return false
				end
				return true
			end,
			help = "/owner add\\check\\remove\\temp <user>: shares ownership of the room with a user, checks if a user is an owner, strips a user of their ownership, or transfers temporary ownership",
		},
	},
	hooks = {
		plugin_load = {
			func = function(mtidx_augment)
				assert(config.auth)
				mtidx_augment("room", room_owner_i)
				mtidx_augment("server", server_owner_i)
			end,
		},
		server_init = {
			func = function(server)
				local dconf = server:dconf()
				if not dconf:root().rooms then
					local rooms = {}
					local reserve = {
						null = {
							-- motd = "Welcome to TPTMPv2!",
							motd = "Welcome to TPTMPv2! This test server is run by LBPHacker, report bugs and suggestions to him. If you got v2 from the script manager and want to go back to v1, disable v2 in the script manager.",
						},
						guest = {
							motd = "Welcome to TPTMPv2! You have landed in the guest lobby as you do not seem to be logged in.",
						},
						kicked = {
						},
					}
					for name, info in pairs(reserve) do
						rooms[name] = {
							reserved = true,
							owners = {},
						}
					end
					dconf:root().rooms = rooms
					for name, info in pairs(reserve) do
						server:phost():call_hook("room_reserve", server, name, info)
					end
				end
				dconf:commit()
			end,
		},
		room_join = {
			func = function(room, client)
				if room:is_temporary() and not room.temp_owner_ then
					room:set_temp_owner_(client)
				end
			end,
		},
		room_leave = {
			func = function(room, client)
				if room:is_temporary() and room.temp_owner_ == client then
					room:set_temp_owner_(nil)
					for other in room:clients() do
						if other ~= client then
							room:set_temp_owner_(other)
							break
						end
					end
				end
			end,
		},
		room_info = {
			func = function(room, client)
				if room:is_reserved() then
					client:send_server("* Status: reserved")
				elseif room:is_temporary() then
					client:send_server("* Status: temporary")
					client:send_server(("* Owner: %s"):format(room.temp_owner_:nick()))
				else
					local server = client:server()
					local room_info = server:dconf():root().rooms[room:name()]
					if room.is_private and room:is_private() then
						client:send_server("* Status: permanent, private")
					else
						client:send_server("* Status: permanent")
					end
					local owners = {}
					for i = 1, #room_info.owners do
						local _, nick = server:offline_user_by_uid(room_info.owners[i])
						table.insert(owners, nick)
					end
					table.sort(owners)
					client:send_server(("* %s: %s"):format(#owners == 1 and "Owner" or "Owners", table.concat(owners, ", ")))
				end
			end,
		},
	},
}
