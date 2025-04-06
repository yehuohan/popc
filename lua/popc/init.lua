--- @class Popc Pop Out Panel of Custom user mode
local M = {}

function M.setup(opts)
    opts = opts or {}

    local tabuf = require('popc.panel.tabuf')
    tabuf.setup()

    vim.api.nvim_create_user_command('PopcTabuf', tabuf.ui_pop, { nargs = 0 })

    vim.api.nvim_create_user_command('PopcInspect', function(args)
        require('popc.panel.' .. (args.fargs[1] or 'tabuf')).print()
    end, {
        nargs = '?',
        complete = function()
            return {
                'tabuf',
                -- 'session',
                -- 'bookmark',
            }
        end,
    })
    if not opts.debug then
        vim.api.nvim_create_user_command('PopcLog', function(args)
            require('popc.log').print(args.fargs[1])
        end, { nargs = '?', complete = require('popc.log').get_tags })
    end
end

return M
