--- @class Popc.Panel.Bookmark
local M = {}
local api = vim.api
local config = require('popc.config')
local copts = config.opts
local umode = require('popc.usermode')

--- @class BookmarkItem
--- @field name string
--- @field path string

--- Bookmark panel context
--- @type PanelContext
local pctx = {
    name = 'Bookmark',
    text = copts.icons.bookmark .. ' Bookmark',
    items = {},
    index = 1,
    keys = copts.bookmark.keys,
    pkeys = {},
    -- Specified panel data
    --- @type BookmarkItem[]
    bkm_items = nil,
    bkm_sort = 'name',
    --- @type ConfigData
    cfg_data = nil,
}

--- @return BookmarkItem[]
local function load_bkm_items()
    pctx.cfg_data = config.load_data()
    pctx.bkm_items = pctx.cfg_data.bookmarks
    return pctx.bkm_items
end

--- @return BookmarkItem[]
local function save_bkm_items()
    pctx.cfg_data.bookmarks = pctx.bkm_items
    config.save_data(pctx.cfg_data)
    return pctx.bkm_items
end

--- Check duplicated bookmark item
--- @return boolean
local function check_bkm_items(name, path)
    for _, bkm in ipairs(pctx.bkm_items) do
        if name == bkm.name and path == bkm.path then
            return false
        end
    end
    return true
end

--- @param bkm_items BookmarkItem[]?
local function setup_bkm_items(bkm_items)
    pctx.bkm_items = bkm_items or load_bkm_items()
    local items = {}
    for _, bkm in ipairs(pctx.bkm_items) do
        table.insert(items, { bkm.name, copts.icons.pointer, bkm.path })
    end
    pctx.items = items
end

function M.setup()
    api.nvim_create_user_command('PopcBookmark', M.pop, { nargs = 0 })
end

function M.inspect()
    return vim.inspect(pctx), pctx
end

--- Panel keys handler
local pkeys = pctx.pkeys

--- @param uctx UsermodeContext
--- @param cmd string
local function load_with(uctx, cmd)
    local item = pctx.bkm_items[pctx.index]
    if not item then
        return
    end
    vim.cmd[cmd](vim.fs.joinpath(item.path, item.name))
    uctx.state = umode.State.ReDraw
end

function pkeys.load_bookmark(uctx)
    load_with(uctx, 'edit')
end

function pkeys.load_bookmark_quit(uctx)
    pkeys.load_bookmark(uctx)
    uctx.state = umode.State.None
end

function pkeys.split_bookmark(uctx)
    load_with(uctx, 'split')
end

function pkeys.split_bookmark_quit(uctx)
    pkeys.split_bookmark(uctx)
    uctx.state = umode.State.None
end

function pkeys.vsplit_bookmark(uctx)
    load_with(uctx, 'vsplit')
end

function pkeys.vsplit_bookmark_quit(uctx)
    pkeys.vsplit_bookmark(uctx)
    uctx.state = umode.State.None
end

function pkeys.tabnew_bookmark(uctx)
    load_with(uctx, 'tabnew')
    uctx.state = umode.State.RePop
end

function pkeys.tabnew_bookmark_quit(uctx)
    pkeys.tabnew_bookmark(uctx)
    uctx.state = umode.State.None
end

function pkeys.append_bookmark(uctx)
    local filepath = api.nvim_buf_get_name(api.nvim_get_current_buf())
    if filepath == '' then
        umode.notify("Can't append a empty bookmark")
        return
    end

    filepath = vim.fs.normalize(filepath)
    local name = vim.fs.basename(filepath)
    local path = vim.fs.dirname(filepath)
    if not check_bkm_items(name, path) then
        return
    end

    if not umode.confirm(('Append a bookmark: %s'):format(filepath)) then
        return
    end
    table.insert(pctx.bkm_items, { name = name, path = path })
    save_bkm_items()

    setup_bkm_items(pctx.bkm_items)
    uctx.state = umode.State.ReDisp
end

function pkeys.delete_bookmark(uctx)
    local item = pctx.bkm_items[pctx.index]
    if not item then
        return
    end

    if not umode.confirm(("Delete bookmark '%s'?"):format(item.name)) then
        return
    end
    table.remove(pctx.bkm_items, pctx.index)
    save_bkm_items()

    setup_bkm_items(pctx.bkm_items)
    uctx.state = umode.State.ReDisp
end

function pkeys.sort_bookmark(uctx)
    if #pctx.bkm_items <= 1 then
        return
    end

    local sort = pctx.bkm_sort == 'name' and 'path' or 'name'
    table.sort(pctx.bkm_items, function(wa, wb)
        return vim.stricmp(wa[sort], wb[sort]) < 0
    end)
    pctx.bkm_sort = sort
    save_bkm_items()

    setup_bkm_items(pctx.bkm_items)
    uctx.state = umode.State.ReDisp
end

function M.pop()
    setup_bkm_items()
    umode.apop(pctx)
end

return M
