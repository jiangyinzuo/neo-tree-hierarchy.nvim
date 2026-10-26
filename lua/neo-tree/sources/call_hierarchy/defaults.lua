local defaults = require("neo-tree.sources.hierarchy.lib.defaults")

local M = vim.deepcopy(defaults)

M.auto_expand_depth = 1

return M
