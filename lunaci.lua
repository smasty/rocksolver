-- LunaCI - LuaDist automated CI environment
-- Part of the LuaDist project - http://luadist.org
-- Author: Martin Srank, martin@smasty.net
-- License: MIT

module("lunaci", package.seeall)

local config = require "lunaci.config"
local deps = require "lunaci.deps"

local lfs = require "lfs"

require "pl"
stringx.import()

local logging = require "logging"
require "logging.file"
require "logging.console"


-- log = logging.file(config.log_file, config.log_date_format)
log = logging.console("%level %message\n")
--log:setLevel(config.log_level)

