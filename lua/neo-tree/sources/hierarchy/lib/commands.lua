local cc = require("neo-tree.sources.common.commands")
local filters = require("neo-tree.sources.common.filters")
local manager = require("neo-tree.sources.manager")
local source = require("neo-tree.sources.hierarchy.lib.source")
local utils = require("neo-tree.utils")

local M = {}

M.create = function(source_name)
  local commands = {}

  commands.refresh = utils.wrap(manager.refresh, source_name)
  commands.redraw = utils.wrap(manager.redraw, source_name)
  commands.jump_to_item = source.jump_to_item
  commands.show_item = source.show_item
  commands.open = commands.jump_to_item
  commands.toggle_node = function(state)
    cc.toggle_node(state, utils.wrap(source.toggle_directory, state))
  end
  commands.toggle_direction = source.toggle_direction
  commands.filter_on_submit = function(state)
    filters.show_filter(state, true, true)
  end
  commands.filter = function(state)
    filters.show_filter(state, true)
  end

  cc._add_common_commands(commands, "node")
  cc._add_common_commands(commands, "^close_window$")
  cc._add_common_commands(commands, "source$")
  cc._add_common_commands(commands, "preview")
  cc._add_common_commands(commands, "^cancel$")
  cc._add_common_commands(commands, "help")
  cc._add_common_commands(commands, "^toggle_auto_expand_width$")

  return commands
end

return M
