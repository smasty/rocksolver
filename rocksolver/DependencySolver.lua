-- LuaDist Package dependency solver
-- Part of the LuaDist project - http://luadist.org
-- Author: Martin Srank, hello@smasty.net
-- License: MIT

module("rocksolver.DependencySolver", package.seeall)

local const = require("rocksolver.constraints")
local Package = require("rocksolver.Package")

local tablex = require "pl.tablex"


-- helper function for debug purposes
local function table_tostring(tbl, label)
    assert(type(tbl) == "table", "utils.table_tostring: Argument 'tbl' is not a table.")
    local str = ""
    for k,v in pairs(tbl) do
        if type(v) == "table" then
            if v.__tostring then
                str = str .. tostring(v) .. " "
            else
                str = str .. "(" ..table_tostring(v, k) .. ")"
            end
        else
            if label ~= nil then
                str = str .. " " .. k .. " = " .. tostring(v) .. ", "
            else
                str = str .. tostring(v) .. ", "
            end
        end
    end
    return str
end


local DependencySolver = {}
DependencySolver.__index = DependencySolver

setmetatable(DependencySolver, {
    __call = function (class, ...)
        return class.new(...)
    end,
})

function DependencySolver.new(manifest, platform)
    local self = setmetatable({}, DependencySolver)

    self.manifest = manifest
    self.platform = platform

    return self
end


-- Check if a given package is in the provided list of installed packages.
-- Can also check for package version constraint.
function DependencySolver:is_installed(pkg_name, installed, pkg_constraint)
    -- TODO asserts

    local function selected(pkg)
        return pkg.selected and "selected" or "installed"
    end
    local constraint_str = pkg_constraint and " " .. pkg_constraint or ""

    local pkg_installed, err = false, nil

    for _, installed_pkg in ipairs(installed) do
        if pkg_name == installed_pkg.name then
            if not pkg_constraint or const.constraint_satisified(installed_pkg.version, pkg_constraint) then
                pkg_installed = true
                break
            else
                err = ("Package %s%s needed, but %s at version %s.")
                    :format(pkg_name, constraint_str, selected(installed_pkg), installed_pkg.version)
                break
            end
        end
    end

    return pkg_installed, err
end


function DependencySolver:find_candidates(package)
    -- TODO asserts

    pkg_name, pkg_constraint = const.split(package)
    pkg_constraint = pkg_constraint or ""
    if not self.manifest.packages[pkg_name] then return {} end

    local found = {}
    for version, spec in tablex.sort(self.manifest.packages[pkg_name], const.compareVersions) do
        if const.constraint_satisified(version, pkg_constraint) then
            local pkg = Package(pkg_name, version, spec)
            if pkg:supports_platform(self.platform) then
                table.insert(found, pkg)
            end
        end
    end

    return found
end


-- Returns list of all needed packages to install the "package" using the manifest and a list of already installed packages.
function DependencySolver:resolve_dependencies(package, installed, dependency_parents, tmp_installed)
    installed = installed or {}
    dependency_parents = dependency_parents or {}
    tmp_installed = tmp_installed or tablex.deepcopy(installed)

    -- TODO asserts

    -- Extract package name and constraint
    local pkg_name, pkg_const = const.split(package)

    --[[ for future debugging:
    print('resolving: '.. package)
    print('    installed: ', table_tostring(installed))
    print('    tmp_installed: ', table_tostring(tmp_installed))
    print('- is installed: ', self:is_installed(pkg_name, tmp_installed, pkg_const))
    --]]

    -- Check if the package is already installed
    local pkg_installed, err = self:is_installed(pkg_name, tmp_installed, pkg_const)


    if pkg_installed then return {} end
    if err then return nil, err end

    local to_install = {}

    -- Get package candidates
    local candidates = self:find_candidates(package)
    if #candidates == 0 then
        return nil, "No suitable candidate for package \"" .. package .. "\" found."
    end

    -- For each candidate (highest version first)
    for _, pkg in ipairs(candidates) do

        --[[ for future debugging:
        print('  candidate: '.. tostring(pkg))
        print('      installed: ', table_tostring(installed))
        print('      tmp_installed: ', table_tostring(tmp_installed))
        print('      to_install: ', table_tostring(to_install))
        print('      dependencies: ', table_tostring(pkg:dependencies()))
        print('  -is installed: ', self:is_installed(pkg.name, tmp_installed, pkg_const))
        -- ]]

        -- Clear state from previous iteration
        pkg_installed, err = false, nil

        -- Check if it was already added by previous candidate
        pkg_installed, err = self:is_installed(pkg.name, tmp_installed, pkg_const)
        if pkg_installed then
            break
        end

        -- Maybe check for conflicting packages here if we will support that functionallity

        -- Resolve dependencies of the package
        if pkg:dependencies(self.platform) then

            local deps = pkg:dependencies(self.platform)

            -- For preventing circular dependencies
            table.insert(dependency_parents, pkg.name)

            -- For each dep of pkg
            for _, dep in ipairs(deps) do
                -- Detect circular dependencies
                local has_circular_dependency = false
                local dep_name = const.split(dep)
                for _, parent in ipairs(dependency_parents) do
                    if dep_name == parent then
                        has_circular_dependency = true
                        break
                    end
                end

                -- If circular deps detected
                if has_circular_dependency then
                    err = "Error getting dependency of \"" .. tostring(pkg) .. "\": \"" .. dep .. "\" is a circular dependency."
                    break
                end

                -- No circular deps - recursively call on this dependency package.
                local deps_to_install, deps_err = self:resolve_dependencies(dep, installed, dependency_parents, tmp_installed)

                if deps_err then
                    err = "Error getting dependency of \"" .. tostring(pkg) .. "\": " .. deps_err
                    break
                end

                -- If suitable deps found - add them to the to_install list.
                if deps_to_install then
                    for _, dep_to_install in ipairs(deps_to_install) do
                        table.insert(to_install, dep_to_install)
                        table.insert(tmp_installed, dep_to_install)
                        table.insert(installed, dep_to_install)
                    end
                end
            end

            -- Remove last pkg from the circular deps stack
            table.remove(dependency_parents)
        end

        if not err then
            -- Mark package as selected and add it to tmp_installed
            pkg.selected = true
            table.insert(tmp_installed, pkg)
            table.insert(to_install, pkg)
            --print("+ Installing package " .. tostring(pkg))
        else
            -- If some error occured, reset to original state
            to_install = {}
            tmp_installed = tablex.deepcopy(installed)
        end
    end


    -- If package is not installed and no candidates were suitable, return last error.
    if #to_install == 0 and not pkg_installed then
        return nil, err
    end


    return to_install, nil
end


return DependencySolver
