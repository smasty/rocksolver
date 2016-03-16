-- Tests of LuaDist's dependency resolving
-- Adopted from original luadist-git by mnicky.

local DependencySolver = require "rocksolver.DependencySolver"
local Package = require "rocksolver.Package"
local mfutils = require "rocksolver.manifest"

-- Convert package list to string
local function describe_packages(pkgs)
    if not pkgs then return nil end
    assert(type(pkgs) == "table")
    local str = ""

    for k,v in ipairs(pkgs) do
        if k == 1 then
            str = str .. v.name .. "-" .. tostring(v.version)
        else
            str = str .. " " .. v.name .. "-" .. tostring(v.version)
        end
    end

    return str
end

-- Call dependency resolver - converts manifest and installed tables
-- to the required format for ease of manual definition in the tests.
local function get_dependencies(pkg, manifest, installed, platform)

    local function generate_manifest(manifest)
        local modules = {}
        for _, pkg in pairs(manifest) do
            if not modules[pkg.name] then
                modules[pkg.name] = {}
            end
            modules[pkg.name][pkg.version] = {
                dependencies = pkg.deps,
                supported_platforms = type(pkg.platform) == "string" and {pkg.platform} or pkg.platform
            }
        end
        return {
            repo_path = repo_path,
            packages = modules
        }
    end

    for k, v in pairs(installed) do
        installed[k] = Package(v.name, v.version, {dependencies = v.deps})
    end

    local solver = DependencySolver(generate_manifest(manifest), platform or {"unix", "linux"})
    return solver:resolve_dependencies(pkg, installed)
end


-- Return test fail message.
local function pkgs_fail_msg(pkgs, err)
    if not pkgs then
        return "TEST FAILED - Returned packages were: 'nil' \n    Error was: \"" .. (tostring(err) or "nil") .. "\""
    else
        return "TEST FAILED - Returned packages were: '" .. describe_packages(pkgs) .. "' \n    Error was: \"" .. (tostring(err) or "nil") .. "\""
    end
end

-- Run all the 'tests' and display results.
local function run_tests(tests)
    local passed = 0
    local failed = 0

    for name, test in pairs(tests) do
        local ok, err = pcall(test)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print("In '" .. name .. "()': " .. err)
        end
    end
    if failed > 0 then print("----------------------------------") end
    print("Passed " .. passed .. "/" .. passed + failed .. " tests (" .. failed .. " failed).")
end


-- Test suite.
local tests = {}


--- ========== DEPENDENCY RESOLVING TESTS ====================================
-- normal dependencies

-- a depends b, install a
tests.depends_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {"b"}}
    manifest.b = {name = "b", version = "1.0"}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == "b-1.0 a-1.0", pkgs_fail_msg(pkgs, err))
end

-- a depends b, b depends c, install a
tests.depends_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {"b"}}
    manifest.b = {name = "b", version = "1.0", deps = {"c"}}
    manifest.c = {name = "c", version = "1.0"}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == "c-1.0 b-1.0 a-1.0", pkgs_fail_msg(pkgs, err))
end

-- a depends b, a depends c, a depends d, c depends f, c depends g, d depends c,
-- d depends e, d depends j, e depends h, e depends i, g depends l, j depends k,
-- install a
tests.depends_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {"b", "c", "d"}}
    manifest.b = {name = "b", version = "1.0"}
    manifest.c = {name = "c", version = "1.0", deps = {"f", "g"}}
    manifest.d = {name = "d", version = "1.0", deps = {"c", "e", "j"}}
    manifest.e = {name = "e", version = "1.0", deps = {"h", "i"}}
    manifest.f = {name = "f", version = "1.0"}
    manifest.g = {name = "g", version = "1.0", deps = {"l"}}
    manifest.h = {name = "h", version = "1.0"}
    manifest.i = {name = "i", version = "1.0"}
    manifest.j = {name = "j", version = "1.0", deps = {"k"}}
    manifest.k = {name = "k", version = "1.0"}
    manifest.l = {name = "l", version = "1.0"}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == "b-1.0 f-1.0 l-1.0 g-1.0 c-1.0 h-1.0 i-1.0 e-1.0 k-1.0 j-1.0 d-1.0 a-1.0", pkgs_fail_msg(pkgs, err))
end


--- circular dependencies

-- a depends b, b depends a, install a
tests.depends_circular_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {"b"}}
    manifest.b = {name = "b", version = "1.0", deps = {"a"}}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == nil and err:find("circular"), pkgs_fail_msg(pkgs, err))
end

