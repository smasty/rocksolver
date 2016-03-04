-- LunaCI package definition
-- Part of the LuaDist project - http://luadist.org
-- Author: Martin Srank, martin@smasty.net
-- License: MIT

module("lunaci.package", package.seeall)


Package = {
}

function Package:new()
    o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

