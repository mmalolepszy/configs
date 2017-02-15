---
 -- Resolves closest directory location for specified directory.
 -- Navigates subsequently up one level and tries to find specified directory
 -- @param  {string} path    Path to directory will be checked. If not provided
 --                          current directory will be used
 -- @param  {string} dirname Directory name to search for
 -- @return {string} Path to specified directory or nil if such dir not found
local function get_dir_contains(path, dirname)

    -- return parent path for specified entry (either file or directory)
    local function pathname(path)
        local prefix = ""
        local i = path:find("[\\/:][^\\/:]*$")
        if i then
            prefix = path:sub(1, i-1)
        end
        return prefix
    end

    -- Navigates up one level
    local function up_one_level(path)
        if path == nil then path = '.' end
        if path == '.' then path = clink.get_cwd() end
        return pathname(path)
    end

    -- Checks if provided directory contains git directory
    local function has_specified_dir(path, specified_dir)
        if path == nil then path = '.' end
        local found_dirs = clink.find_dirs(path..'/'..specified_dir)
        if #found_dirs > 0 then return true end
        return false
    end

    -- Set default path to current directory
    if path == nil then path = '.' end

    -- If we're already have .git directory here, then return current path
    if has_specified_dir(path, dirname) then
        return path..'/'..dirname
    else
        -- Otherwise go up one level and make a recursive call
        local parent_path = up_one_level(path)
        if parent_path == path then
            return nil
        else
            return get_dir_contains(parent_path, dirname)
        end
    end
end

local function get_git_dir(path)
    return get_dir_contains(path, '.git')
end

function string:trim()
    return self:match'^%s*(.*%S)' or ''
end

function string:split(p)
    local temp = {}
    local index = 0
    local last_index = string.len(self)

    while true do
        local i, e = string.find(self, p, index)

        if i and e then
            local next_index = e + 1
            local word_bound = i - 1
            table.insert(temp, string.sub(self, index, word_bound))
            index = next_index
        else            
            if index > 0 and index <= last_index then
                table.insert(temp, string.sub(self, index, last_index))
            elseif index == 0 then
                table.insert(temp, self)
            end
            break
        end
    end

    return temp
end

---
 -- Find out number of stashes
---
function get_git_stash()
    for line in io.popen("type "..get_git_dir().."/logs/refs/stash 2>nul| wc -l"):lines() do
        return tonumber(line)
    end
end

function get_git_tag_or_hash()
    local tag
    for line in io.popen('git describe --exact-match 2>nul'):lines() do
        tag = line:trim()
    end
    
    if tag then
        return tag
    else
        for line in io.popen('git rev-parse --short HEAD 2>nul'):lines() do
            return ":"..line:trim()
        end
    end
end

---
 -- Get all status information about current git folder
 -- Based on https://github.com/magicmonty/bash-git-prompt
---
function get_git_enhanced_status()
    
    local result = {
        branch = '', 
        remote = '', 
        clean = true, 
        ahead = 0, 
        behind = 0, 
        untracked = 0, 
        changed = 0, 
        conflicts = 0, 
        staged = 0, 
        stashed = get_git_stash()
    }

    for line in io.popen("git status --porcelain --branch -uall"):lines() do
        first = line:sub(1, 1)
        second = line:sub(2, 2)
        rest = line:sub(4):trim()
        
        if first == "#" and second == "#" then
            if rest:find("Initial commit on") then
                _,_,result.branch = rest:find("Initial commit on (.+)")
            elseif rest:find("no branch") then
                result.branch = get_git_tag_or_hash()
            elseif #rest:split("%.%.%.") == 1 then
                result.branch = rest
            else
                chunks = rest:split("%.%.%.")
                result.branch = chunks[1]
                result.remote = chunks[2]:split(" ")[1]
                if #chunks[2]:split(" ") > 1 then
                    divergence = table.concat(chunks[2]:split(" "), " ", 2)
                    _,_,result.ahead = divergence:find("ahead (%d+)")
                    _,_,result.behind = divergence:find("behind (%d+)")
                end
            end
        elseif first == "?" and second == "?" then
            result.untracked = result.untracked + 1
        else
            if second == "M" or second == "D" then
                result.changed = result.changed + 1
            end
            if first == "U" or second == "U" or (first == "A" and second == "A") or (first == "D" and second == "D") then
                result.conflicts = result.conflicts + 1
            elseif first ~= " " then
                result.staged = result.staged + 1
            end
        end
    end

    if result.changed == 0 and result.staged == 0 and result.conflicts == 0 and result.untracked == 0 then
        result.clean = true
    else
        result.clean = false
    end

    return result
end

---
 -- Format prompt from status values
---
function get_git_prompt(status)
    -- Colors for git status
    local colors = {
        normal = "\x1b[37;0m",
        clean = "\x1b[1;37;40m",
        dirty = "\x1b[31;1m",
        status = "\x1b[34;1m",
        divergence = "\x1b[1;35m"
    }

    local symbols = {
        ahead = "↑",
        behind = "↓",
        staged = "●",
        conflicts = "✖",
        changed = "✚",
        untracked = "…",
        stashed = "⌂"
    }

    if status.clean then
        status.color = colors.clean
    else
        status.color = colors.dirty
    end

    local prompt = colors.normal.."("..status.color..status.branch..colors.normal

    if (status.ahead and tonumber(status.ahead) > 0) or (status.behind and tonumber(status.behind) > 0) then
        prompt = prompt.." "..colors.divergence
        if (status.ahead and tonumber(status.ahead) > 0) then
            prompt = prompt..symbols.ahead..status.ahead.." "
        end
        if (status.behind and tonumber(status.behind) > 0) then
            prompt = prompt..symbols.behind..status.behind
        end
    end

    prompt = prompt:trim()..colors.normal..") "

    if status.staged > 0 or status.changed > 0 or status.conflicts > 0 or status.untracked > 0 or status.stashed > 0 then
        prompt = prompt..colors.normal.."["..colors.status
        if status.staged > 0 then
            prompt = prompt..symbols.staged..status.staged.." "
        end
        if status.changed > 0 then
            prompt = prompt..symbols.changed..status.changed.." "
        end
        if status.conflicts > 0 then
            prompt = prompt..symbols.conflicts..status.conflicts.." "
        end
        if status.untracked > 0 then
            prompt = prompt..symbols.untracked..status.untracked.." "
        end
        if status.stashed > 0 then
            prompt = prompt..symbols.stashed..status.stashed.." "
        end

        prompt = prompt:trim()..colors.normal.."] "
    end

    return prompt
end

function git_enhanced_prompt_filter()
    if get_git_dir() then
        -- if we're inside of git repo then try to detect current branch
        local status = get_git_enhanced_status()

        if status.branch then
            -- Has branch => therefore it is a git folder, now figure out status
            local prompt = get_git_prompt(status)

            clink.prompt.value = string.gsub(clink.prompt.value, "{git_enhanced}", prompt)
            return false
        end
    end

    -- No git present or not in git file
    clink.prompt.value = string.gsub(clink.prompt.value, "{git_enhanced}", "")
    return false
end

