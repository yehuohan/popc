--- @class Popc Pop Out Panel of Custom user mode
local M = {}

function M.setup(opts)
    opts = require('popc.config').setup(opts)

    if opts.tabuf.enable then
        require('popc.panel.tabuf').setup()
    end

    -- Only for development
    vim.keymap.set('n', '<leader><leader>H', '<Cmd>PopcTabuf<CR>')

    if opts.debug then
        vim.api.nvim_create_user_command('PopcInspect', function(args)
            local module = 'popc.panel.tabuf'
            local arg = args.fargs[1]
            if arg then
                module = arg == 'usermode' and 'popc.usermode' or 'popc.panel.' .. arg
            end
            local res, _ = require(module).inspect()
            vim[args.bang and 'notify' or 'print'](res)
        end, {
            bang = true,
            nargs = '?',
            complete = function()
                return { 'usermode', 'tabuf', 'bookmark', 'workspace' }
            end,
        })
        vim.api.nvim_create_user_command('PopcLog', function(args)
            local res = require('popc.log').get_logs(args.fargs[1])
            vim[args.bang and 'notify' or 'print'](res)
        end, { bang = true, nargs = '?', complete = require('popc.log').get_tags })
    end
end

return M
