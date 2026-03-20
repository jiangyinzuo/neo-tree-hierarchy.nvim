local DEFAULT_KIND_NAMES = {
  [0] = "Root",
  [1] = "File",
  [2] = "Module",
  [3] = "Namespace",
  [4] = "Package",
  [5] = "Class",
  [6] = "Method",
  [7] = "Property",
  [8] = "Field",
  [9] = "Constructor",
  [10] = "Enum",
  [11] = "Interface",
  [12] = "Function",
  [13] = "Variable",
  [14] = "Constant",
  [15] = "String",
  [16] = "Number",
  [17] = "Boolean",
  [18] = "Array",
  [19] = "Object",
  [20] = "Key",
  [21] = "Null",
  [22] = "EnumMember",
  [23] = "Struct",
  [24] = "Event",
  [25] = "Operator",
  [26] = "TypeParameter",
}

local M = {}

M.create = function(custom_kinds, kinds_display)
  local kind_names = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULT_KIND_NAMES), custom_kinds or {})
  local displays = kinds_display or {}
  local unknown = displays.Unknown or {}

  return function(kind_id)
    local kind_name = kind_names[kind_id]
    return vim.tbl_extend(
      "force",
      { name = kind_name or ("Unknown: " .. tostring(kind_id)), icon = "?", hl = "" },
      kind_name and (displays[kind_name] or unknown) or unknown
    )
  end
end

return M