-- a depends b, b depends a, install a + b
tests.depends_circular_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {"b"}}
    manifest.b = {name = "b", version = "1.0", deps = {"a"}}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == nil and err:find("circular"), pkgs_fail_msg(pkgs, err))

    local pkgs, err = get_dependencies('b', manifest, installed)
    assert(describe_packages(pkgs) == nil and err:find("circular"), pkgs_fail_msg(pkgs, err))
end

-- a depends b, b depends c, c depends a, install a
tests.depends_circular_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {"b"}}
    manifest.b = {name = "b", version = "1.0", deps = {"c"}}
    manifest.c = {name = "c", version = "1.0", deps = {"a"}}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == nil and err:find("circular"), pkgs_fail_msg(pkgs, err))
end

-- a depends b, b depends c, c depends d, d depends e, e depends b, install a
tests.depends_circular_4 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {"b"}}
    manifest.b = {name = "b", version = "1.0", deps = {"c"}}
    manifest.c = {name = "c", version = "1.0", deps = {"d"}}
    manifest.d = {name = "d", version = "1.0", deps = {"e"}}
    manifest.e = {name = "e", version = "1.0", deps = {"b"}}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == nil and err:find("circular"), pkgs_fail_msg(pkgs, err))
end


--- ========== VERSION RESOLVING TESTS  ======================================

--- check if the newest package version is chosen to install

-- a.1 & a.2 avalable, install a, check if the newest 'a' version is chosen
tests.version_install_newest_1 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name = "a", version = "1"}
    manifest.a2 = {name = "a", version = "2"}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == "a-2", pkgs_fail_msg(pkgs, err))
end

-- a depends b, b.1 & b.2 avalable, install a, check if the newest 'b' version is chosen
tests.version_install_newest_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {"b"}}
    manifest.b1 = {name = "b", version = "1"}
    manifest.b2 = {name = "b", version = "2"}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == "b-2 a-1.0", pkgs_fail_msg(pkgs, err))
end

-- provide more version types and check if the newest one is chosen to install
tests.version_install_newest_3 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name = "a", version = "0.9", deps = {"b"}}
    manifest.a2 = {name = "a", version = "1", deps = {"b"}}

    manifest.b1 = {name = "b", version = "1.99", deps = {"c"}}
    manifest.b2 = {name = "b", version = "2.0", deps = {"c"}}

    manifest.c1 = {name = "c", version = "2alpha", deps = {"d"}}
    manifest.c2 = {name = "c", version = "2beta", deps = {"d"}}

    manifest.d1 = {name = "d", version = "1rc2", deps = {"e"}}
    manifest.d2 = {name = "d", version = "1rc3", deps = {"e"}}

    manifest.e1 = {name = "e", version = "3.1beta", deps = {"f"}}
    manifest.e2 = {name = "e", version = "3.1pre", deps = {"f"}}

    manifest.f1 = {name = "f", version = "3.1pre", deps = {"g"}}
    manifest.f2 = {name = "f", version = "3.1rc", deps = {"g"}}

    manifest.g1 = {name = "g", version = "1rc", deps = {"h"}}
    manifest.g2 = {name = "g", version = "11.0", deps = {"h"}}

    manifest.h1 = {name = "h", version = "1alpha2"}
    manifest.h2 = {name = "h", version = "1work2"}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == "h-1alpha2 g-11.0 f-3.1rc e-3.1pre d-1rc3 c-2beta b-2.0 a-1", pkgs_fail_msg(pkgs, err))
end

-- provide more version types and check if the newest one is chosen to install
tests.version_install_newest_4 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name = "a", version = "1.1", deps = {"b"}}
    manifest.a2 = {name = "a", version = "2alpha", deps = {"b"}}

    manifest.b1 = {name = "b", version = "1.2", deps = {"c"}}
    manifest.b2 = {name = "b", version = "1.2beta", deps = {"c"}}

    manifest.c1 = {name = "c", version = "1rc3", deps = {"d"}}
    manifest.c2 = {name = "c", version = "1.1rc2", deps = {"d"}}

    manifest.d1 = {name = "d", version = "2.1beta3"}
    manifest.d2 = {name = "d", version = "2.2alpha2"}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == "d-2.2alpha2 c-1.1rc2 b-1.2 a-2alpha", pkgs_fail_msg(pkgs, err))
end


--- check if version in depends is correctly used

