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


local testpackage = {
    "lua >= 5.1",
    "penlight",
    platforms = {
        unix = {
            "lua >= 5.2",
            "luasocket >= 2.0",
            "lnotify < 1.0"
        }
    },

}

manifest.packages["testpackage"] = {["0.1"] = {dependencies = testpackage, supported_platforms = {"unix"}}}

dependencies, err = deps.get_package_list(pkg, manifest)

if err then print("Error:", err) end
if not dependencies then print("Nothing to install") end
if dependencies then
    for i, dep in ipairs(dependencies) do
        print(dep)
    end
end
