local M = {}

local _border = "rounded"

function M.get_handlers()
	local handlers = {
		["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
			border = _border,
		}),

		["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = _border }),
	}

	return handlers
end

M.setup_ui = function()
	---@type table|nil
	local diagnostic_cfg = {
		enable = true,
		underline = true,
		float = {
			-- focusable = false,
			-- style = "minimal",
			border = _border,
			source = "always",
		},
	}

	local utils = require("user.utils")

	local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
	utils.if_nightly_else(function()
		-- API changed in neovim 0.10, currently nightly
		diagnostic_cfg = vim.tbl_deep_extend("force", diagnostic_cfg, {
			signs = {
				text = {
					[vim.diagnostic.severity.ERROR] = signs.Error,
					[vim.diagnostic.severity.WARN] = signs.Warn,
					[vim.diagnostic.severity.HINT] = signs.Hint,
					[vim.diagnostic.severity.INFO] = signs.Info,
				},
				texthl = {
					[vim.diagnostic.severity.ERROR] = "DiagnosticDefault",
					[vim.diagnostic.severity.WARN] = "DiagnosticDefault",
					[vim.diagnostic.severity.HINT] = "DiagnosticDefault",
					[vim.diagnostic.severity.INFO] = "DiagnosticDefault",
				},
				numhl = {
					[vim.diagnostic.severity.ERROR] = "DiagnosticDefault",
					[vim.diagnostic.severity.WARN] = "DiagnosticDefault",
					[vim.diagnostic.severity.HINT] = "DiagnosticDefault",
					[vim.diagnostic.severity.INFO] = "DiagnosticDefault",
				},
				severity_sort = true,
			},
		})
	end, function()
		-- define signs and their highlights
		for type, icon in pairs(signs) do
			local name = "DiagnosticSign" .. type
			local hl = name
			vim.fn.sign_define(name, { text = icon, texthl = hl })
		end
	end)

	vim.diagnostic.config(diagnostic_cfg)

	-- use pretty gutter signs, fallback for plugins that don't support nightly
	-- style yet
	utils.if_nightly(function()
		for type, icon in pairs(signs) do
			local name = "DiagnosticSign" .. type
			local hl = "DiagnosticSignCustom" .. type
			vim.fn.sign_define(name, { text = icon, texthl = hl })
		end
	end)

	vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "DiagnosticSignError" })
	vim.fn.sign_define("DapStopped", { text = "->", texthl = "DiagnosticSignInfo" })
end

M.get_on_attach = function(telescope_builtin)
	return function(client, bufnr)
		local inlay_hint_supported = vim.lsp.inlay_hint ~= nil and client.supports_method("textDocument/inlayHint")

		if inlay_hint_supported then
			-- TODO: inlay hints will be available in nightly. Right now, using
			-- nightly build will also work, but there are some issues with other
			-- plugins.
			vim.api.nvim_create_user_command("LspToggleInlayHints", function()
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), {}) -- latest nightly
			end, {})

			vim.lsp.inlay_hint.enable(false, {}) -- disable inlay hints by default
		end

		-- Diagnostic keymaps
		require("user.keymaps").lsp(telescope_builtin, inlay_hint_supported)

		vim.api.nvim_set_option_value("omnifunc", "v:lua.vim.lsp.omnifunc", { buf = bufnr })
	end
end

M.get_global_capabilities = function(cmp_nvim_lsp)
	local lsp_capabilities = vim.lsp.protocol.make_client_capabilities()
	local cmp_capabilities = cmp_nvim_lsp.default_capabilities()

	local capabilities = vim.tbl_deep_extend("force", lsp_capabilities, cmp_capabilities)

	---@diagnostic disable-next-line: need-check-nil, undefined-field
	capabilities.textDocument.completion.completionItem.snippetSupport = true
	return capabilities
end

-- LSPs

M.clangd = function(opts, lspconfig)
	return function()
		lspconfig.clangd.setup({
			on_attach = opts.on_attach,
			capabilities = opts.capabilities,
			handlers = opts.handlers,
		})
	end
end

