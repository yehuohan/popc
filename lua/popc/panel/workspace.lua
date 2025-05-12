--- @class Popc.Panel.Workspace Workspace based on vim session
local M = {}
local fn = vim.fn
local api = vim.api
local log = require('popc.log').get('workspace')
local config = require('popc.config')
local copts = config.opts
local umode = require('popc.usermode')

--- @class WorkspaceItem
--- @field name string
--- @field path string

--- Workspace panel context
--- @type PanelContext
local pctx = {
    name = 'Workspace',
    text = copts.icons.workspace .. ' Workspace',
    items = {},
    index = 1,
    keys = copts.workspace.keys,
    pkeys = {},
    -- Specified panel data
    --- @type WorkspaceItem[]
    wks_items = nil,
    wks_name = nil,
    wks_path = nil,
    wks_sort = 'name',
    --- @type ConfigData
    cfg_data = nil,
    --- @type table
    userdata = nil,
}

--- @return WorkspaceItem[]
local function load_wks_items()
    pctx.cfg_data = config.load_data()
    pctx.wks_items = pctx.cfg_data.workspaces
    return pctx.wks_items
end

--- @return WorkspaceItem[]
local function save_wks_items()
    pctx.cfg_data.workspaces = pctx.wks_items
    config.save_data(pctx.cfg_data)
    return pctx.wks_items
end

local function set_current_wks(name, path)
    pctx.wks_name = name
    pctx.wks_path = path
    vim.o.titlestring = ('%s @ %s'):format(name, path)
end

--- Check duplicated workspace item
--- @return boolean
local function check_wks_items(name)
    for _, wks in ipairs(pctx.wks_items) do
        if name == wks.name then
            return false
        end
    end
    return true
end

--- @param wks_items WorkspaceItem[]?
local function setup_wks_items(wks_items)
    pctx.wks_items = wks_items or load_wks_items()
    local items = {}
    for _, wks in ipairs(pctx.wks_items) do
        table.insert(items, {
            (wks.name == pctx.wks_name and wks.path == pctx.wks_path) and copts.icons.focus or '',
            wks.name,
            copts.icons.pointer,
            wks.path,
        })
    end
    pctx.items = items
end

--- @param tmpopts table?
--- @return table?
local function switch_options(tmpopts)
    if tmpopts then
        vim.o.sessionoptions = tmpopts.sessionoptions
        vim.o.switchbuf = tmpopts.switchbuf
        vim.o.autochdir = tmpopts.autochdir
    else
        tmpopts = {
            sessionoptions = vim.o.sessionoptions,
            switchbuf = vim.o.switchbuf,
            autochdir = vim.o.autochdir,
        }
        vim.o.sessionoptions = 'winsize,tabpages,curdir' -- terminal
        vim.o.switchbuf = ''
        vim.o.autochdir = false
        return tmpopts
    end
end

--- Load workspace
--- @param name string
--- @param path string
--- @param append boolean? Keep original tabpages/buffers or not
--- @param silent boolean? Ignore errors when source session
--- @return boolean
function M.load_workspace(name, path, append, silent)
    -- Check workspace file
    local filepath = config.get_wdir_file(name .. '.wks')
    if fn.filereadable(filepath) == 0 then
        umode.notify(("The workspace '%s' is invalid"):format(name))
        return false
    end
    if
        fn.isdirectory(path) == 0
        and (not umode.confirm(("The root '%s' doesn't exist, try open/load workspace anyway?"):format(path)))
    then
        return false
    end

    -- Handle current workspace
    if append then
        vim.cmd.tablast()
        vim.cmd.tabnew()
        if copts.tabuf.enable then
            require('popc.panel.tabuf').cmd_set_root(path)
        end
    else
        if copts.tabuf.enable then
            require('popc.panel.tabuf').cmd_clear_all()
            require('popc.panel.tabuf').cmd_set_root(path)
        else
            vim.cmd.tabonly({ bang = true, mods = { noautocmd = true, silent = true } })
            vim.cmd('silent! %bdelete!')
        end
    end
    set_current_wks(name, path)

    -- Source session as workspace
    local tmpopts = switch_options()
    fn.chdir(path)
    if silent then
        vim.cmd('silent! source ' .. filepath)
    else
        vim.cmd.source(filepath)
    end
    switch_options(tmpopts)

    -- Invoke user autocmd
    api.nvim_exec_autocmds('User', { pattern = 'PopcWorkspaceLoaded' })

    umode.notify(("Load workspace '%s' successful"):format(name))
    return true
