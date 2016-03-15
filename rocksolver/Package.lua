-- LuaDist Package object definition
-- Part of the LuaDist project - http://luadist.org
-- Author: Martin Srank, hello@smasty.net
-- License: MIT

module("rocksolver.Package", package.seeall)

local const = require "rocksolver.constraints"
local tablex = require "pl.tablex"


local Package = {}
Package.__index = Package

setmetatable(Package, {
    __call = function (class, ...)
        return class.new(...)
    end,
})

function Package.new(name, version, spec, is_local)
    local self = setmetatable({}, Package)

    -- TODO asserts
    self.name = name
    self.version = type(version) == 'table' and version or const.parseVersion(version)
    self.spec = spec
    self.remote = not is_local
    self.platforms = spec.supported_platforms and spec.supported_platforms or {}

    return self
end


function Package.fromRockspec(rockspec)
    -- TODO asserts for table and missing fields
    return Package(rockspec.package, rockspec.version, rockspec, true)
end


-- String representation of the package (name and version)
function Package:__tostring()
    return self.name .. ' ' .. tostring(self.version)
end


-- Package equality check - packages are equal if names and versions are equal.
function Package:__eq(p2)
    return self.name == p2.name and self.version == p2.version
end


-- Package comparison - cannot compare packages with different name.
function Package:__lt(p2)
    assert(self.name == p2.name, "Cannot compare two different packages")
    return self.version < p2.version
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

    local available = {...}
    if #available == 1 and type(available[1]) == "table" then
        available = available[1]
    end
    available = tablex.makeset(available)

    local support = nil
    for _, p in pairs(self.platforms) do
        local neg, p = p:match("^(!?)(.*)")
        if neg == "!" then
            if available[p] then
                return false, "Platform " .. p .. " is not supported"
            end
        elseif available[p] then
            supported = true
        elseif supported == nil then
            supported = false
        end
    end

    if supported == false then
        return false, "Platforms " .. table.concat(tablex.keys(available), ", ") .. " are not supported"
    end
    return true
end


-- Returns all package dependencies. If platforms are provided and the package uses per-platform overrides,
-- applicable platform-specific dependencies will be added to the list of dependencies.
function Package:dependencies(platforms)
    if not platforms then
        return self.spec.dependencies and self.spec.dependencies or {}
    elseif type(platforms) ~= 'table' then
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

    if deps and deps.platforms then
        tablex.insertvalues(deps, get_platform_deps(platforms))
        deps.platforms = nil
    end

    return deps and deps or {}
end


return Package
