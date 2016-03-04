-- LunaCI dependency resolver
-- Part of the LuaDist project - http://luadist.org
-- Author: Martin Srank, martin@smasty.net
-- License: MIT

module("lunaci.deps", package.seeall)

local const = require("lunaci.constraints")
--local pkg = require("lunaci.package")

require "pl"
stringx.import()

local package_mt = {__tostring = function(o) return o.package .. " " .. o.version end}
local function newPackage(pkg, ver, manifest)
    local p = {package = pkg, version = ver, dependencies = manifest[pkg][ver]}
    setmetatable(p, package_mt)
    return p
end


-- Check if a given package is in the provided list of installed packages.
-- Can also check for package version constraint.
function is_installed(pkg_name, installed, pkg_constraint)
    -- TODO asserts
    --print("== is_installed", pkg_name, pkg_constraint)

    local pkg_installed, err = false, nil

    for _, installed_pkg in ipairs(installed) do
        if pkg_name == installed_pkg.package then
            if not pkg_constraint or const.constraint_satisified(installed_pkg.version, pkg_constraint) then
                pkg_installed = true
                break
            else
                err = "Package " .. pkg_name .. (pkg_constraint and " " .. pkg_constraint or "") .. " needed, but installed at version " .. installed_pkg.version .. "."
                break
            end
        end
    end

    return pkg_installed, err
end


function find_candidates(package, manifest)
    pkg_name, pkg_constraint = const.split(package)
    pkg_constraint = pkg_constraint or ""
    if not manifest[pkg_name] then return {} end

    local found = {}
    for version in tablex.sort(manifest[pkg_name], const.compareVersions) do
        if const.constraint_satisified(version, pkg_constraint) then
            table.insert(found, newPackage(pkg_name, version, manifest))
        end
    end

    return found
end


local function table_tostring(tbl, label)
    assert(type(tbl) == "table", "utils.table_tostring: Argument 'tbl' is not a table.")
    local str = ""
    for k,v in pairs(tbl) do
        if type(v) == "table" then
            str = str .. "(" ..table_tostring(v, k) .. ")"
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

-- Returns list of all needed packages to install the "package" using the manifest and a list of already installed packages.
function resolve_dependencies(package, manifest, installed, dependency_parents, tmp_installed)

    tmp_installed = tmp_installed or tablex.deepcopy(installed)

    -- TODO asserts

    -- Extract package name and constraint
    local pkg_name, pkg_const = const.split(package)

    --[[ for future debugging:
    print('resolving: '.. package)
    print('    installed: ', table_tostring(installed))
    print('    tmp_installed: ', table_tostring(tmp_installed))
    print('- is installed: ', is_installed(pkg_name, tmp_installed, pkg_const))
    --]]

    -- Check if the package is already installed
    local pkg_installed, err = is_installed(pkg_name, tmp_installed, pkg_const)


    if pkg_installed then return {} end
    if err then return nil, err end

    local to_install = {}

    -- Get package candidates
    local candidates = find_candidates(package, manifest)
    if #candidates == 0 then
        return nil, "No suitable candidate for package '" .. package .. "' found."
    end

    -- For each candidate (highest version first)
    for _, pkg in ipairs(candidates) do

        --[[ for future debugging:
        print('  candidate: '.. pkg.package..'-'..pkg.version)
        print('      installed: ', table_tostring(installed))
        print('      tmp_installed: ', table_tostring(tmp_installed))
        print('      to_install: ', table_tostring(to_install))
        print('      dependencies: ', table_tostring(pkg.dependencies))
        print('  -is installed: ', is_installed(pkg.package, tmp_installed, pkg_const))
        -- ]]

        -- Clear state from previous iteration
        pkg_installed, err = false, nil

        -- Check if it was already added by previous candidate
        pkg_installed, err = is_installed(pkg.package, tmp_installed, pkg_const)
        if pkg_installed then
            break
        end

        -- Maybe check for conflicting packages here if we will support that functionallity

        -- Resolve dependencies of the package
        if pkg.dependencies then

            -- For preventing circular dependencies
            table.insert(dependency_parents, pkg.package)

            -- For each dep of pkg
            for _, dep in ipairs(pkg.dependencies) do
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

                -- No circular deps - recursively call this on this dependency package.
                local deps_to_install, deps_err = resolve_dependencies(dep, manifest, installed, dependency_parents, tmp_installed)

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


function get_package_list(package, manifest, version)
    assert(type(package) == "string", "deps.get_package_list: package must be string")
    assert(type(manifest) == "table", "deps.get_package_list: manifest must be table")
    if version then assert(type(version) == "string", "deps.get_package_list: version must be string") end

    if not manifest[package] or (version and not manifest[package][version]) then
        return nil, "No such package: "..package.." "..version
    end


    -- Add virtual Lua package to the manifest
    local lua_version = _VERSION:match("Lua%s+([%d%.%-]+)")
    manifest["lua"] = {[lua_version] = {}}
    local installed = {newPackage("lua", lua_version, manifest)}

    --local pkg = newPackage(package, version, manifest)
    local to_install, err = resolve_dependencies(package .. (version and ("=="..version) or ""), manifest, installed, {})

    return to_install, err
end
