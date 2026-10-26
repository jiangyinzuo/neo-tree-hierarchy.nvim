local common = require("neo-tree.sources.common.components")
local highlights = require("neo-tree.ui.highlights")

local M = {}

-- 空状态是辅助提示，不继承目录或根节点的粗体样式。
local function define_message_highlight()
  vim.api.nvim_set_hl(0, "NeoTreeHierarchyMessage", { fg = "#777777", ctermfg = 243, bold = false })
end
define_message_highlight()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("NeoTreeHierarchyHighlights", { clear = true }),
  callback = define_message_highlight,
})

local function get_kind(node)
  return node.extra and node.extra.kind or nil
end

M.kind_icon = function(config, node, state)
  local kind = get_kind(node)
  local icon = {
    text = kind and kind.icon or (config.default or ""),
    highlight = kind and kind.hl or highlights.FILE_ICON,
  }

  if config.provider then
    icon = config.provider(icon, node, state) or icon
  end

  return icon
end

M.kind_name = function(_, node)
  local kind = get_kind(node)
  if not kind or not kind.name or node.type == "message" then
    return {}
  end

  return {
    text = kind.name,
    highlight = kind.hl or highlights.FILE_NAME,
  }
end

M.detail = function(config, node)
  local detail = node.extra and node.extra.detail or nil
  if not detail or detail == "" then
    return {}
  end

  return {
    text = (config.prefix ~= nil and config.prefix or " ") .. detail,
    highlight = config.highlight or highlights.DIM_TEXT,
  }
end

M.name = function(config, node)
  if node.type == "message" then
    return { text = node.name, highlight = "NeoTreeHierarchyMessage" }
  end
  local kind = get_kind(node)
  return {
    text = node.name,
    highlight = (kind and kind.hl) or config.highlight or highlights.FILE_NAME,
  }
end

return vim.tbl_deep_extend("force", common, M)