end

--- Make session as workspace
--- @param filepath string Session filepath
--- @param root string Workspace root
local function make_session(filepath, root)
    root = root .. '/'
    local lines = {
        "let s:session_root = v:lua.require('popc.panel.workspace').cmd_get_wksroot()",
        'let s:session_tidx = tabpagenr()',
        ("let s:session_data = json_decode('%s')"):format(vim.json.encode(M.cmd_get_userdata())),
        "call v:lua.require('popc.panel.workspace').cmd_set_userdata(s:session_data)",
    }
    local tabnr = 1
    for cmd in io.lines(filepath) do
        if cmd:match('^cd ') then
            table.insert(lines, 'silent! exe "cd " . s:session_root')
        elseif cmd:match('^lcd ') then
            table.insert(lines, 'silent! exe "lcd " . s:session_root')
        elseif cmd:match("exists(':tcd')") then
            vim.list_extend(lines, {
                "if exists(':tcd') == 2",
                '  silent! exe "tcd " . s:session_root',
                'endif',
            })
        elseif (cmd:match('^%%argdel') and tabnr == 1) or ((cmd:match('^tabnew') or cmd:match('^tabedit')) and tabnr > 1) then
            if copts.tabuf.enable then
                -- Add new tabpage
                if tabnr == 1 then
                    table.insert(lines, cmd)
                else
                    table.insert(lines, 'set eventignore+=BufWinEnter')
                    table.insert(lines, 'tabnew')
                    table.insert(lines, 'set eventignore-=BufWinEnter')
                end
                -- Add tabpage buffers
                local tid = api.nvim_list_tabpages()[tabnr]
                local tabctx = require('popc.panel.tabuf').cmd_get_tabctx()
                for _, bid in ipairs(tabctx[tid].bufs) do
                    local info = fn.getbufinfo(bid)[1]
                    if info.name == '' then
                        table.insert(lines, 'enew') -- There's a no name buffer
                    else
                        local file = fn.substitute(vim.fs.normalize(info.name), root, '', 'g')
                        table.insert(lines, string.format('edit +%d %s', info.lnum, fn.fnameescape(file)))
                    end
                end
                -- Switch to current buffer of tab
                if tabnr > 1 and (not cmd:match('bufhidden=wipe')) then
                    table.insert(lines, 'edit' .. fn.substitute(cmd, '\v^tabnew|^tabedit', '', ''))
                end
                -- Set tabpage label
                local attr = vim.json.encode({ label = tabctx[tid].label, tdir = tabctx[tid].tdir })
                if attr ~= '[]' then
                    table.insert(
                        lines,
                        ("call v:lua.require('popc.panel.tabuf').cmd_set_tabctx(nvim_list_tabpages()[s:session_tidx - 1 + %d], %s)"):format(
                            tabnr - 1,
                            attr
                        )
                    )
                end
                tabnr = tabnr + 1
            else
                table.insert(lines, cmd)
            end
        elseif cmd:match('^tabrewind') then
            -- Start from base tabnr
            table.insert(lines, 'exe "tabnext " . s:session_tidx')
        elseif cmd:match('^tabnext %d+') then
            -- Back to init tab
            table.insert(lines, ('exe "tabnext " . string(s:session_tidx - 1 + %s)'):format(fn.split(cmd)[2]))
        elseif cmd:match('win_findbuf%(s:wipebuf%)') or cmd:match("exists%('s:wipebuf'%)") then
            -- Only remove no name buffer
            table.insert(lines, "if exists('s:wipebuf') && empty(bufname(s:wipebuf))")
        elseif cmd:match('^$argadd') or cmd:match('^badd') or cmd:match('^silent only') or cmd:match('^silent tabonly') then
            -- Delete lines
        elseif cmd:match(root) then
            -- Use relative path to root
            table.insert(lines, fn.substitute(cmd, root, '', 'g'))
        else
            table.insert(lines, cmd)
        end
    end
    fn.writefile(lines, filepath)
