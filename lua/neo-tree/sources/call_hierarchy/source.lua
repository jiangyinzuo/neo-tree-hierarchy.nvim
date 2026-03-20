local M = {
  name = "call_hierarchy",
  display_name = " 󰃷 Call Hierarchy ",
  default_config = require("neo-tree.sources.call_hierarchy.defaults"),
  commands = require("neo-tree.sources.call_hierarchy.commands"),
  components = require("neo-tree.sources.call_hierarchy.components"),
}

return M
