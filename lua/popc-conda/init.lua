--- @class PopcConda Conda panel extension for popc
local M = {}
local api = vim.api
local umode = require('popc.usermode')
local conda = require('popc-conda.conda')

M.opts = {
    python_servers = {}, -- Python related servers to restart after switch conda environment
    keys = {
        -- Set false to disable key
        ['<Space>'] = 'activate', -- Activate the selected environment
        ['<CR>'] = 'activate_quit', -- Activate the selected environment, then quit panel
        ['D'] = 'deactivate', -- Deactivate the current environment
        ['R'] = 'refetch_envs', -- Refetch conda environments
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

--- Setup panel items from conda environments items
--- @param refetch boolean? Refetch conda environments forcely
--- @return boolean
local function setup_env_items(refetch)
    if refetch or #pctx.envs == 0 then
        local envs, err = conda.list_envs()
        if not envs then
            umode.notify(err)
            return false
        end
        pctx.envs = envs
    else
        local env_name = vim.env.CONDA_DEFAULT_ENV
        for _, env in ipairs(pctx.envs) do
            env.active = env.name == env_name and '*' or ''
        end
    end

    local items = {}
    for _, env in ipairs(pctx.envs) do
        table.insert(items, { env.name, env.active, env.path })
    end
    pctx.items = items
    return true
end

--- Restart configured Python LSP servers
local function restart_python_servers()
    local servers = M.opts.python_servers
    if type(servers) ~= 'table' or #servers == 0 then
        return
    end

    for _, server in ipairs(servers) do
        if type(server) == 'string' and #vim.lsp.get_clients({ name = server }) > 0 then
            vim.cmd.lsp({ args = { 'restart', server } })
        end
    end
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
    setup_env_items()
    uctx.state = umode.State.ReDisp
end

function pkeys.activate_quit(uctx)
    local env = pctx.envs[pctx.index]
    local ok, err = conda.activate(env.name)
    if not ok then
        umode.notify(err)
    else
        umode.notify(('Activated conda environment: %s'):format(env.name))
        restart_python_servers()
    end
    uctx.state = umode.State.None
end

function pkeys.deactivate(uctx)
    local ok, err = conda.deactivate()
    if not ok then
        umode.notify(err)
    else
        umode.notify('Deactivated conda environment')
        restart_python_servers()
        setup_env_items()
        uctx.state = umode.State.ReDisp
    end
end

function pkeys.refetch_envs(uctx)
    if setup_env_items(true) then
        umode.notify('Refetched conda environments')
        uctx.state = umode.State.ReDisp
    end
end

function M.pop()
    if setup_env_items() then
        umode.apop(pctx)
    end
end

return M
