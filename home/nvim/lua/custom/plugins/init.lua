-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
local M = {
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    keys = {
      { '<leader>fe', '<cmd>Neotree toggle<cr>', desc = '[F]ile [E]xplorer' },
    },
    opts = {
      filesystem = {
        hijack_netrw_behavior = 'open_default',
      },
      window = {
        width = 32,
      },
    },
  },
  {
    'sindrets/diffview.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys = {
      { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = '[G]it [D]iff view' },
      { '<leader>gc', '<cmd>DiffviewClose<cr>', desc = '[G]it diff [C]lose' },
      { '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', desc = '[G]it file [H]istory' },
      { '<leader>gH', '<cmd>DiffviewFileHistory<cr>', desc = '[G]it branch [H]istory' },
    },
    config = function()
      require('diffview').setup {
        enhanced_diff_hl = false, -- Use simpler diff highlighting
        view = {
          merge_tool = {
            layout = 'diff3_mixed',
          },
        },
      }

      -- Set up autocmd to fix diff colors after colorscheme loads
      vim.api.nvim_create_autocmd('ColorScheme', {
        pattern = '*',
        callback = function()
          -- Nord-compatible diff colors (subtle backgrounds, normal text)
          vim.api.nvim_set_hl(0, 'DiffAdd', { bg = '#3B4252', fg = '#A3BE8C' })
          vim.api.nvim_set_hl(0, 'DiffDelete', { bg = '#3B4252', fg = '#BF616A' })
          vim.api.nvim_set_hl(0, 'DiffChange', { bg = '#3B4252', fg = 'NONE' })
          vim.api.nvim_set_hl(0, 'DiffText', { bg = '#434C5E', fg = '#EBCB8B', bold = true })
        end,
      })

      -- Apply immediately as well
      vim.api.nvim_set_hl(0, 'DiffAdd', { bg = '#3B4252', fg = '#A3BE8C' })
      vim.api.nvim_set_hl(0, 'DiffDelete', { bg = '#3B4252', fg = '#BF616A' })
      vim.api.nvim_set_hl(0, 'DiffChange', { bg = '#3B4252', fg = 'NONE' })
      vim.api.nvim_set_hl(0, 'DiffText', { bg = '#434C5E', fg = '#EBCB8B', bold = true })
    end,
  },
}

local ok, lint = pcall(require, 'custom.plugins.lint')
if ok and type(lint) == 'table' then
  vim.list_extend(M, lint)
end

return M