end

--- Save workspace
--- @param name string
--- @param path string
function M.save_workspace(name, path)
    local filepath = config.get_wdir_file(name .. '.wks')
    set_current_wks(name, path)

    -- Make session as workspace
    local tmpopts = switch_options()
    fn.chdir(path)
    vim.cmd.mksession({ bang = true, args = { filepath } })
    switch_options(tmpopts)

    -- Invoke user autocmd
    api.nvim_exec_autocmds('User', { pattern = 'PopcWorkspaceSavePre' })
    -- vim.uv.fs_copyfile(filepath, filepath .. '.ori')
    make_session(filepath, path)
    umode.notify(("Saved workspace '%s' successful"):format(name))
end

function M.setup()
    api.nvim_create_user_command('PopcWorkspace', M.pop, { nargs = 0 })
end

function M.inspect()
    return vim.inspect(pctx), pctx
end

--- Panel keys handler
local pkeys = pctx.pkeys

function pkeys.open_workspace_quit(uctx)
    local item = pctx.wks_items[pctx.index]
    if not item then
        return
    end
    if M.load_workspace(item.name, item.path, false) then
        uctx.state = umode.State.None
        log('Opened workspace: name = %s, path = %s', item.name, item.path)
    end
end

function pkeys.open_workspace_quit_silent(uctx)
    local item = pctx.wks_items[pctx.index]
    if not item then
        return
    end
    if M.load_workspace(item.name, item.path, false, true) then
        uctx.state = umode.State.None
        log('Opened workspace silently: name = %s, path = %s', item.name, item.path)
    end
end

function pkeys.load_workspace_quit(uctx)
    local item = pctx.wks_items[pctx.index]
    if not item then
        return
    end
    if M.load_workspace(item.name, item.path, true) then
        uctx.state = umode.State.None
        log('Loaded workspace: name = %s, path = %s', item.name, item.path)
    end
end

function pkeys.append_workspace(uctx)
    local name = umode.input({ prompt = 'Set workspace name: ' })
    if not name or name == '' then
        return
    end
    local path = umode.input({
        prompt = 'Set workspace root: ',
        default = vim.fs.root(api.nvim_buf_get_name(api.nvim_get_current_buf()), copts.root_marker),
        completion = 'file',
    })
    if not path or path == '' then
        return
    end
    path = vim.fs.normalize(fn.fnamemodify(path, ':p'))
    if fn.isdirectory(path) == 0 then
        umode.notify(("The root '%s' doesn't exist"):format(path))
        return
    end

    if not check_wks_items(name) then
        umode.notify(("A same workspace '%s' already exists"):format(name))
        return
    end
    M.save_workspace(name, path)
    table.insert(pctx.wks_items, { name = name, path = path })
    save_wks_items()

    setup_wks_items(pctx.wks_items)
    uctx.state = umode.State.ReDisp
    log('Appended workspace: name = %s, path = %s', name, path)
end

function pkeys.delete_workspace(uctx)
    local item = pctx.wks_items[pctx.index]
    if not item then
        return
    end

    if not umode.confirm(("Delete workspace '%s'?"):format(item.name)) then
        return
    end
    local filepath = config.get_wdir_file(item.name .. '.wks')
    if fn.filereadable(filepath) == 1 then
        fn.delete(filepath)
    end
    table.remove(pctx.wks_items, pctx.index)
    save_wks_items()

    setup_wks_items(pctx.wks_items)
    uctx.state = umode.State.ReDisp
    log('Deleted workspace: name = %s, path = %s', item.name, item.path)
