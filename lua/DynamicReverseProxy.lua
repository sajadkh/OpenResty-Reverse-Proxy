local _M = {}


-- Dind host address
function _M.getHost(service, defaultHost)
    local redis = require "resty.redis"
    local red = redis:new()
    red:set_timeouts(1000, 1000, 1000) -- 1 sec

    -- connect to the redis
    local ok, err = red:connect("redis", 6379)

    if not ok then
        ngx.say("failed to connect: ", err)
        return
    end

    -- ngx.var.request_uri
    -- Check redis db for finding host name
    local res, err = red:get(service)
    if not res then
        ngx.say("failed to get host: ", err)
        return
    end

    if res == ngx.null then
        -- Create default host name
        ok, err = red:set(service, defaultHost)
        -- Error not handled because it will be return default value and it will be set in next call

        return defaultHost
    else
        return res
    end
end

-- Find service name
function _M.getService(path)
    local paths = split(path, '[\\/]+')
    if #paths > 1 then
        local service = paths[2]
        table.remove(paths, 1)
        table.remove(paths, 1)
        local called_path_str = table.concat(paths, "/") 
        return service, called_path_str
    else
        return "default", ""
    end    
end

-- Split a String
function split(str, pat)
    local t = {}
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
       if s ~= 1 or cap ~= "" then
          table.insert(t, cap)
       end
       last_end = e+1
       s, e, cap = str:find(fpat, last_end)
    end
    if last_end <= #str then
       cap = str:sub(last_end)
       table.insert(t, cap)
    end
    return t
 end
 

return _M
