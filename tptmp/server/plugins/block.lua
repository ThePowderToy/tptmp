local util   = require("tptmp.server.util")
local config = require("tptmp.server.config")

local client_block_i = {}

function client_block_i:rehash_blocked_by_()
	local dconf = self:server():dconf()
	local uids = not self:guest() and dconf:root().blocked_by[tostring(self:uid())]
	local lookup = {}
	if uids then
		for i = 1, #uids do
			lookup[uids[i]] = true
		end
	end
	self.blocked_by_ = lookup
end

return {
	commands = {
		block = {
			func = function(client, message, words, offsets)
				if not words[3] then
					-- * TODO[req]: list blocked users
					return false
				end
				local rnick = words[3]
				local server = client:server()
				if words[2] == "add" then
					local other_by_nick = server:client_by_nick(rnick)
					local blocked = false
					local nick
					if other_by_nick and (other_by_nick:guest() or client:guest()) then
						if not other_by_nick.temp_blocked_by_[client] then
							blocked = true
							other_by_nick.temp_blocked_by_[client] = true
						end
						nick = other_by_nick:nick()
					else
						local other_uid, other_nick = server:offline_user_by_nick(rnick)
						if not other_uid then
							client:send_server("* No such user")
							return true
						end
						local dconf = server:dconf()
						local blocked_by = dconf:root().blocked_by
						local uids = blocked_by[tostring(other_uid)]
						local idx = uids and util.array_find(uids, client:uid())
						if not idx then
							local blocks = uids and #uids or 0
							if blocks >= config.max_blocks_per_user then
								client:send_server("You have blocked too many users, contact staff")
								return true
							end
							blocked = true
							if not uids then
								uids = {}
								blocked_by[tostring(other_uid)] = uids
							end
							table.insert(uids, client:uid())
							uids[0] = #uids
							dconf:commit()
							local other_by_uid = server:client_by_uid(other_uid)
							if other_by_uid then
								other_by_uid:rehash_blocked_by_()
							end
						end
						nick = other_nick
					end
					if blocked then
						server.log_inf_("$ blocked $", client:nick(), nick)
						client:send_server(("* %s is now blocked"):format(nick))
					else
						client:send_server(("* %s is already blocked"):format(nick))
					end
				elseif words[2] == "check" then
					local other_by_nick = server:client_by_nick(rnick)
					local unblocked = false
					local nick
					if other_by_nick and (other_by_nick:guest() or client:guest()) then
						if other_by_nick.temp_blocked_by_[client] then
							unblocked = true
						end
						nick = other_by_nick:nick()
					else
						local other_uid, other_nick = server:offline_user_by_nick(rnick)
						if not other_uid then
							client:send_server("* No such user")
							return true
						end
						local dconf = server:dconf()
						local blocked_by = dconf:root().blocked_by
						local uids = blocked_by[tostring(other_uid)]
						local idx = uids and util.array_find(uids, client:uid())
						if idx then
							unblocked = true
						end
						nick = other_nick
					end
					if unblocked then
						client:send_server(("* %s is currently unblocked"):format(nick))
					else
						client:send_server(("* %s is not currently blocked"):format(nick))
					end
				elseif words[2] == "remove" then
					local other_by_nick = server:client_by_nick(rnick)
					local unblocked = false
					local nick
					if other_by_nick and (other_by_nick:guest() or client:guest()) then
						if other_by_nick.temp_blocked_by_[client] then
							unblocked = true
							other_by_nick.temp_blocked_by_[client] = nil
						end
						nick = other_by_nick:nick()
					else
						local other_uid, other_nick = server:offline_user_by_nick(rnick)
						if not other_uid then
							client:send_server("* No such user")
							return true
						end
						local dconf = server:dconf()
						local blocked_by = dconf:root().blocked_by
						local uids = blocked_by[tostring(other_uid)]
						local idx = uids and util.array_find(uids, client:uid())
						if idx then
							unblocked = true
							table.remove(uids, idx)
							uids[0] = #uids
							if #uids == 0 then
								blocked_by[tostring(other_uid)] = nil
							end
							dconf:commit()
							local other_by_uid = server:client_by_uid(other_uid)
							if other_by_uid then
								other_by_uid:rehash_blocked_by_()
							end
						end
						nick = other_nick
					end
					if unblocked then
						server.log_inf_("$ unblocked $", client:nick(), nick)
						client:send_server(("* %s is now unblocked"):format(nick))
					else
						client:send_server(("* %s is not currently blocked"):format(nick))
					end
				else
					return false
				end
				return true
			end,
			help = "/block add\\check\\remove [user]: blocks a user, preventing them from messaging you or interacting with you otherwise, checks whether a user is blocked, or unblocks a user",
		},
	},
	hooks = {
		load = {
			func = function(mtidx_augment)
				mtidx_augment("client", client_block_i)
			end,
		},
		init = {
			func = function(server)
				local dconf = server:dconf()
				dconf:root().blocked_by = dconf:root().blocked_by or {}
				dconf:commit()
			end,
		},
		connect = {
			func = function(client)
				client.temp_blocked_by_ = setmetatable({}, { __mode = "k" })
				client:rehash_blocked_by_()
			end,
		},
	},
	checks = {
		can_interact_with = {
			func = function(src, dest)
				if type(dest) ~= "number" then
					if src.temp_blocked_by_[dest] then
						return false, "temporarily blocked"
					end
					if dest:guest() then
						return true
					end
					dest = dest:uid()
				end
				if src.blocked_by_[dest] then
					return false, "permanently blocked"
				end
				return true
			end,
		},
	},
}