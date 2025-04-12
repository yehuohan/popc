--- @class Popc Pop Out Panel of Custom user mode
local M = {}

function M.setup(opts)
    opts = require('popc.config').setup(opts)

    local tabuf = require('popc.panel.tabuf')
    tabuf.setup()
    vim.api.nvim_create_user_command('PopcTabuf', tabuf.pop, { nargs = 0 })
    -- Only for development
    vim.keymap.set('n', '<leader><leader>H', '<Cmd>PopcTabuf<CR>')

    vim.api.nvim_create_user_command('PopcInspect', function(args)
        local module = 'popc.panel.tabuf'
        local arg = args.fargs[1]
        if arg then
            module = arg == 'usermode' and 'popc.usermode' or 'popc.panel.' .. arg
        end
        if args.bang then
            vim.notify(require(module).inspect())
        else
            vim.print(require(module).inspect())
        end
    end, {
        bang = true,
        nargs = '?',
        complete = function()
            return { 'usermode', 'tabuf', 'bookmark', 'workspace' }
        end,
    })
    if opts.debug then
        vim.api.nvim_create_user_command('PopcLog', function(args)
            if args.bang then
                vim.notify(require('popc.log').get_logs(args.fargs[1]))
            else
                vim.print(require('popc.log').get_logs(args.fargs[1]))
            end
        end, { bang = true, nargs = '?', complete = require('popc.log').get_tags })
    end
end

return M
