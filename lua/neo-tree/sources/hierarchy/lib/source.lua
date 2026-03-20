local renderer = require("neo-tree.ui.renderer")
local util = vim.lsp.util

local client_filter_factory = require("neo-tree.sources.hierarchy.lib.client_filters")
local kind_factory = require("neo-tree.sources.hierarchy.lib.kinds")

local M = {}

local function get_clients(bufnr)
  return vim.lsp.get_clients({ bufnr = bufnr })
end

local function get_client_encoding(client)
  return client and (client.offset_encoding or client.encoding) or nil
end

local function get_item_range(item)
  return item and (item.selectionRange or item.range) or nil
end

local function get_item_positions(item)
  local range = get_item_range(item)
  if not range then
    return nil, nil
  end

  return range.start, range["end"]
end

local function build_location(item)
  return {
    uri = item.uri,
    range = get_item_range(item),
  }
end

local function show_document_safe(location, position_encoding, opts)
  local uri = location.targetUri or location.uri
  if not uri then
    return false
  end

  local bufnr = vim.uri_to_bufnr(uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end

  return util.show_document(location, position_encoding, opts)
end

local function make_message_node(id, name, path, kind_getter)
  return {
    id = id,
    name = name,
    path = path,
    type = "message",
    children = {},
    extra = {
      kind = kind_getter(0),
    },
  }
end

local function make_item_node(state, opts)
  local kind = state.hierarchy.kind_getter(opts.item.kind)
  local detail = opts.detail_suffix
  local position, end_position = get_item_positions(opts.item)

  return {
    id = opts.id,
    name = opts.item.name,
    path = vim.uri_to_fname(opts.item.uri),
    type = "directory",
    loaded = false,
    children = {},
    extra = {
      kind = kind,
      item = opts.item,
      client_id = opts.client_id,
      position_encoding = opts.position_encoding,
      relation = opts.relation,
      detail = detail,
      position = position,
      end_position = end_position,
    },
  }
end

local function build_child_nodes(state, parent_id, client_id, position_encoding, items, relation_builder)
  local children = {}
  for index, relation in ipairs(items or {}) do
    local item, detail_suffix = relation_builder(relation)
    table.insert(children, make_item_node(state, {
      id = string.format("%s.%d", parent_id, index),
      item = item,
      client_id = client_id,
      position_encoding = position_encoding,
      relation = relation,
      detail_suffix = detail_suffix,
    }))
  end
  return children
end

local function render_empty(state, callback, message)
  renderer.show_nodes({
    make_message_node("0", message, state.path or "", state.hierarchy.kind_getter),
  }, state, nil, callback)
end

local function request(client, bufnr, method, params, callback)
  client:request(method, params, function(err, result)
    vim.schedule(function()
      callback(err, result)
    end)
  end, bufnr)
end

local function request_all(clients, bufnr, method, params_factory, callback)
  if #clients == 0 then
    callback({})
    return
  end

  local pending = #clients
  local responses = {}

  for _, client in ipairs(clients) do
    local params = type(params_factory) == "function" and params_factory(client) or params_factory
    request(client, bufnr, method, params, function(err, result)
      responses[client.id] = {
        err = err,
        result = result,
      }
      pending = pending - 1
      if pending == 0 then
        callback(responses)
      end
    end)
  end
end

local function collect_supported_clients(state, bufnr)
  local supported = {}
  for _, client in ipairs(get_clients(bufnr)) do
    if state.hierarchy.supports_client(client) then
      table.insert(supported, client)
    end
  end
  return state.hierarchy.client_filter(supported)
end

local function resolve_node_bufnr(state, node)
  local item = node and node.extra and node.extra.item or nil
  if item and item.uri then
    return vim.uri_to_bufnr(item.uri)
  end

  if state.lsp_bufnr and vim.api.nvim_buf_is_valid(state.lsp_bufnr) then
    return state.lsp_bufnr
  end

  return nil
end

local function resolve_node_client(state, node, bufnr)
  local client_id = node.extra and node.extra.client_id or nil
  local client = client_id and vim.lsp.get_client_by_id(client_id) or nil
  if client then
    return client
  end

  local clients = collect_supported_clients(state, bufnr)
  return clients[1]
end

local function build_root_nodes(state, bufname, clients, responses)
  local roots = {}
  local filename = vim.fn.fnamemodify(bufname, ":t")

  for _, client in ipairs(clients) do
    local response = responses[client.id]
    local prepared = response and response.result or nil
    if type(prepared) == "table" and #prepared > 0 then
      local children = {}
      for index, item in ipairs(prepared) do
        table.insert(children, make_item_node(state, {
          id = string.format("%d.%d", #roots, index),
          item = item,
          client_id = client.id,
          position_encoding = get_client_encoding(client),
        }))
      end

      table.insert(roots, {
        id = tostring(#roots),
        name = string.format("%s (%s) in %s", state.hierarchy.direction_label or state.hierarchy.direction_key or state.hierarchy.root_label, client.name, filename),
        path = bufname,
        type = "root",
        children = children,
        extra = {
          kind = state.hierarchy.kind_getter(0),
          client_id = client.id,
          position_encoding = get_client_encoding(client),
        },
      })
    end
  end

  return roots
end

local function load_directory(state, node)
  local item = node.extra and node.extra.item or nil
  local bufnr = resolve_node_bufnr(state, node)
  local client = bufnr and resolve_node_client(state, node, bufnr) or nil
  if not item or not client or not bufnr then
    node.loaded = true
    renderer.redraw(state)
    return
  end

  node.extra.client_id = client.id
  node.extra.position_encoding = get_client_encoding(client)
  state.lsp_bufnr = bufnr

  request(client, bufnr, state.hierarchy.child_method, { item = item }, function(err, result)
    if err then
      node.loaded = true
      renderer.show_nodes({
        make_message_node(node:get_id() .. ".0", err.message or "Hierarchy request failed", node.path, state.hierarchy.kind_getter),
      }, state, node:get_id())
      node:expand()
      renderer.redraw(state)
      return
    end

    local children = build_child_nodes(
      state,
      node:get_id(),
      client.id,
      get_client_encoding(client),
      result,
      state.hierarchy.relation_builder
    )

    if #children == 0 then
      children = {
        make_message_node(node:get_id() .. ".0", state.hierarchy.empty_children_label, node.path, state.hierarchy.kind_getter),
      }
    end

    node.loaded = true
    renderer.show_nodes(children, state, node:get_id())
    node:expand()
    renderer.redraw(state)
  end)
end

local function auto_expand_roots(state)
  if (state.hierarchy.auto_expand_depth or 0) < 1 then
    return
  end

  local tree = state.tree
  if not tree then
    return
  end

  for _, root in ipairs(tree:get_nodes() or {}) do
    for _, child in ipairs(tree:get_nodes(root:get_id()) or {}) do
      if child.type == "directory" and child.loaded == false then
        load_directory(state, child)
      end
    end
  end
end

M.setup = function(config, spec)
  config = config or {}

  local directions = spec.directions
  local direction_key = directions and directions[1] and directions[1].key or nil

  return {
    spec = spec,
    kind_getter = kind_factory.create(config.custom_kinds, config.kinds),
    client_filter = client_filter_factory.build(config.client_filters),
    supports_client = spec.supports_client,
    root_label = spec.root_label,
    auto_expand_depth = config.auto_expand_depth or 0,
    -- active direction (child_method + empty_children_label may differ per direction)
    child_method = direction_key and directions[1].child_method or spec.child_method,
    empty_children_label = direction_key and directions[1].empty_children_label or spec.empty_children_label,
    relation_builder = direction_key and directions[1].relation_builder or spec.relation_builder,
    direction_label = direction_key and (directions[1].label or directions[1].key) or spec.root_label,
    direction_key = direction_key,
  }
end

M.navigate = function(state, callback)
  local winid = assert(state.lsp_winid)
  local bufnr = assert(state.lsp_bufnr)
  local clients = collect_supported_clients(state, bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  state.path = bufname

  if #clients == 0 then
    render_empty(state, callback, "No hierarchy provider found for " .. vim.fn.fnamemodify(bufname, ":t"))
    return
  end

  request_all(clients, bufnr, state.hierarchy.spec.prepare_method, function(client)
    return util.make_position_params(winid, get_client_encoding(client))
  end, function(responses)
    local roots = build_root_nodes(state, bufname, clients, responses)
    if #roots == 0 then
      render_empty(state, callback, "No hierarchy items found for " .. vim.fn.fnamemodify(bufname, ":t"))
      return
    end

    renderer.show_nodes(roots, state, nil, function()
      if callback then callback() end
      auto_expand_roots(state)
    end)
  end)
end

M.toggle_directory = function(state, node)
  node = node or state.tree:get_node()
  if not node or node.type ~= "directory" then
    return
  end

  if node.loaded == false then
    load_directory(state, node)
    return
  end

  local updated = false
  if node:has_children() then
    if node:is_expanded() then
      updated = node:collapse()
    else
      updated = node:expand()
    end
  end

  if updated then
    renderer.redraw(state)
  end
end

M.toggle_direction = function(state)
  local directions = state.hierarchy.spec.directions
  if not directions or #directions < 2 then
    return
  end

  local current = state.hierarchy.direction_key
  local next_dir = nil
  for i, dir in ipairs(directions) do
    if dir.key == current then
      next_dir = directions[(i % #directions) + 1]
      break
    end
  end
  if not next_dir then
    next_dir = directions[1]
  end

  state.hierarchy.direction_key = next_dir.key
  state.hierarchy.child_method = next_dir.child_method
  state.hierarchy.empty_children_label = next_dir.empty_children_label
  state.hierarchy.relation_builder = next_dir.relation_builder
  state.hierarchy.direction_label = next_dir.label or next_dir.key

  -- re-navigate to rebuild the tree with the new direction label
  local manager = require("neo-tree.sources.manager")
  manager.refresh(state.name)
end

M.jump_to_item = function(state, node)
  node = node or state.tree:get_node()
  if not node or node.type == "root" or node.type == "message" then
    return
  end

  local item = node.extra and node.extra.item or nil
  local position_encoding = node.extra and node.extra.position_encoding or nil
  if not item or not position_encoding then
    return
  end

  show_document_safe(build_location(item), position_encoding, { reuse_win = true, focus = true })
end

M.show_item = function(state, node)
  node = node or state.tree:get_node()
  if not node or node.type == "root" or node.type == "message" then
    return
  end

  local item = node.extra and node.extra.item or nil
  local position_encoding = node.extra and node.extra.position_encoding or nil
  if not item or not position_encoding then
    return
  end

  local neo_win = vim.api.nvim_get_current_win()
  show_document_safe(build_location(item), position_encoding, { reuse_win = true, focus = false })
  if vim.api.nvim_win_is_valid(neo_win) then
    vim.api.nvim_set_current_win(neo_win)
  end
end

return M
