local events = require("neo-tree.events")
local manager = require("neo-tree.sources.manager")
local source = require("neo-tree.sources.hierarchy.lib.source")
local utils = require("neo-tree.utils")

local spec = {
  root_label = "CALL HIERARCHY",
  prepare_method = "textDocument/prepareCallHierarchy",
  supports_client = function(client)
    return client.server_capabilities.callHierarchyProvider ~= nil
  end,
  directions = {
    {
      key = "incoming",
      label = "incoming calls",
      child_method = "callHierarchy/incomingCalls",
      empty_children_label = "No incoming calls",
      relation_builder = function(relation)
        return relation.from, string.format("%d call site%s", #(relation.fromRanges or {}), #(relation.fromRanges or {}) == 1 and "" or "s")
      end,
    },
    {
      key = "outgoing",
      label = "outgoing calls",
      child_method = "callHierarchy/outgoingCalls",
      empty_children_label = "No outgoing calls",
      relation_builder = function(relation)
        return relation.to, string.format("%d call site%s", #(relation.fromRanges or {}), #(relation.fromRanges or {}) == 1 and "" or "s")
      end,
    },
  },
}

local M = {
  name = "call_hierarchy",
  display_name = " 󰃷 Call Hierarchy ",
  default_config = require("neo-tree.sources.call_hierarchy.defaults"),
  commands = require("neo-tree.sources.call_hierarchy.commands"),
  components = require("neo-tree.sources.call_hierarchy.components"),
}

M.navigate = function(state, path, path_to_reveal, callback, async)
  state.lsp_winid = utils.get_appropriate_window(state)
  state.lsp_bufnr = vim.api.nvim_win_get_buf(state.lsp_winid)
  state.hierarchy = state.hierarchy or source.setup(state.config or state, spec)
  source.navigate(state, callback)
end

M.setup = function(config, global_config)
  local _ = global_config
  local shared = source.setup(config, spec)
  manager.subscribe(M.name, {
    event = events.VIM_BUFFER_ENTER,
    handler = function()
      local state = manager.get_state(M.name)
      if state then
        state.hierarchy = shared
      end
    end,
  })
end

return M