M.rust_analyzer = function(opts)
	return function()
		---@diagnostic disable-next-line: inject-field
		vim.g.rustaceanvim = {
			-- Plugin configuration
			tools = {},
			-- LSP configuration
			server = {
				on_attach = opts.on_attach,
				capabilites = opts.capabilites,
				handlers = opts.handlers,
				settings = {
					-- rust-analyzer language server configuration
					["rust-analyzer"] = {
						hover = {
							links = {
								enable = false,
							},
						},

						lens = { enable = true },
						inlayHints = { enable = true },
						completion = { autoimport = { enable = true } },
						rustc = { source = "discover" },
						updates = { channel = "nightly" },

						cargo = { allFeatures = true },
						checkOnSave = true,
						check = {
							enable = true,
							command = "clippy",
							features = "all",
						},
						procMacro = {
							enable = true,
						},
					},
				},
			},
			-- DAP configuration
			dap = {},
		}
	end
end

M.zig_lsp = function(opts, lspconfig)
	return function()
		lspconfig.zls.setup({
			settings = {
				enable_build_on_save = true,
				enable_autofix = true,
			},
			on_attach = opts.on_attach,
			capabilites = opts.capabilities,
			handlers = opts.handlers,
		})
	end
end

M.go_lsp = function(opts, lspconfig)
	return function()
		lspconfig["gopls"].setup({
			settings = {
				gopls = {
					gofumpt = true,
					buildFlags = {
						"-tags=integration,unit",
					},
					hints = {
						assignVariableTypes = true,
						compositeLiteralFields = true,
						compositeLiteralTypes = true,
						constantValues = true,
						functionTypeParameters = true,
						parameterNames = true,
						rangeVariableTypes = true,
					},
				},
			},
			on_attach = opts.on_attach,
			capabilites = opts.capabilities,
			handlers = opts.handlers,
		})
	end
end

M.tsserver = function(opts, lspconfig)
	return function()
		lspconfig["tsserver"].setup({
			settings = {
				typescript = {
					inlayHints = {
						includeInlayParameterNameHints = "all",
						includeInlayParameterNameHintsWhenArgumentMatchesName = false,
						includeInlayFunctionParameterTypeHints = true,
						includeInlayVariableTypeHints = true,
						includeInlayVariableTypeHintsWhenTypeMatchesName = false,
						includeInlayPropertyDeclarationTypeHints = true,
						includeInlayFunctionLikeReturnTypeHints = true,
						includeInlayEnumMemberValueHints = true,
					},
				},
			},
			on_attach = function(client, bufnr)
				client.server_capabilities.documentFormattingProvider = false

				local ts_utils = require("nvim-lsp-ts-utils")
				ts_utils.setup({})
				ts_utils.setup_client(client)

				opts.on_attach(client, bufnr)
			end,
			capabilites = opts.capabilites,
			handlers = opts.handlers,
		})
	end
end

M.jsonls = function(opts, lspconfig)
	return function()
		lspconfig["jsonls"].setup({
			on_attach = function(client, bufnr)
				client.server_capabilities.document_formatting = false
				client.server_capabilities.document_range_formatting = false

				opts.on_attach(client, bufnr)
			end,
			capabilites = opts.capabilites,
			handlers = opts.handlers,
		})
	end
end

M.eslint = function(opts, lspconfig)
	return function()
		lspconfig["eslint"].setup({
			on_attach = opts.on_attach,
			capabilities = opts.capabilities,
			handlers = opts.handlers,
		})
	end
end

M.lua_ls = function(opts, lspconfig)
	return function()
		lspconfig.lua_ls.setup({
			on_attach = opts.on_attach,
			capabilities = opts.capabilities,
			handlers = opts.handlers,
			settings = {
				Lua = {
					hint = {
						enable = true,
					},
					diagnostics = {
						globals = { "vim" },
					},
					workspace = {
						library = vim.api.nvim_get_runtime_file("", true),
					},
				},
			},
		})
	end
end

M.vue_ls = function(opts, lspconfig)
	return function()
		lspconfig["vuels"].setup({
			on_attach = opts.on_attach,
			capabilities = opts.capabilities,
			handlers = opts.handlers,
			settings = {
				vetur = {
					completion = {
						autoImport = true,
						tagCasing = "kebab",
						useScaffoldSnippets = true,
					},
					useWorkspaceDependencies = true,
					experimental = {
						templateInterpolationService = true,
					},
				},
				format = {
					enable = false,
					options = {
						useTabs = false,
						tabSize = 2,
					},
					scriptInitialIndent = false,
					styleInitialIndent = false,
					defaultFormatter = {},
				},
				validation = {
					template = false,
					script = false,
					style = false,
					templateProps = false,
					interpolation = false,
				},
			},
		})
	end
end

return M