end

function pkeys.save_workspace()
    local item = pctx.wks_items[pctx.index]
    if not item then
        return
    end

    if pctx.wks_name ~= item.name or pctx.wks_path ~= item.path then
        umode.notify("Can't override a different workspace")
        return
    end

    M.save_workspace(item.name, item.path)
    log('Saved workspace: name = %s, path = %s', item.name, item.path)
end

function pkeys.save_workspace_forcely(uctx)
    local item = pctx.wks_items[pctx.index]
    if not item then
        return
    end

    if not umode.confirm(("ATTENTION: Override the workspace '%s' forcely?"):format(item.name)) then
        return
    end
    M.save_workspace(item.name, pctx.wks_path)
    item.path = pctx.wks_path
    save_wks_items()

    setup_wks_items(pctx.wks_items)
    uctx.state = umode.State.ReDisp
    log('Saved workspace forcely: name = %s, path = %s', item.name, item.path)
end

function pkeys.set_workspace_name(uctx)
    local item = pctx.wks_items[pctx.index]
    if not item then
        return
    end

    local name = umode.input({ prompt = 'Set workspace name: ' })
    if not name or name == '' or name == item.name then
        return
    end
    if not check_wks_items(name) then
        umode.notify(("A same workspace '%s' already exists"):format(name))
        return
    end
    local current = (pctx.wks_name == item.name and pctx.wks_path == item.path)
    fn.rename(config.get_wdir_file(item.name .. '.wks'), config.get_wdir_file(name .. '.wks'))
    item.name = name
    if current then
        pctx.wks_name = name
        set_current_wks(name, item.path)
    end
    save_wks_items()

    setup_wks_items(pctx.wks_items)
    uctx.state = umode.State.ReDisp
end

function pkeys.set_workspace_root(uctx)
    local item = pctx.wks_items[pctx.index]
    if not item then
        return
    end

    local path = umode.input({
        prompt = 'Set workspace root: ',
        default = vim.fs.root(api.nvim_buf_get_name(api.nvim_get_current_buf()), copts.root_marker),
        completion = 'file',
    })
    if not path or path == '' then
        return
    end
    path = vim.fs.normalize(fn.fnamemodify(path, ':p'))
    if fn.isdirectory(path) == 0 then
        umode.notify(("The root '%s' doesn't exist"):format(path))
        return
    end
    local current = (pctx.wks_name == item.name and pctx.wks_path == item.path)
    item.path = path
    if current then
        pctx.wks_path = path
        set_current_wks(item.name, path)
    end
    save_wks_items()

    setup_wks_items(pctx.wks_items)
    uctx.state = umode.State.ReDisp
end

function pkeys.sort_workspace(uctx)
    if #pctx.wks_items <= 1 then
        return
    end

    local sort = pctx.wks_sort == 'name' and 'path' or 'name'
    table.sort(pctx.wks_items, function(wa, wb)
        return vim.stricmp(wa[sort], wb[sort]) < 0
    end)
    pctx.wks_sort = sort
    save_wks_items()

    setup_wks_items(pctx.wks_items)
    uctx.state = umode.State.ReDisp
end

function M.pop()
    setup_wks_items()
    umode.apop(pctx)
end

--- @return string
function M.cmd_get_wksname()
    return pctx.wks_name or ''
end

--- @return string
function M.cmd_get_wksroot()
    return pctx.wks_path or ''
end

--- Set user data to save along with workspace
---
--- Usaully invoke at `PopcWorkspaceSavePre`
--- @param userdata table
function M.cmd_set_userdata(userdata)
    pctx.userdata = userdata
end

--- Get user data loaded along with workspace
---
--- Usaully invoke at `PopcWorkspaceLoaded`
--- @return table userdata
function M.cmd_get_userdata()
    return pctx.userdata or vim.empty_dict()
end

return M
