local M = {}

function M.check()
    local health = vim.health or require('health')
    local copts = require('popc.config').opts

    health.start('Require vim.o.hidden = true')
    if vim.o.hidden then
        health.ok('')
    else
        health.error('')
    end

    health.start('Require "folke/snacks.nvim" when opts.usermode.input = "snacks"')
    if copts.usermode.input == 'snacks' and not require('snacks').input then
        health.error('')
    else
        health.ok('')
    end
end

return M
