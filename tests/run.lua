-- 用真实 Neo-tree 渲染与固定 LSP 响应验证行为，不依赖语言服务器的索引时序。
local plugin = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local deps = vim.env.NEOTREE_TEST_DEPS or vim.fn.fnamemodify(plugin, ":h")
vim.opt.rtp:prepend(plugin)
for _, name in ipairs({ "neo-tree.nvim", "nui.nvim", "plenary.nvim", "nvim-treesitter" }) do
	vim.opt.rtp:append(deps .. "/" .. name)
end
vim.o.swapfile = false
local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
local original_clients, original_client = vim.lsp.get_clients, vim.lsp.get_client_by_id
local function run()
	local override = vim.env.HIERARCHY_TEST_SOURCE
	if override then
		package.loaded["neo-tree.sources.hierarchy.lib.source"] = assert(loadfile(override))()
	end
	local function item(name, file, kind, row, detail)
		local position = { line = row or 0, character = 6 }
		return {
			name = name,
			uri = vim.uri_from_fname(file),
			kind = kind or 5,
			detail = detail,
			range = { start = position, ["end"] = { line = position.line, character = 7 } },
			selectionRange = { start = position, ["end"] = { line = position.line, character = 7 } },
		}
	end
	local main, hidden = directory .. "/main.py", directory .. "/hidden.py"
	vim.fn.writefile({ "class Leaf: pass" }, main)
	vim.fn.writefile(
		{ "class Parent: pass", "class Grandparent: pass", "class Owner:", "    def method(self): pass" },
		hidden
	)
	vim.cmd.edit(main)
	local root = item("Leaf", main)
	local parent, grandparent = item("Parent", hidden), item("Grandparent", hidden, 5, 1)
	local method = item("method", hidden, 6, 3, "Owner.method")
	local responses = { Leaf = { parent, method }, Parent = { grandparent }, Grandparent = {} }
	local requests = {}
	local client = {
		id = 919,
		name = "fixture",
		offset_encoding = "utf-16",
		server_capabilities = { typeHierarchyProvider = true },
	}
	function client:request(method_name, params, callback)
		requests[method_name] = (requests[method_name] or 0) + 1
		callback(
			nil,
			method_name == "textDocument/prepareTypeHierarchy" and { root } or responses[params.item.name] or {}
		)
		return true, 1
	end
	vim.lsp.get_clients = function()
		return { client }
	end
	vim.lsp.get_client_by_id = function(id)
		if id == client.id then
			return client
		end
	end
	require("neo-tree").setup({
		sources = { "type_hierarchy" },
		default_source = "type_hierarchy",
		enable_git_status = false,
		enable_diagnostics = false,
		type_hierarchy = { auto_expand_depth = 1 },
	})
	local hidden_events = 0
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter", "BufWinEnter" }, {
		callback = function(event)
			if event.file == hidden then
				hidden_events = hidden_events + 1
			end
		end,
	})
	require("neo-tree.command").execute({ source = "type_hierarchy", action = "focus" })
	local manager = require("neo-tree.sources.manager")
	local source = require("neo-tree.sources.hierarchy.lib.source")
	local state = manager.get_state("type_hierarchy")
	local function node(name)
		if not state.tree then
			return
		end
		for _, candidate in pairs(state.tree.nodes.by_id) do
			if candidate.extra and candidate.extra.item and candidate.extra.item.name == name then
				return candidate
			end
		end
	end
	assert(
		vim.wait(3000, function()
			return node("Parent") ~= nil
		end),
		"parent was not rendered"
	)
	local hidden_buf = vim.uri_to_bufnr(parent.uri)
	assert(not vim.api.nvim_buf_is_loaded(hidden_buf), "rendering a class/method loaded its hidden file")
	assert(hidden_events == 0, "label rendering fired hidden-buffer events")
	assert(node("method").name == "Owner.method", "unloaded method lost its LSP scope fallback")
	local first = node("Parent")
	source.toggle_directory(state, first)
	assert(
		vim.wait(3000, function()
			return node("Grandparent") ~= nil
		end),
		"grandparent was not rendered"
	)
	assert(node("Leaf"):is_expanded() and first:is_expanded(), "child loading collapsed ancestors")
	local calls = requests["typeHierarchy/supertypes"]
	source.toggle_directory(state, first)
	assert(not first:is_expanded(), "loaded node did not collapse")
	source.toggle_directory(state, first)
	assert(first:is_expanded() and node("Grandparent"), "reopening lost loaded children")
	assert(requests["typeHierarchy/supertypes"] == calls, "reopening re-requested loaded children")
	assert(hidden_events == 0, "expansion fired hidden-buffer events")
	print("PASS: cross-file class and method labels do not load files or fire buffer events")
	print("PASS: LSP scope fallback, ancestor expansion, collapse/reopen and lazy child reuse")
	-- 真实空响应分别渲染两个方向，检查最终文本范围的高亮，而非只测组件返回值。
	local function check_empty(label)
		state.hierarchy.empty_children_label = label
		local grand = node("Grandparent")
		grand.loaded = false
		source.toggle_directory(state, grand)
		assert(vim.wait(3000, function()
			return grand.loaded
		end))
		local row
		for i, line in ipairs(vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)) do
			if line:find(label, 1, true) then
				row = i - 1
			end
		end
		assert(row, label .. " was not rendered")
		local highlighted = false
		for _, mark in
			ipairs(vim.api.nvim_buf_get_extmarks(state.bufnr, -1, { row, 0 }, { row, -1 }, { details = true }))
		do
			if mark[4].hl_group == "NeoTreeHierarchyMessage" then
				highlighted = true
			end
		end
		assert(highlighted, label .. " did not use message styling")
	end
	check_empty("No supertypes")
	check_empty("No subtypes")
	local message_style = vim.api.nvim_get_hl(0, { name = "NeoTreeHierarchyMessage", link = false })
	assert(message_style.fg == 0x777777 and not message_style.bold)
	vim.api.nvim_exec_autocmds("ColorScheme", {})
	message_style = vim.api.nvim_get_hl(0, { name = "NeoTreeHierarchyMessage", link = false })
	assert(message_style.fg == 0x777777 and not message_style.bold)
	print("PASS: No supertypes / No subtypes render dark gray without bold, including after theme changes")

	-- 已加载源码仍可提供比 LSP detail 更精确的嵌套作用域。
	vim.fn.bufload(hidden_buf)
	vim.bo[hidden_buf].filetype = "python"
	local parser = vim.treesitter.get_parser(hidden_buf, "python")
	parser:parse()
	responses.Leaf = { method }
	method.detail = "IncorrectFallback"
	source.navigate(state)
	assert(
		vim.wait(3000, function()
			return node("method") and node("method").name == "Owner::method"
		end),
		"loaded method did not use Tree-sitter scope"
	)
	print("PASS: loaded Python method retains Tree-sitter scope inference")
end
local ok, error_message = xpcall(run, debug.traceback)
vim.lsp.get_clients, vim.lsp.get_client_by_id = original_clients, original_client
vim.fn.delete(directory, "rf")
if not ok then
	io.stderr:write(error_message .. "\n")
	vim.cmd("cquit 1")
else
	vim.cmd("qa!")
end
