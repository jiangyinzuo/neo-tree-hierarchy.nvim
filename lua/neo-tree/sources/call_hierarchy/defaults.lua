local defaults = require("neo-tree.sources.hierarchy.lib.defaults")

local M = vim.deepcopy(defaults)

M.auto_expand_depth = 1
M.window.mappings["o"] = "jump_to_item"
M.window.mappings["P"] = "toggle_preview"

return M
