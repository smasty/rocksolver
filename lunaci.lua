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



manifest, err = pretty.read(file.read(config.manifest_file))

pkg = #arg > 0 and arg[1] or nil
if not pkg then
    print("No package specified.")
    os.exit(1)
end


--[[
manifest = {
    a = {
        ["1.0"] = {"c 2.0"}
    },
    b = {
        ["1.0"] = {"a 1.0"}
    }
}

pkg = "a"
--]]
dependencies, err = deps.get_package_list(pkg, manifest)

if err then print("Error:", err) end
if not dependencies then print("Nothing to install") end
if dependencies then
    for i, dep in ipairs(dependencies) do
        print(dep)
    end
end