tests.version_of_depends_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {"b <= 1"}}

    manifest.b1 = {name = "b", version = "1.0", deps = {"c >= 2"}}
    manifest.b2 = {name = "b", version = "2.0", deps = {"c >= 2"}}

    manifest.c1 = {name = "c", version = "1.9", deps = {"d ~> 3.3"}}
    manifest.c2 = {name = "c", version = "2.0", deps = {"d ~> 3.3"}}
    manifest.c3 = {name = "c", version = "2.1", deps = {"d ~> 3.3"}}

    manifest.d1 = {name = "d", version = "3.2"}
    manifest.d2 = {name = "d", version = "3.3"}
    manifest.d3 = {name = "d", version = "3.3.1"}
    manifest.d4 = {name = "d", version = "3.3.2"}
    manifest.d5 = {name = "d", version = "3.4"}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == "d-3.3.2 c-2.1 b-1.0 a-1.0", pkgs_fail_msg(pkgs, err))
end

tests.version_of_depends_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {"b ~= 1.0"}}

    manifest.b1 = {name = "b", version = "1.0", deps = {"c < 2.1"}}
    manifest.b2 = {name = "b", version = "0.9", deps = {"c < 2.1"}}

    manifest.c1 = {name = "c", version = "2.0.9", deps = {"d == 4.4alpha"}}
    manifest.c2 = {name = "c", version = "2.1.0", deps = {"d == 4.4alpha"}}
    manifest.c3 = {name = "c", version = "2.1.1", deps = {"d == 4.4alpha"}}

    manifest.d1 = {name = "d", version = "4.0"}
    manifest.d2 = {name = "d", version = "4.5"}
    manifest.d3 = {name = "d", version = "4.4beta"}
    manifest.d4 = {name = "d", version = "4.4alpha"}
    manifest.d5 = {name = "d", version = "4.4"}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == "d-4.4alpha c-2.0.9 b-0.9 a-1.0", pkgs_fail_msg(pkgs, err))
end

tests.version_of_depends_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {"b > 1.2"}}

    manifest.b1 = {name = "b", version = "1.2", deps = {"c ~= 2.1.1"}}
    manifest.b2 = {name = "b", version = "1.2alpha", deps = {"c ~= 2.1.1"}}
    manifest.b3 = {name = "b", version = "1.2beta", deps = {"c ~= 2.1.1"}}
    manifest.b5 = {name = "b", version = "1.3rc", deps = {"c ~= 2.1.1"}}
    manifest.b4 = {name = "b", version = "1.3", deps = {"c ~= 2.1.1"}}

    manifest.c1 = {name = "c", version = "2.0.9"}
    manifest.c3 = {name = "c", version = "2.1.1"}
    manifest.c2 = {name = "c", version = "2.1.0"}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == "c-2.1.0 b-1.3 a-1.0", pkgs_fail_msg(pkgs, err))
end

tests.version_of_depends_4 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name = "a", version = "1.0"}
    manifest.a2 = {name = "a", version = "2.0"}

    manifest.b1 = {name = "b", version = "1.0", deps = {"a >= 1.0"}}
    manifest.b2 = {name = "b", version = "2.0", deps = {"a >= 2.0"}}

    manifest.c = {name = "c", version = "1.0", deps = {"a ~> 1.0","b >= 1.0"}}

    local pkgs, err = get_dependencies('c', manifest, installed)
    assert(describe_packages(pkgs) == "a-1.0 b-1.0 c-1.0", pkgs_fail_msg(pkgs, err))
end

tests.version_of_depends_5 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name = "a", version = "1.0"}
    manifest.a2 = {name = "a", version = "2.0", deps = {"x"}}

    manifest.b = {name = "b", version = "1.0", deps = {"a == 1.0"}}

    manifest.c = {name = "c", version = "1.0", deps = {"a >= 1.0","b >= 1.0"}}

    local pkgs, err = get_dependencies('c', manifest, installed)
    assert(describe_packages(pkgs) == "a-1.0 b-1.0 c-1.0", pkgs_fail_msg(pkgs, err))
end

-- TODO: Without trying all possible permutations of packages to install
-- LuaDist probably can't find a solution to this.
--[[
tests.version_of_depends_6 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name = "a", version = "1.0"}
    manifest.a2 = {name = "a", version = "2.0"}

    manifest.b = {name = "b", version = "1.0", deps = {"a == 1.0"}}

    manifest.c = {name = "c", version = "1.0", deps = {"a >= 1.0","b >= 1.0"}}

    local pkgs, err = get_dependencies('c', manifest, installed)
    assert(describe_packages(pkgs) == "a-1.0 b-1.0 c-1.0", pkgs_fail_msg(pkgs, err))
end
--]]

