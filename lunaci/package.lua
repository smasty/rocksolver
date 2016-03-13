-- LunaCI package definition
-- Part of the LuaDist project - http://luadist.org
-- Author: Martin Srank, martin@smasty.net
-- License: MIT

module("lunaci.package", package.seeall)

local const = require "lunaci.constraints"
local tablex = require "pl.tablex"


Package = {}

function Package:new(package, version, spec, remote)
    o = {}
    setmetatable(o, self)
    self.__index = self

    self.package = package
    self.version = type(version) == 'table' and version or const.parseVersion(version)
    self.spec = spec
    self.remote = remote
    self.platforms = spec.supported_platforms and spec.supported_platforms or {}

    return o
end


function Package:__tostring()
    return self.package .. ' ' .. self.version
end


-- A local package has the full Rockspec available in Package.spec
function Package:is_local()
    return not self.remote
end


-- A remote package is defined by a manifest and only contains dependency information.
function Package:is_remote()
    return not self.is_local()
end


-- Compare package supported platforms with given available platform.
-- If only negative platforms are listed, we assume all other platforms are supported.
-- If a positive entry exists, then at least one entry must positively match to the available platform.
-- More then one available platform may be given, e.g. Linux defines both 'unix' and 'linux'.
function Package:supports_platform(...)
    -- If all platforms are supported, just return true
    if #self.platforms == 0 then return true end

    local available_platforms = arg
    if #arg == 1 and type(arg[1]) == "table" then
        available_platforms = arg[1]
    end

    local support = nil
    for _, p in pairs(self.platforms) do
        local neg, p = p:match("^(!?)(.*)")
        if neg == "!" then
            if available_platforms[p] then
                return false, "Platform " .. p .. " is not supported"
            end
        else
            if available_platforms[p] then
                supported = true
            else if supported == nil then
                supported = false
            end
        end
    end

    if supported == false then
        return false, "Platforms " .. table.concat(available_platforms, ", ") .. " are not supported"
    end
    return true
end


-- Returns all package dependencies. If platforms are provided and the package uses per-platform overrides,
-- applicable platform-specific dependencies will be added to the list of dependencies.
function Package:dependencies(platforms)
    if not platforms then
        return self.spec.dependencies
    else if type(platforms) ~= 'table' then
        platforms = {platforms}
    end

    local function get_platform_deps(platforms)
        local deps = {}
        local plat_deps = self.spec.dependencies.platforms
        for _, p in pairs(platforms) do
            if plat_deps[p] then
                tablex.insertvalues(deps, plat_deps[p])
            end
        end
        return deps
    end

    local deps = self.spec.dependencies

    if and deps.platforms then
        tablex.insertvalues(deps, get_platform_deps(platforms))
        deps.platforms = nil
    end

    return deps
end
