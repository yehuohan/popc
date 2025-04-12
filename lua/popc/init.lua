--- @class Popc Pop Out Panel of Custom user mode
local M = {}

function M.setup(opts)
    opts = require('popc.config').setup(opts)

    local tabuf = require('popc.panel.tabuf')
    tabuf.setup()

    vim.api.nvim_create_user_command('PopcInspect', function(args)
        local module = 'popc.panel.tabuf'
        local arg = args.fargs[1]
        if arg then
            module = arg == 'usermode' and 'popc.usermode' or 'popc.panel.' .. arg
        end
        vim.print(require(module).inspect())
    end, {
        nargs = '?',
        complete = function()
            return { 'usermode', 'tabuf', 'session', 'bookmark' }
        end,
    })
    if opts.debug then
        vim.api.nvim_create_user_command('PopcLog', function(args)
            require('popc.log').print(args.fargs[1])
        end, { nargs = '?', complete = require('popc.log').get_tags })
    end
end

return M
