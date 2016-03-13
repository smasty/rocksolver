-- LunaCI configuration
-- Part of the LuaDist project - http://luadist.org
-- Author: Martin Srank, martin@smasty.net
-- License: MIT

module("lunaci.config", package.seeall)

local path = require "pl.path"
--local file = require "pl.file"
--local stringx = require "pl.stringx"
local logging = require "logging"


-- Configuration ---------------------------------------------------------------
local data_dir = path.abspath("data")

manifest_file = path.join(data_dir, "manifest-file")     -- Manifest file with module dependencies

platform = {"unix", "linux"}


-- Logging ---------------------------------------------------------------------
log_level       = logging.DEBUG                                -- Logging level.
log_file        = path.join(data_dir, "logs/lunaci-%s.log") -- Log output file path - %s in place of date
log_date_format = "%Y-%m-%d"                                   -- Log date format
