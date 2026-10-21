--- @class PopcConda Conda panel extension for popc
local M = {}
local api = vim.api
local umode = require('popc.usermode')
local conda = require('popc-conda.conda')

M.opts = {
    keys = {
        -- Set false to disable key
        ['<Space>'] = 'activate', -- Activate the selected environment
        ['<CR>'] = 'activate_quit', -- Activate the selected environment, then quit panel
        ['D'] = 'deactivate_quit', -- Deactivate the current environment, then quit panel
    },
}

--- Conda panel context
--- @type PanelContext
local pctx = {
    name = 'Conda',
    text = 'Conda',
    items = {},
    index = 1,
    keys = {},
    pkeys = {},
    -- Specified panel data
    --- @type CondaEnvItem[]
    envs = {},
}

--- Setup panel items from conda environment names
--- @param envs CondaEnvItem[]?
local function setup_env_items(envs)
    pctx.envs = envs or {}
    local items = {}
    for _, env in ipairs(pctx.envs) do
        table.insert(items, { env.name, env.active, env.path })
    end
    pctx.items = items
end

--- Setup the conda extension
--- @param opts table?
function M.setup(opts)
    if opts then
        M.opts = vim.tbl_deep_extend('force', M.opts, opts)
    end
    pctx.keys = M.opts.keys

    api.nvim_create_user_command('PopcConda', M.pop, { nargs = 0 })
    require('popc.inspect').register('conda', 'popc-conda')
end

function M.inspect()
    return vim.inspect(pctx), pctx
end

--- Panel keys handler
local pkeys = pctx.pkeys

function pkeys.activate(uctx)
    pkeys.activate_quit(uctx)
    setup_env_items(conda.list_envs())
    uctx.state = umode.State.ReDisp
end

function pkeys.activate_quit(uctx)
    local env = pctx.envs[pctx.index]
    local ok, err = conda.activate(env.name)
    umode.notify(ok and ('Activated conda environment: %s'):format(env.name) or err)
    uctx.state = umode.State.None
end

function pkeys.deactivate_quit(uctx)
    local ok, err = conda.deactivate()
    umode.notify(ok and 'Deactivated conda environment' or err)
    uctx.state = umode.State.None
end

function M.pop()
    local envs, err = conda.list_envs()
    if not envs then
        umode.notify(err)
    else
        setup_env_items(envs)
        umode.apop(pctx)
    end
end

return M
