local defaults = require("neo-tree.sources.hierarchy.lib.defaults")

local M = vim.deepcopy(defaults)

M.window.mappings["<cr>"] = "jump_to_item"
M.window.mappings["o"] = "jump_to_item"
M.window.mappings["P"] = "toggle_preview"

return M
