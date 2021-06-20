local common_config = require("tptmp.common.config")

local config = {
	-- ***********************************************************************
	-- *** The following options are purely cosmetic and should be         ***
	-- *** customised in accordance with your taste.                       ***
	-- ***********************************************************************

	-- * Version string to display in the window title.
	versionstr = "2.0",

	-- * Amount of incoming messages to remember, counted from the
	--   last one received.
	backlog_size = 1000,

	-- * Amount of outgoing messages to remember, counted from the
	--   last one sent.
	history_size = 1000,

	-- * Default window width. Overridden by the value loaded from the manager
	--   backend, if any.
	default_width = 210,

	-- * Default window height. Similar to default_width.
	default_height = 155,

	-- * Default window background alpha. Similar to default_width.
	default_alpha = 150,

	-- * Minimum window width.
	min_width = 150,

	-- * Minimum window height.
	min_height = 107,

	-- * Amount of time in seconds that elapses between a notification bubble
	--   appearing and settling in its final position.
	notif_fly_time = 0.1,

	-- * Distance in pixels between the position where a notification appears
	--   and the position where it settles.
	notif_fly_distance = 3,

	-- * Prefix for messages logged.
	print_prefix = "\bt[TPTMP]\bw ",


	-- ***********************************************************************
	-- *** The following options should only be changed if you know what   ***
	-- *** you are doing. This usually involves consulting with the        ***
	-- *** developers. Otherwise, these are sane values you should trust.  ***
	-- ***********************************************************************

	-- * Specifies whether connections made without specifying the port number
	--   should be encrypted.
	default_secure = false, -- * TODO[fin]: Enable.

	-- * Size of the buffer passed to the recv system call. Bigger values
	--   consume more memory, smaller ones incur larger system call overhead.
	read_size = 0x1000000,

	-- * Receive queue limit. Specifies the maximum amount of data the server
	--   is allowed to have sent but which the client has not yet had time to
	--   process. The connection is closed if the size of the receive queue
	--   exceeds this limit.
	recvq_limit = 0x200000,

	-- * Send queue limit. Specifies the maximum amount of data the server
	--   is allowed to have not yet processed but which the client has already
	--   queued. The connection is closed if the size of the send queue exceeds
	--   this limit.
	sendq_limit = 0x2000000,

	-- * Maximum amount of time in seconds after which the connection attempt
	--   attempt should be deemed a failure, unless it succeeds.
	connect_timeout = 15,

	-- * Amount of time in seconds between pings being sent to the server.
	--   Should be half of the ping_timeout option on the server side or less.
	ping_interval = 60,

	-- * Amount of time in seconds the connection is allowed to be maintained
	--   without the server sending a ping. Should be twice the ping_interval
	--   option on the server side or more.
	ping_timeout = 120,

	-- * Amount of time in seconds that elapses between a non-graceful
	--   connection closure (anything that isn't the client willingly
	--   disconnecting or the server explicitly dropping the client) and an
	--   attempt to establish a new connection.
	reconnect_later_timeout = 2,

	-- * Path to the temporary stamp created when syncing.
	stamp_temp = ".tptmp.stm",

	-- * Pattern used to match word characters by the textbox. Used by cursor
	--   control, mostly Ctrl+Left and Ctrl+Right and related shortcuts.
	word_pattern = "^[A-Za-z0-9-_\128-\255]+$",

	-- * Pattern used to match whitespace characters by the textbox. Similar to
	--   word_pattern.
	whitespace_pattern = "^ $",

	-- * Namespace for settings stored in the manager backend.
	manager_namespace = "tptmp",

	-- * Grace period in seconds after which another client is deemed to not
	--   have FPS synchronization enabled.
	fps_sync_timeout = 3,


	-- ***********************************************************************
	-- *** The following options should be changed in                      ***
	-- *** tptmp/common/config.lua instead. Since these options should     ***
	-- *** align with the equivalent options on the server side, you       ***
	-- *** will most likely have to run your own version of the server     ***
	-- *** if you intend to change these.                                  ***
	-- ***********************************************************************

	-- * Host to connect to by default.
	default_host = common_config.host,

	-- * Port to connect to by default.
	default_port = common_config.port,

	-- * Protocol version.
	version = common_config.version,

	-- * Client-to-server message size limit.
	message_size = common_config.message_size,

	-- * Client-to-server message rate limit.
	message_interval = common_config.message_interval,

	-- * Authentication backend URL. Only relevant if auth = true on the
	--   server side.
	auth_backend = common_config.auth_backend,

	-- * Authentication backend timeout in seconds. Only relevant if
	---  auth = true on the server side.
	auth_backend_timeout = common_config.auth_backend_timeout,
}
config.default_x = math.floor((sim.XRES - config.default_width) / 2)
config.default_y = math.floor((sim.YRES - config.default_height) / 2)

return config