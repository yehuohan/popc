--- @class PopcConda.Conda Conda environment manager
local M = {}
local fn = vim.fn
local log = require('popc.log').get('conda')

--- @class CondaEnvItem
--- @field name string
--- @field path string
--- @field active string

--- Run a command with list arguments
--- @param args string[] String list contains cmd + args
--- @return string[]? lines String list of command stdout
--- @return string? err
local function run_cmd(args)
    local ok, lines = pcall(fn.systemlist, args)
    if not ok then
        return nil, tostring(lines)
    end
    for k, line in ipairs(lines) do
        lines[k] = line:gsub('\r$', '')
    end
    if vim.v.shell_error ~= 0 then
        return nil, table.concat(lines, '\n')
    end
    return lines
end

--- Unquote a POSIX shell value
--- @param value string
--- @return string
local function unquote_posix(value)
    if #value >= 2 then
        local first, last = value:sub(1, 1), value:sub(-1)
        if first == "'" and last == "'" then
            return (value:sub(2, -2):gsub("'\\''", "'"))
        elseif first == '"' and last == '"' then
            return (value:sub(2, -2):gsub('\\(.)', '%1'))
        end
    end
    return value
end

--- Run conda activate/deactivate
--- @param env_name string? Environment to activate, or nil to deactivate
--- @return boolean ok
--- @return string? err
local function conda_activate(env_name)
    local sub = env_name and 'activate' or 'deactivate'
    local shell = fn.has('win32') == 1 and 'powershell' or fn.fnamemodify(vim.o.shell, ':t'):lower()
    local lines, err = run_cmd({ 'conda', 'shell.' .. shell, sub, env_name })
    if not lines then
        return false, err
    end

    -- Apply conda shell assignments to the Neovim environment
    log('Conda %s shell: %s', sub, shell)
    log('Conda %s environments:\n%s', sub, table.concat(lines, '\n'))
    if shell == 'powershell' then
        -- Powershell
        for _, line in ipairs(lines) do
            local name, value = line:match('^%s*%$Env:([%w_]+)%s*=%s*"(.*)"%s*$')
            if name then
                vim.env[name] = value:gsub('`(.)', '%1')
            end
        end
    else
        -- POSIX
        for _, line in ipairs(lines) do
            if sub == 'activate' then
                local name, value = line:match('^export%s+([%w_]+)=(.*)$')
                if name then
                    vim.env[name] = unquote_posix(value)
                end
            elseif sub == 'deactivate' then
                local name = line:match('^unset%s+([%w_]+)')
                if name then
                    vim.env[name] = nil
                end
            end
        end
    end

    return true
end

--- Check whether the conda command is available
--- @return boolean
function M.is_available()
    return fn.executable('conda') == 1
end

--- List conda environment names, with `base` first
--- @return CondaEnvItem[]? envs
--- @return string? err
function M.list_envs()
    if not M.is_available() then
        return nil, 'The conda command is not available'
    end

    local lines, err = run_cmd({ 'conda', 'env', 'list' })
    if not lines then
        return nil, err
    end

    --- @type CondaEnvItem[]
    local envs = { { name = 'base', path = '', active = '' } }
    for _, line in ipairs(lines) do
        local name, active, path = line:match('^%s*([^#%s%*][^%s%*]*)%s*(%*?)%s+(.+%S)%s*$')
        if name and path then
            if name == 'base' then
                envs[1].name = name
                envs[1].path = path
                envs[1].active = active
            else
                envs[#envs + 1] = { name = name, path = path, active = active }
            end
        end
    end
    return envs
end

--- Activate a conda environment
--- @param env_name string
--- @return boolean ok
--- @return string? err
function M.activate(env_name)
    vim.validate('env_name', env_name, 'string')
    return conda_activate(env_name)
end

--- Deactivate the current conda environment
---
--- Treat an inactive environment as a successful no-op
--- @return boolean ok
--- @return string? err
function M.deactivate()
    local shlvl = tonumber(vim.env.CONDA_SHLVL or '') or 0
    local prefix = vim.env.CONDA_PREFIX
    if shlvl <= 0 and (not prefix or prefix == '') then
        return true
    end

    return conda_activate(nil)
end

return M
