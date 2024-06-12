return {
  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = function()
      local lint = require 'lint'
      lint.linters_by_ft = lint.linters_by_ft or {}
      lint.linters_by_ft.markdown = nil
      lint.linters_by_ft.rst = nil
      lint.linters_by_ft.text = nil

      if vim.fn.executable 'eslint_d' == 0 then
        vim.notify('[lint] eslint_d not found; disabling eslint diagnostics', vim.log.levels.WARN)
      else
        lint.linters_by_ft = vim.tbl_extend('force', lint.linters_by_ft, {
          javascript = { 'eslint_d' },
          javascriptreact = { 'eslint_d' },
          typescript = { 'eslint_d' },
          typescriptreact = { 'eslint_d' },
        })

        local eslint = lint.linters.eslint_d
        if eslint then
          eslint.args = {
            '--stdin',
            '--stdin-filename',
            function()
              return vim.api.nvim_buf_get_name(0)
            end,
            '--format',
            'json',
          }
          eslint.condition = function(ctx)
            local root = vim.fs.dirname(ctx.filename)
            if not root then
              return false
            end
            return vim.fs.find({
              '.eslintrc',
              '.eslintrc.cjs',
              '.eslintrc.js',
              '.eslintrc.json',
              '.eslintrc.yaml',
              '.eslintrc.yml',
              'eslint.config.js',
              'eslint.config.cjs',
              'eslint.config.mjs',
              'package.json',
            }, { upward = true, path = root, stop = vim.loop.os_homedir() })[1] ~= nil
          end
        end
      end

      return lint
    end,
    config = function(_, opts)
      -- apply opts to ensure linters use our settings
      opts.linters_by_ft = opts.linters_by_ft

      local lint = require 'lint'
      local augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = augroup,
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },
}
