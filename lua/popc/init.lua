--- @class Popc Pop Out Panel of Custom user mode
local M = {}

function M.setup(opts)
    opts = require('popc.config').setup(opts)

    if opts.tabuf.enable then
        require('popc.panel.tabuf').setup()
    end
    if opts.workspace.enable then
        require('popc.panel.workspace').setup()
    end
    if opts.bookmark.enable then
        require('popc.panel.bookmark').setup()
    end
    if opts.selection.enable then
        require('popc.panel.selection').setup()
        M.pop_selection = require('popc.panel.selection').pop_selection
    end

    local inspect = require('popc.inspect')
    vim.api.nvim_create_user_command('PopcInspect', function(args)
        local module, err = inspect.resolve(args.fargs[1])
        if not module then
            vim.notify(err, vim.log.levels.ERROR)
        else
            vim[args.bang and 'notify' or 'print'](module.inspect())
        end
    end, {
        bang = true,
        nargs = '?',
        complete = function(arglead)
            return vim.tbl_filter(function(name)
                return name:match('^' .. arglead)
            end, inspect.get_tags())
        end,
    })

    if opts.debug then
        vim.api.nvim_create_user_command('PopcLog', function(args)
            local res = require('popc.log').get_logs(args.fargs[1])
            vim[args.bang and 'notify' or 'print'](res)
        end, {
            bang = true,
            nargs = '?',
            complete = function(arglead)
                return vim.tbl_filter(function(name)
                    return name:match('^' .. arglead)
                end, require('popc.log').get_tags())
            end,
        })
    end
end

return M
