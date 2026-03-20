local events = require("neo-tree.events")
local manager = require("neo-tree.sources.manager")
local source = require("neo-tree.sources.hierarchy.lib.source")
local utils = require("neo-tree.utils")

local spec = {
  root_label = "TYPE HIERARCHY",
  prepare_method = "textDocument/prepareTypeHierarchy",
  supports_client = function(client)
    return client.server_capabilities.typeHierarchyProvider ~= nil
  end,
  directions = {
    {
      key = "supertypes",
      label = "supertypes",
      child_method = "typeHierarchy/supertypes",
      empty_children_label = "No supertypes",
      relation_builder = function(item)
        return item
      end,
    },
    {
      key = "subtypes",
      label = "subtypes",
      child_method = "typeHierarchy/subtypes",
      empty_children_label = "No subtypes",
      relation_builder = function(item)
        return item
      end,
    },
  },
}

local M = {
  name = "type_hierarchy",
  display_name = "  Type Hierarchy ",
  default_config = require("neo-tree.sources.type_hierarchy.defaults"),
  commands = require("neo-tree.sources.type_hierarchy.commands"),
  components = require("neo-tree.sources.type_hierarchy.components"),
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