-- TODO: Without trying all possible permutations of packages to install
-- LuaDist probably can't find a solution to this.
--[[
tests.version_of_depends_7 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name = "a", version = "1.0"}
    manifest.a2 = {name = "a", version = "2.0", deps = {"d == 1.0"}}

    manifest.d1 = {name = "d", version = "1.0"}
    manifest.d2 = {name = "d", version = "2.0"}

    manifest.b = {name = "b", version = "1.0", deps = {"a == 1.0"}}

    manifest.c = {name = "c", version = "1.0", deps = {"a >= 1.0","b >= 1.0"}}

    local pkgs, err = get_dependencies('c', manifest, installed)
    assert(describe_packages(pkgs) == "a-1.0 b-1.0 c-1.0", pkgs_fail_msg(pkgs, err))
end
--]]

--- check if the installed package is in needed version

-- a-1.2 installed, b depends a >= 1.2, install b
tests.version_of_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.2"}
    manifest.b = {name = "b", version = "1.0", deps = {"a >= 1.2"}}
    installed.a = manifest.a

    local pkgs, err = get_dependencies('b', manifest, installed)
    assert(describe_packages(pkgs) == "b-1.0", pkgs_fail_msg(pkgs, err))
end

-- a-1.2 installed, a-1.3 also available, b depends a >= 1.2, install b
tests.version_of_installed_2 = function()
    local manifest, installed = {}, {}
    manifest.a12 = {name = "a", version = "1.2"}
    manifest.a13 = {name = "a", version = "1.3"}
    manifest.b = {name = "b", version = "1.0", deps = {"a >= 1.2"}}
    installed.a12 = manifest.a12

    local pkgs, err = get_dependencies('b', manifest, installed)
    assert(describe_packages(pkgs) == "b-1.0", pkgs_fail_msg(pkgs, err))
end

-- a-1.2 installed, b depends a >= 1.4, install b
tests.version_of_installed_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.2"}
    manifest.b = {name = "b", version = "1.0", deps = {"a >= 1.4"}}
    installed.a = manifest.a

    local pkgs, err = get_dependencies('b', manifest, installed)
    assert(describe_packages(pkgs) == nil and err:find("but installed at version"), pkgs_fail_msg(pkgs, err))
end

-- a-1.2 installed, a-1.3 also available, b depends a >= 1.3, install b
tests.version_of_installed_4 = function()
    local manifest, installed = {}, {}
    manifest.a12 = {name = "a", version = "1.2"}
    manifest.a13 = {name = "a", version = "1.3"}
    manifest.b = {name = "b", version = "1.0", deps = {"a >= 1.3"}}
    installed.a12 = manifest.a12

    local pkgs, err = get_dependencies('b', manifest, installed)
    assert(describe_packages(pkgs) == nil and err:find("but installed at version"), pkgs_fail_msg(pkgs, err))
end



--- ========== OTHER EXCEPTIONAL STATES  =====================================

--- states when no packages to install are found

-- when no such package exists
tests.no_packages_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0"}

    local pkgs, err = get_dependencies('x', manifest, installed)
    assert(describe_packages(pkgs) == nil and err:find("No suitable candidate"), pkgs_fail_msg(pkgs, err))
end

-- when no such dependency exists
tests.no_packages_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {"x"}}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == nil and err:find("No suitable candidate"), pkgs_fail_msg(pkgs, err))
end

-- when no such dependency version exists
tests.no_packages_to_install_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {"b > 1.0"}}
    manifest.b = {name = "b", version = "0.9"}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == nil and err:find("No suitable candidate"), pkgs_fail_msg(pkgs, err))
end

-- when all required packages are installed
tests.no_packages_to_install_4 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0"}
    manifest.b = {name = "b", version = "0.9"}
    installed.a = manifest.a
    installed.b = manifest.b

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == "", pkgs_fail_msg(pkgs, err))
    local pkgs, err = get_dependencies('b', manifest, installed)
    assert(describe_packages(pkgs) == "", pkgs_fail_msg(pkgs, err))
end

--- states when installed pkg is not in manifest

-- normal installed package
tests.installed_not_in_manifest_1 = function()
    local manifest, installed = {}, {}
    manifest.b = {name = "b", version = "0.9", deps = {"a"}}
    installed.a = {name = "a", version = "1.0"}

    local pkgs, err = get_dependencies('b', manifest, installed)
    assert(describe_packages(pkgs) == "b-0.9", pkgs_fail_msg(pkgs, err))
end


--- ========== Platform support checking =====================================

