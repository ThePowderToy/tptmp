local config = require("tptmp.server.config")
local jnet   = require("jnet")

local server_ban_i = {}

function server_ban_i:insert_host_ban_(host)
	if not self.host_bans_:insert(host) then
		return nil, "eexist", "already banned"
	end
	self:save_host_bans_()
	return true
end

function server_ban_i:remove_host_ban_(host)
	if not self.host_bans_:remove(host) then
		return nil, "enoent", "not currently banned"
	end
	self:save_host_bans_()
	return true
end

function server_ban_i:save_host_bans_()
	local tbl = {}
	for host in self.host_bans_:nets() do
		table.insert(tbl, tostring(host))
	end
	tbl[0] = #tbl
	self.dconf_:root().host_bans = tbl
	self.dconf_:commit()
end

function server_ban_i:load_host_bans_()
	local tbl = self.dconf_:root().host_bans or {}
	self.host_bans_ = jnet.set()
	for i = 1, #tbl do
		self.host_bans_:insert(jnet(tbl[i]))
	end
	self:save_host_bans_()
end

function server_ban_i:host_banned_(host)
	return self.host_bans_:contains(host)
end

function server_ban_i:insert_uid_ban_(uid)
	if self.uid_bans_[uid] then
		return nil, "eexist", "already banned"
	end
	self.uid_bans_[uid] = true
	self:save_uid_bans_()
	return true
end

function server_ban_i:remove_uid_ban_(uid)
	if not self.uid_bans_[uid] then
		return nil, "enoent", "not currently banned"
	end
	self.uid_bans_[uid] = nil
	self:save_uid_bans_()
	return true
end

function server_ban_i:save_uid_bans_()
	local tbl = {}
	for uid in pairs(self.uid_bans_) do
		table.insert(tbl, uid)
	end
	tbl[0] = #tbl
	self.dconf_:root().uid_bans = tbl
	self.dconf_:commit()
end

function server_ban_i:load_uid_bans_()
	local tbl = self.dconf_:root().uid_bans or {}
	self.uid_bans_ = {}
	for i = 1, #tbl do
		self.uid_bans_[tbl[i]] = true
	end
	self:save_uid_bans_()
end

function server_ban_i:uid_banned_(uid)
	return self.uid_bans_[uid]
end

return {
	console = {
		ban = {
			func = function(rcon, data)
				local server = rcon:server()
				if type(data.nick) ~= "string" then
					return { status = "badnick", human = "invalid nick" }
				end
				local uid = server:offline_user_by_nick(data.nick)
				if not uid then
					return { status = "nouser", human = "no such user" }
				end
				if data.action == "insert" then
					local ok, err, human = server:insert_uid_ban_(uid)
					if not ok then
						return { status = err, human = human }
					end
					return { status = "ok" }
				elseif data.action == "remove" then
					local ok, err, human = server:remove_uid_ban_(uid)
					if not ok then
						return { status = err, human = human }
					end
					return { status = "ok" }
				elseif data.action == "check" then
					return { status = "ok", banned = server:uid_banned_(uid) }
				end
				return { status = "badaction", human = "unrecognized action" }
			end,
		},
		ipban = {
			func = function(rcon, data)
				local server = rcon:server()
				local ok, host = pcall(jnet, data.host)
				if not ok then
					return { status = "badhost", human = "invalid host: " .. host, reason = host }
				end
				if data.action == "insert" then
					local ok, err, human = server:insert_host_ban_(host)
					if not ok then
						return { status = err, human = human }
					end
					return { status = "ok" }
				elseif data.action == "remove" then
					local ok, err, human = server:remove_host_ban_(host)
					if not ok then
						return { status = err, human = human }
					end
					return { status = "ok" }
				elseif data.action == "check" then
					local banned_subnet = server:host_banned_(host)
					return { status = "ok", banned = banned_subnet and tostring(banned_subnet) or false }
				end
				return { status = "badaction", human = "unrecognized action" }
			end,
		},
	},
	hooks = {
		plugin_load = {
			func = function(mtidx_augment)
				mtidx_augment("server", server_ban_i)
			end,
		},
		server_init = {
			func = function(server)
				server:load_host_bans_()
				server:load_uid_bans_()
			end,
		},
	},
	checks = {
		can_connect = {
			func = function(client)
				local banned_subnet = client:server():host_banned_(client:host())
				if banned_subnet then
					return nil, "you are banned from this server", ("host %s is banned (subnet %s)"):format(client:host(), tostring(banned_subnet)), {
						reason = "host_banned",
						subnet = tostring(banned_subnet),
					}
				end
				return true
			end,
		},
		can_join = {
			func = function(client)
				if client:guest() then
					if not config.guests_allowed then
						return nil, "authentication failed and guests are not allowed on this server", nil, {
							reason = "guests_banned",
						}
					end
				else
					if client:server():uid_banned_(client:uid()) then
						return nil, "you are banned from this server", ("%s, uid %i is banned"):format(client:nick(), client:uid()), {
							reason = "uid_banned",
						}
					end
				end
				return true
			end,
		},
	},
}
