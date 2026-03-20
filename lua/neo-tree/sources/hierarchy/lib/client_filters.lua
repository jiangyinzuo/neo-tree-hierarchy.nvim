local M = {}

local function always_true()
  return true
end

local function make_filter(cfg_flt)
  if type(cfg_flt) ~= "table" then
    return always_true
  end

  if type(cfg_flt.fn) == "function" then
    return cfg_flt.fn
  end

  if cfg_flt.allow_only then
    local allowed = {}
    for _, client_name in ipairs(cfg_flt.allow_only) do
      allowed[client_name] = true
    end
    return function(client_name)
      return allowed[client_name] == true
    end
  end

  if cfg_flt.ignore then
    local ignored = {}
    for _, client_name in ipairs(cfg_flt.ignore) do
      ignored[client_name] = true
    end
    return function(client_name)
      return ignored[client_name] ~= true
    end
  end

  return always_true
end

M.build = function(cfg_flt)
  local filter_type = "first"
  if cfg_flt == "all" or (type(cfg_flt) == "table" and cfg_flt.type == "all") then
    filter_type = "all"
  end

  local filter_fn = make_filter(cfg_flt)

  return function(clients)
    if type(clients) ~= "table" then
      return {}
    end

    local filtered = {}
    for _, client in ipairs(clients) do
      if filter_fn(client.name, client) then
        table.insert(filtered, client)
        if filter_type ~= "all" then
          break
        end
      end
    end

    return filtered
  end
end

return M