-- no package of required platform
tests.platform_checks_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", platform = "win32"}
    manifest.b = {name = "b", version = "0.9", platform = "bsd"}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == nil and err:find("No suitable candidate"), pkgs_fail_msg(pkgs, err))
    local pkgs, err = get_dependencies('b', manifest, installed)
    assert(describe_packages(pkgs) == nil and err:find("No suitable candidate"), pkgs_fail_msg(pkgs, err))
end

-- no package of required platform
tests.platform_checks_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", platform = "!unix"}
    manifest.b = {name = "b", version = "0.9", platform = {"bsd", "win32", "darwin"}}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == nil and err:find("No suitable candidate"), pkgs_fail_msg(pkgs, err))
    local pkgs, err = get_dependencies('b', manifest, installed)
    assert(describe_packages(pkgs) == nil and err:find("No suitable candidate"), pkgs_fail_msg(pkgs, err))
end

-- only some packages have required arch
tests.platform_checks_3 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name = "a", version = "1.1", platform = "win32"}
    manifest.a2 = {name = "a", version = "1.0"}
    manifest.b1 = {name = "b", version = "1.9", platform = "bsd"}
    manifest.b2 = {name = "b", version = "0.8"}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == "a-1.0", pkgs_fail_msg(pkgs, err))
    local pkgs, err = get_dependencies('b', manifest, installed)
    assert(describe_packages(pkgs) == "b-0.8", pkgs_fail_msg(pkgs, err))
end

--- ========== OS specific dependencies  =====================================

-- only OS specific dependencies
tests.os_specific_depends_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {platforms = {unix = {"b", "c"}}}}
    manifest.b = {name = "b", version = "0.9"}
    manifest.c = {name = "c", version = "0.9"}

    local pkgs, err = get_dependencies('a', manifest, installed, {"unix"})
    assert(describe_packages(pkgs) == "b-0.9 c-0.9 a-1.0", pkgs_fail_msg(pkgs, err))
end

-- OS specific dependency of other platform
tests.os_specific_depends_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {platforms = {win32 = {"b"}}}}
    manifest.b = {name = "b", version = "0.9"}

    local pkgs, err = get_dependencies('a', manifest, installed)
    assert(describe_packages(pkgs) == "a-1.0", pkgs_fail_msg(pkgs, err))
end

-- normal and OS specific dependencies
tests.os_specific_depends_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name = "a", version = "1.0", deps = {"c", platforms = {unix = {"b"}}, "d"}}
    manifest.b = {name = "b", version = "0.9"}
    manifest.c = {name = "c", version = "0.9"}
    manifest.d = {name = "d", version = "0.9"}

    local pkgs, err = get_dependencies('a', manifest, installed, {"unix"})
    assert(describe_packages(pkgs) == "c-0.9 d-0.9 b-0.9 a-1.0", pkgs_fail_msg(pkgs, err))
end


--- ========== INSTALL SPECIFIC VERSION  =====================================

--- install specific version

-- a-1.0 available, a-2.0 available, install a-1.0
tests.install_specific_version_1 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name = "a", version = "1.0"}
    manifest.a2 = {name = "a", version = "2.0"}

    local pkgs, err = get_dependencies('a = 1.0', manifest, installed)
    assert(describe_packages(pkgs) == "a-1.0", pkgs_fail_msg(pkgs, err))
end

-- a-1.0 available, a-2.0 available, install a < 2.0
tests.install_specific_version_2 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name = "a", version = "1.0"}
    manifest.a2 = {name = "a", version = "2.0"}

    local pkgs, err = get_dependencies('a < 2.0', manifest, installed)
    assert(describe_packages(pkgs) == "a-1.0", pkgs_fail_msg(pkgs, err))
end

-- a-1.0 available, a-2.0 available, install a <= 2.0
tests.install_specific_version_3 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name = "a", version = "1.0"}
    manifest.a2 = {name = "a", version = "2.0"}

    local pkgs, err = get_dependencies('a <= 2.0', manifest, installed)
    assert(describe_packages(pkgs) == "a-2.0", pkgs_fail_msg(pkgs, err))
end

-- a-1.0 available, a-2.0 available, install a >= 3.0
tests.install_specific_version_4 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name = "a", version = "1.0"}
    manifest.a2 = {name = "a", version = "2.0"}

    local pkgs, err = get_dependencies('a >= 3.0', manifest, installed)
    assert(describe_packages(pkgs) == nil and err:find("No suitable candidate"), pkgs_fail_msg(pkgs, err))
end



-- actually run the test suite
run_tests(tests)
