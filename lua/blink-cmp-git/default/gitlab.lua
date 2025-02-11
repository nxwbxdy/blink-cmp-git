local utils = require('blink-cmp-git.utils')
local common = require('blink-cmp-git.default.common')

local default_gitlab_enable = function()
    if not utils.command_found('git') or
        not utils.command_found('glab') and not utils.command_found('curl') then
        return false
    end
    return utils.get_repo_remote_origin_url():find('gitlab.com')
end

-- TODO: refactor this function
local function default_gitlab_mr_or_issue_configure_score_offset(items)
    -- Bonus to make sure items sorted as below:
    -- open issue, open pr, closed issue, merged pr, closed pr
    local keys = {
        'OPENIssue',
        'OPENPR',
        'CLOSEDIssue',
        'MERGEDPR',
        'CLOSEDPR'
    }
    local bonus = 999999
    local bonus_score = {}
    for i = 1, #keys do
        bonus_score[keys[i]] = bonus * (#keys - i)
    end
    for i = 1, #items do
        local state = ''
        if type(items[i].documentation) == 'string' then
            state = items[i].documentation:match('State: (%w*)')
        end
        local bonus_key = state .. items[i].kind_name
        if bonus_score[bonus_key] then
            items[i].score_offset = bonus_score[bonus_key]
        end
        -- sort by number when having the same bonus score
        local number = items[i].label:match('#(%d+)')
        if number then
            if items[i].score_offset == nil then
                items[i].score_offset = 0
            end
            items[i].score_offset = items[i].score_offset + tonumber(number)
        end
    end
end

local function default_gitlab_issue_get_label(item)
    return utils.concat_when_all_true('#', item.iid, ' ', item.title, '')
end

local function default_gitlab_issue_get_kind_name(_)
    return 'Issue'
end

local function default_gitlab_issue_get_insert_text(item)
    return utils.concat_when_all_true('#', item.iid, '')
end

local function default_gitlab_issue_get_documentation(item)
    return
        utils.concat_when_all_true('#', item.iid, ' ', item.title, '\n') ..
        utils.concat_when_all_true('State: ', item.state, '\n') ..
        utils.concat_when_all_true('Author: ', item.author.username, '') ..
        utils.concat_when_all_true(' (', item.author.name, ')') .. '\n' ..
        utils.concat_when_all_true('Created at: ', item.created_at, '\n') ..
        utils.concat_when_all_true('Updated at: ', item.updated_at, '\n') ..
        utils.concat_when_all_true('Closed  at: ', item.closed_at, '\n') ..
        utils.concat_when_all_true(item.description, '')
end

local function default_gitlab_mr_get_label(item)
    return utils.concat_when_all_true('!', item.iid, ' ', item.title, '')
end

local function default_gitlab_mr_get_kind_name(_)
    return 'MR'
end

local function default_gitlab_mr_get_insert_text(item)
    return utils.concat_when_all_true('!', item.iid, '')
end

local function default_gitlab_mr_get_documentation(item)
    return
        utils.concat_when_all_true('!', item.iid, ' ', item.title, '\n') ..
        utils.concat_when_all_true('State: ', item.state, '\n') ..
        utils.concat_when_all_true('Author: ', item.author.username, '') ..
        utils.concat_when_all_true(' (', item.author.name, ')') .. '\n' ..
        utils.concat_when_all_true('Created at: ', item.created_at, '\n') ..
        utils.concat_when_all_true('Updated at: ', item.updated_at, '\n') ..
        (
            item.state == 'MERGED' and
            utils.concat_when_all_true('Merged  at: ', item.merged_at, '\n') ..
            utils.concat_when_all_true('Merged  by: ', item.merged_by.username, '') ..
            utils.concat_when_all_true(' (', item.merged_by.name, ')') .. '\n'
            or
            utils.concat_when_all_true('Closed  at: ', item.closed_at, '\n')
        ) ..
        utils.concat_when_all_true(item.description, '')
end

local function default_gitlab_mention_get_label(item)
    return utils.concat_when_all_true(item.username, '')
end

local function default_gitlab_mention_get_kind_name(_)
    return 'Mention'
end

local function default_gitlab_mention_get_insert_text(item)
    return utils.concat_when_all_true('@', item.username, '')
end

local function default_gitlab_mention_get_documentation(item)
    return {
        get_command = 'glab',
        get_command_args = {
            'api',
            'users/' .. tostring(item.id),
        },
        ---@diagnostic disable-next-line: redefined-local
        resolve_documentation = function(output)
            local user_info = utils.json_decode(output)
            utils.remove_empty_string_value(user_info)
            return
                utils.concat_when_all_true(user_info.username, '') ..
                utils.concat_when_all_true(' (', user_info.name, ')') .. '\n' ..
                utils.concat_when_all_true('Location: ', user_info.location, '\n') ..
                utils.concat_when_all_true('Email: ', user_info.public_email, '\n') ..
                utils.concat_when_all_true('Company: ', user_info.work_information, '\n') ..
                utils.concat_when_all_true('Created at: ', user_info.created_at, '\n')
        end
    }
end

--- @type blink-cmp-git.GCSOptions
return {
    issue = {
        enable = default_gitlab_enable,
        triggers = { '#' },
        get_command = 'glab',
        get_command_args = {
            'issue',
            'list',
            '--all',
            '--output', 'json',
        },
        insert_text_trailing = ' ',
        separate_output = common.json_array_separator,
        get_label = default_gitlab_issue_get_label,
        get_kind_name = default_gitlab_issue_get_kind_name,
        get_insert_text = default_gitlab_issue_get_insert_text,
        get_documentation = default_gitlab_issue_get_documentation,
        configure_score_offset = default_gitlab_mr_or_issue_configure_score_offset,
        on_error = common.default_on_error,
    },
    pull_request = {
        enable = default_gitlab_enable,
        triggers = { '!' },
        get_command = 'glab',
        get_command_args = {
            'mr',
            'list',
            '--all',
            '--output', 'json',
        },
        insert_text_trailing = ' ',
        separate_output = common.json_array_separator,
        get_label = default_gitlab_mr_get_label,
        get_kind_name = default_gitlab_mr_get_kind_name,
        get_insert_text = default_gitlab_mr_get_insert_text,
        get_documentation = default_gitlab_mr_get_documentation,
        configure_score_offset = default_gitlab_mr_or_issue_configure_score_offset,
        on_error = common.default_on_error,
    },
    mention = {
        enable = default_gitlab_enable,
        triggers = { '@' },
        get_command = 'glab',
        get_command_args = {
            'api',
            'projects/:id/users',
        },
        insert_text_trailing = ' ',
        separate_output = common.json_array_separator,
        get_label = default_gitlab_mention_get_label,
        get_kind_name = default_gitlab_mention_get_kind_name,
        get_insert_text = default_gitlab_mention_get_insert_text,
        get_documentation = default_gitlab_mention_get_documentation,
        configure_score_offset = common.score_offset_origin,
        on_error = common.default_on_error,
    },
}
