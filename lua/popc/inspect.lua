--- @class Popc.Inspect Inspect targets for `:PopcInspect`
local M = {}

--- Registered inspect targets with tag and module name
--- @type table<string,string>
local inspec_tbl = {
    usermode = 'popc.usermode',
    tabuf = 'popc.panel.tabuf',
    bookmark = 'popc.panel.bookmark',
    workspace = 'popc.panel.workspace',
    selection = 'popc.panel.selection',
}

--- Register an inspect target
--- @param tag string
--- @param module string
function M.register(tag, module)
    if type(tag) ~= 'string' or tag == '' then
        error('PopcInspect tag must be a non-empty string')
    end
    if type(module) ~= 'string' or module == '' then
        error('PopcInspect module name must be a non-empty string')
    end
    inspec_tbl[tag] = module
end

--- Unregister an inspect target
--- @param tag string
function M.unregister(tag)
    inspec_tbl[tag] = nil
end

--- Get registered inspect target tags
--- @return string[]
function M.get_tags()
    local tags = vim.tbl_keys(inspec_tbl)
    table.sort(tags)
    return tags
end

--- Resolve an inspect target to a valid module
--- @param tag string
--- @return table? module
--- @return string? err
function M.resolve(tag)
    local target = inspec_tbl[tag]
    if not target then
        return nil, ('PopcInspect invalid tag: %s'):format(tag)
    end

    local ok, module = pcall(require, target)
    if not ok then
        return nil, ('PopcInspect failed to require target module: %s'):format(target)
    end

    if type(module) ~= 'table' or not vim.is_callable(module.inspect) then
        return nil, ('PopcInspect target module %s has no inspect()'):format(tag)
    end

    return module
end

return M
