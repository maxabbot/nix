-- ============================================================================
-- General Options
-- ============================================================================

local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true
opt.numberwidth = 4
opt.signcolumn = 'yes'

-- Tabs & indentation
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true

-- Line wrapping
opt.wrap = false
opt.linebreak = true

-- Search settings
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Appearance
opt.termguicolors = true
opt.background = 'dark'
opt.cursorline = true
opt.showmode = false

-- Behavior
opt.mouse = 'a'
opt.clipboard = 'unnamedplus'
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.undofile = true
opt.undodir = vim.fn.stdpath('data') .. '/undo'

-- Split windows
opt.splitright = true
opt.splitbelow = true

-- Scrolling
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Performance
opt.updatetime = 250
opt.timeoutlen = 300

-- Completion
opt.completeopt = 'menu,menuone,noselect'
opt.pumheight = 10

-- Misc
opt.hidden = true
opt.iskeyword:append('-')
opt.shortmess:append('c')
opt.whichwrap:append('<,>,[,],h,l')
opt.fillchars = { eob = ' ' }

-- Set leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
