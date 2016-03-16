-- LuaDist Rocksolver utility functions
-- Part of the LuaDist project - http://luadist.org
-- Author: Martin Srank, hello@smasty.net
-- License: MIT

module("rocksolver.utils", package.seeall)

local Package = require "rocksolver.Package"


-- Given list of Packages and a repo path template string,
-- generates a table in LuaDist manifest format.
-- repo_path should contain a %s placeholder for the package name.
-- Local manifest example:  packages/%s
-- Remote manifest example: git://github.com/LuaDist/%s.git
function generate_manifest(packages, repo_path)
    assert(type(packages) == "table", "utils.generate_manifest: Argument 'packages' is not a table.")
    assert(type(repo_path) == "string", "utils.generate_manifest: Argument 'repo_path' is not a string.")

    local modules = {}
    for _, pkg in pairs(packages) do
        assert(getmetatable(pkg) == Package, "utils.generate_manifest: Argument 'packages' does not contain Package instances.")
        if not modules[pkg.name] then
            modules[pkg.name] = {}
        end
        modules[pkg.name][pkg.version.string] = {
            dependencies = pkg.spec.dependencies,
            supported_platforms = pkg.spec.supported_platforms
        }
    end

    return {
        repo_path = repo_path,
        packages = modules
    }
end


-- Given a LuaDist manifest table, returns a list of Packages in the manifest.
-- Option argument is_local denotes a local manifest, therefore generated Packages
-- will be local as well, otherwise they will be remote.
function load_manifest(manifest, is_local)
    assert(type(manifest) == "table", "utils.load_manifest: Argument 'manifest' is not a table.")

    if not manifest.packages then return {} end
    local pkgs = {}
    for pkg_name, versions in pairs(manifest.packages) do
        for version, spec in pairs(versions) do
            table.insert(pkgs, Package(pkg_name, version, spec, is_local))
        end
    end

    return pkgs
end
