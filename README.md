# neo-tree-hierarchy.nvim

Extra Neo-tree sources for browsing LSP call hierarchies and type hierarchies.

## What this plugin provides

- `call_hierarchy`
  - prepares items with `textDocument/prepareCallHierarchy`
  - browses `incoming calls` and `outgoing calls`
- `type_hierarchy`
  - prepares items with `textDocument/prepareTypeHierarchy`
  - browses `supertypes` and `subtypes`
- shared hierarchy runtime under `lua/neo-tree/sources/hierarchy/lib/`

Both sources resolve the symbol under the cursor from Neo-tree's target window, group root items by LSP client, lazily load child nodes when you expand them, and reuse Neo-tree's normal jump / preview flow for the selected item.

## How it works

The shared runtime in `lua/neo-tree/sources/hierarchy/lib/source.lua` does the heavy lifting for both sources:

1. Collect LSP clients attached to Neo-tree's target buffer.
2. Keep only clients that support the requested hierarchy capability.
3. Apply `client_filters`.
4. Send the prepare request once per remaining client, using that client's position encoding.
5. Build one Neo-tree root per client.
6. Lazily request child nodes when a hierarchy item is expanded.
7. Let `gd` switch direction and rebuild the tree.
8. Jump / reveal the selected item with `vim.lsp.util.show_document(...)` after preloading the target buffer.

Root labels reflect the active direction, for example:

- `incoming calls (clangd) in foo.c`
- `outgoing calls (clangd) in foo.c`
- `supertypes (lua_ls) in bar.lua`
- `subtypes (lua_ls) in bar.lua`

## Setup

Put this plugin on your `runtimepath` alongside `neo-tree.nvim`, then register the two sources in Neo-tree.

```lua
require("neo-tree").setup({
  sources = {
    "filesystem",
    "buffers",
    "git_status",
    "call_hierarchy",
    "type_hierarchy",
  },
  source_selector = {
    winbar = true,
    sources = {
      { source = "filesystem" },
      { source = "buffers" },
      { source = "git_status" },
      { source = "call_hierarchy" },
      { source = "type_hierarchy" },
    },
  },
  call_hierarchy = {
    client_filters = "first",
    auto_expand_depth = 1,
  },
  type_hierarchy = {
    client_filters = "first",
    auto_expand_depth = 1,
  },
})
```

## Default behavior

Both hierarchy sources currently use these mappings by default:

- `<2-LeftMouse>`, `l`: expand / collapse the selected hierarchy node
- `h`: close the selected node
- `o`: jump to the selected hierarchy item
- `p`: show the selected hierarchy item
- `P`: toggle preview
- `gd`: toggle direction
  - `call_hierarchy`: incoming ↔ outgoing
  - `type_hierarchy`: supertypes ↔ subtypes
- `/`: open Neo-tree's live filter prompt
- `f`: filter on submit

A number of file-oriented Neo-tree mappings are intentionally disabled with `noop` because these sources expose LSP hierarchy items, not filesystem operations.

## Display behavior

### Call hierarchy

Call hierarchy nodes show the symbol name and try to render methods with their enclosing scope, for example `Foo::Bar::method`. The runtime first infers scope from Treesitter ancestors and falls back to LSP `detail` when available.

When applicable, an inline call count suffix is also shown:

- no suffix for a single call site
- `×2`, `×3`, ... for repeated call sites
- the suffix is rendered immediately to the right of the name

### Type hierarchy

Type hierarchy nodes show the resolved symbol kind and symbol name. Methods are rendered with their enclosing scope, for example `Foo::Bar::method`. The runtime first infers scope from Treesitter ancestors and falls back to LSP `detail` when available, without the extra call-count suffix used by `call_hierarchy`.

### Preview and jump

Preview and jump use the stored item range from the LSP hierarchy item. Before opening the target, the runtime preloads the target buffer so first-open navigation is reliable even when that buffer was not loaded yet.

## Configuration

### `auto_expand_depth`

Controls automatic expansion after the initial render.

```lua
call_hierarchy = {
  auto_expand_depth = 1,
}

type_hierarchy = {
  auto_expand_depth = 1,
}
```

Current behavior:

- `0`: do not auto-expand
- `1` or greater: auto-expand the first hierarchy level under each root

The current implementation only auto-expands one level.

### `client_filters`

Controls which LSP clients contribute hierarchy roots.

#### First matching client

```lua
call_hierarchy = {
  client_filters = "first",
}
```

This is the default.

#### All matching clients

```lua
type_hierarchy = {
  client_filters = "all",
}
```

#### Allow only selected client names

```lua
call_hierarchy = {
  client_filters = {
    type = "all",
    allow_only = { "vtsls", "lua_ls" },
  },
}
```

#### Ignore selected client names

```lua
type_hierarchy = {
  client_filters = {
    ignore = { "copilot", "null-ls" },
  },
}
```

#### Custom predicate

```lua
call_hierarchy = {
  client_filters = {
    type = "all",
    fn = function(client_name, client)
      return client_name ~= "copilot"
    end,
  },
}
```

### `custom_kinds`

Overrides the default mapping from numeric LSP symbol kind ids to kind names.

```lua
type_hierarchy = {
  custom_kinds = {
    [5] = "EntityClass",
  },
}
```

### `kinds`

Controls icon and highlight rendering for each kind name.

```lua
call_hierarchy = {
  kinds = {
    Method = { icon = "󰊕", hl = "Function" },
    Class = { icon = "󰌗", hl = "Type" },
    Unknown = { icon = "?", hl = "Comment" },
  },
}
```

### `renderers`

Like any Neo-tree source, both hierarchy sources can override renderers.

Available shared components are:

- `kind_icon`
- `name`
- `detail`
- `kind_name`

The current default directory renderer keeps `detail` inline next to `name`:

```lua
call_hierarchy = {
  renderers = {
    directory = {
      { "indent", with_expanders = true },
      { "kind_icon" },
      {
        "container",
        content = {
          { "name", zindex = 10 },
          { "detail", zindex = 10, prefix = " ", highlight = "Function" },
        },
      },
    },
  },
}
```

## Current limitations

- Roots are grouped by LSP client, so `client_filters = "all"` can show multiple root sections for the same symbol.
- Child hierarchy items are loaded on demand when you expand a node.
- `auto_expand_depth` currently expands only the first hierarchy level.
- If no attached client supports the requested hierarchy feature, the source renders an empty-state message instead of a tree.
- If the prepare request returns no hierarchy items, the source also renders an empty-state message.
