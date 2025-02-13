local M = {}
local Job = require('plenary.job')

function M.is_inside_git_repo()
    if not M.command_found('git') then return false end
    local res = false
    ---@diagnostic disable-next-line: missing-fields
    Job:new({
        command = 'git',
        args = { 'rev-parse', '--is-inside-work-tree' },
        cwd = M.get_cwd(),
        env = M.get_job_default_env(),
        on_exit = function(_, return_value, _)
            res = return_value == 0
        end
    }):sync()
    return res
end

function M.get_option(opt, ...)
    if type(opt) == 'function' then
        return opt(...)
    else
        return opt
    end
end

--- @param command string
--- @return boolean
function M.command_found(command)
    return vim.fn.executable(command) == 1
end

function M.get_job_default_env()
    return vim.tbl_extend('force', vim.fn.environ(), {
        CLICOLOR_FORCE = '0',
        CLICOLOR = '0',
        PAGER = '',
    })
end

function M.get_repo_owner_and_repo(do_url_encode)
    local remote_url = M.get_repo_remote_origin_url()
    local owner, repo, res
    if remote_url:find('github.com') then
        owner, repo = remote_url:match('github%.com[/:]([^/]+)/([^/]+)%.git')
    elseif remote_url:find('gitlab.com') then
        owner, repo = remote_url:match('gitlab%.com[/:]([^/]+)/([^/]+)%.git')
    end
    if not owner or not repo then
        res = ''
    else
        res = owner .. '/' .. repo
    end
    if do_url_encode then
        res = string.gsub(res, '[^%w _%%%-%.~]', function(c)
            return string.format('%%%02X', string.byte(c))
        end)
    end
    return res
end

function M.remove_empty_string_value(tbl)
    for key, value in pairs(tbl) do
        if type(value) == 'table' then
            M.remove_empty_string_value(value)
        elseif type(value) == 'string' and value == '' then
            tbl[key] = nil
        end
    end
    return tbl
end

function M.truthy(value)
    if type(value) == 'boolean' then
        return value
    elseif type(value) == 'function' then
        return M.truthy(value())
    elseif type(value) == 'table' then
        return not vim.tbl_isempty(value)
    elseif type(value) == 'string' then
        return value ~= ''
    elseif type(value) == 'number' then
        return value ~= 0
    elseif type(value) == 'nil' then
        return false
    else
        return true
    end
end

--- Transform arguments to string, and concatenate them with a space.
function M.str(...)
    local args = { ... }
    for i, v in ipairs(args) do
        args[i] = type(args[i]) == 'string' and args[i] or vim.inspect(v)
    end
    return table.concat(args, ' ')
end

function M.get_repo_remote_origin_url()
    if not M.command_found('git') then return '' end
    local output = ''
    ---@diagnostic disable-next-line: missing-fields
    Job:new({
        command = 'git',
        args = { 'remote', 'get-url', 'origin' },
        cwd = M.get_cwd(),
        on_exit = function(job, return_value, _)
            if return_value ~= 0 then
                return
            end
            output = table.concat(job:result(), '\n')
        end
    }):sync()
    return output
end

function M.get_cwd()
    return require('blink-cmp-git').get_latest_git_source_config().get_cwd()
end

--- Get the absolute path of current git repo
--- Return nil if not in a git repo
--- @return string?
function M.get_git_repo_absolute_path()
    if not M.command_found('git') then return nil end
    local result
    ---@diagnostic disable-next-line: missing-fields
    Job:new({
        command = 'git',
        args = { 'rev-parse', '--show-toplevel' },
        cwd = M.get_cwd(),
        env = M.get_job_default_env(),
        on_exit = function(j, return_value, _)
            if return_value == 0 then
                result = table.concat(j:result(), '\n')
                if not M.truthy(result) then
                    result = nil
                end
            end
        end
    }):sync()
    return result
end

function M.json_decode(str, opts)
    opts = vim.tbl_extend('force', { luanil = { object = true, array = true } }, opts or {})
    return vim.json.decode(str, opts)
end

function M.concat_when_all_true(...)
    local args = {}
    for i = 1, select('#', ...) do
        local arg = select(i, ...)
        if not arg then
            return ''
        end
        table.insert(args, tostring(arg))
    end
    return table.concat(args, '')
end

return M
