# neo-tree-hierarchy.nvim

Extra Neo-tree sources for browsing LSP call hierarchies and type hierarchies.

## What this provides

- `call_hierarchy`: shows `textDocument/prepareCallHierarchy` results and lazily expands `callHierarchy/incomingCalls` or `callHierarchy/outgoingCalls`
- `type_hierarchy`: shows `textDocument/prepareTypeHierarchy` results and lazily expands `typeHierarchy/supertypes` or `typeHierarchy/subtypes`
- Shared hierarchy runtime under `lua/neo-tree/sources/hierarchy/lib/`

The sources resolve the symbol under the cursor from Neo-tree's target window, group root items by LSP client, and open or preview the selected item with Neo-tree's standard commands.

## Source layout

```text
lua/neo-tree/sources/
├── call_hierarchy/
│   ├── init.lua         -- source entrypoint
│   ├── commands.lua     -- source command table
│   ├── components.lua   -- source renderer components
│   └── defaults.lua     -- source defaults and mappings
├── type_hierarchy/
│   ├── init.lua
│   ├── commands.lua
│   ├── components.lua
│   └── defaults.lua
└── hierarchy/lib/
    ├── source.lua       -- shared LSP request + tree-building logic
    ├── commands.lua     -- shared command factory
    ├── components.lua   -- shared renderer components
    ├── defaults.lua     -- shared renderer + window defaults
    ├── client_filters.lua
    └── kinds.lua
```

## How the shared source works

`lua/neo-tree/sources/hierarchy/lib/source.lua` is the runtime used by both sources.

1. Collect LSP clients attached to the current buffer.
2. Keep only clients that support the requested hierarchy capability.
3. Apply `client_filters`.
4. Send the prepare request once per client, using that client's position encoding.
5. Build one Neo-tree root node per matching client.
6. Lazily request child nodes when a hierarchy item is expanded.
7. Reuse Neo-tree preview and jump behavior for the selected item.
8. Allow switching hierarchy direction from the source window.

Implementation details:

- Call hierarchy nodes append a detail suffix like `2 call sites`.
- Preview support is driven by `node.extra.position` and `node.extra.end_position`.
- Child hierarchy items are loaded on demand by expanding `directory` nodes.

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

Both sources currently share the same default mappings:

- `<cr>`, `<2-LeftMouse>`, `l`: expand/collapse the selected hierarchy node
- `h`: close the selected node
- `o`: jump to the selected hierarchy item
- `P`: toggle preview
- `gd`: toggle direction (incoming ↔ outgoing, supertypes ↔ subtypes)
- `/`: open Neo-tree's live filter prompt
- `f`: filter on submit

The root node label reflects the active direction, e.g. `incoming calls (clangd) in foo.lua` or `subtypes (lua_ls) in bar.lua`.

A number of file-oriented mappings are intentionally disabled with `noop` because these sources expose LSP hierarchy items, not filesystem operations.

## Configuration

### `auto_expand_depth`

Controls how many hierarchy levels are expanded automatically after the initial render.

```lua
call_hierarchy = {
  auto_expand_depth = 1,
}

type_hierarchy = {
  auto_expand_depth = 1,
}
```

Current supported values:

- `0`: do not auto-expand
- `1`: auto-expand the first hierarchy level

The default is `1` for both sources. Direction switching with `gd` respects the same setting.

### `client_filters`

Controls which LSP clients contribute hierarchy roots.

#### Use the first matching client

```lua
call_hierarchy = {
  client_filters = "first",
}
```

This is the default.

#### Use every matching client

```lua
type_hierarchy = {
  client_filters = "all",
}
```

#### Restrict by client name

```lua
call_hierarchy = {
  client_filters = {
    type = "all",
    allow_only = { "vtsls", "lua_ls" },
  },
}
```

#### Ignore selected clients

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

Overrides the mapping from numeric LSP symbol kind ids to display names.

```lua
type_hierarchy = {
  custom_kinds = {
    [5] = "EntityClass",
  },
}
```

### `kinds`

Controls icon and highlight rendering per kind name.

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

Example:

```lua
call_hierarchy = {
  renderers = {
    directory = {
      { "indent", with_expanders = true },
      { "kind_icon" },
      { "name", zindex = 10 },
      { "detail", zindex = 20 },
    },
  },
}
```

## Current limitations

- `call_hierarchy` and `type_hierarchy` support switching directions, but each source currently auto-expands at most one level (`auto_expand_depth = 0` or `1`).
- The source roots are grouped by LSP client, so using `client_filters = "all"` can show multiple root sections for the same symbol.
- If no attached client supports the relevant hierarchy capability, the source renders an empty-state message instead of a tree.

## Smoke test status

The current implementation has been checked with a headless Neo-tree setup and loads both sources successfully.
