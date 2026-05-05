-- ============================================================================
-- Key Mappings
-- ============================================================================

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Leader key is set in options.lua as <Space>

-- ============================================================================
-- General Mappings
-- ============================================================================

-- Better window navigation
keymap('n', '<C-h>', '<C-w>h', opts)
keymap('n', '<C-j>', '<C-w>j', opts)
keymap('n', '<C-k>', '<C-w>k', opts)
keymap('n', '<C-l>', '<C-w>l', opts)

-- Resize windows with arrows
keymap('n', '<C-Up>', ':resize -2<CR>', opts)
keymap('n', '<C-Down>', ':resize +2<CR>', opts)
keymap('n', '<C-Left>', ':vertical resize -2<CR>', opts)
keymap('n', '<C-Right>', ':vertical resize +2<CR>', opts)

-- Navigate buffers
keymap('n', '<S-l>', ':bnext<CR>', opts)
keymap('n', '<S-h>', ':bprevious<CR>', opts)
keymap('n', '<leader>bd', ':bdelete<CR>', opts)

-- Clear highlights
keymap('n', '<leader>h', ':nohlsearch<CR>', opts)

-- Better paste
keymap('v', 'p', '"_dP', opts)

-- Stay in indent mode
keymap('v', '<', '<gv', opts)
keymap('v', '>', '>gv', opts)

-- Move text up and down
keymap('v', '<A-j>', ':m .+1<CR>==', opts)
keymap('v', '<A-k>', ':m .-2<CR>==', opts)
keymap('x', '<A-j>', ":move '>+1<CR>gv-gv", opts)
keymap('x', '<A-k>', ":move '<-2<CR>gv-gv", opts)

-- Save and quit
keymap('n', '<leader>w', ':w<CR>', opts)
keymap('n', '<leader>q', ':q<CR>', opts)
keymap('n', '<leader>Q', ':qa!<CR>', opts)

-- Split windows
keymap('n', '<leader>sv', '<C-w>v', opts)
keymap('n', '<leader>sh', '<C-w>s', opts)
keymap('n', '<leader>se', '<C-w>=', opts)
keymap('n', '<leader>sx', ':close<CR>', opts)

-- Tabs
keymap('n', '<leader>to', ':tabnew<CR>', opts)
keymap('n', '<leader>tx', ':tabclose<CR>', opts)
keymap('n', '<leader>tn', ':tabn<CR>', opts)
keymap('n', '<leader>tp', ':tabp<CR>', opts)

-- Terminal
keymap('n', '<leader>tt', ':terminal<CR>', opts)
keymap('t', '<Esc>', '<C-\\><C-n>', opts)

-- ============================================================================
-- Plugin-specific Keymaps (will be loaded by plugins)
-- ============================================================================

-- File explorer (nvim-tree)
keymap('n', '<leader>e', ':NvimTreeToggle<CR>', opts)

-- Telescope
keymap('n', '<leader>ff', ':Telescope find_files<CR>', opts)
keymap('n', '<leader>fg', ':Telescope live_grep<CR>', opts)
keymap('n', '<leader>fb', ':Telescope buffers<CR>', opts)
keymap('n', '<leader>fh', ':Telescope help_tags<CR>', opts)
keymap('n', '<leader>fr', ':Telescope oldfiles<CR>', opts)

-- Git
keymap('n', '<leader>gg', ':LazyGit<CR>', opts)
keymap('n', '<leader>gb', ':Gitsigns toggle_current_line_blame<CR>', opts)

-- LSP (will be set up in lsp.lua when attached)
-- See lua/plugins/lsp.lua for LSP-specific keymaps

-- Format
keymap('n', '<leader>fm', ':lua vim.lsp.buf.format({ async = true })<CR>', opts)
