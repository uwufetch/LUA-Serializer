---@diagnostic disable: cast-local-type
local settings = {
    prioritizecompression = false
}

local sub = string.sub
local find = string.find
local format = string.format
local gsub = string.gsub
local dump = string.dump
local byte = string.byte
local rep = string.rep
local concat = table.concat
local insert = table.insert
local type = type
local tostring = tostring
local pairs = pairs
local huge = math.huge
local nhuge = -huge

local newline = '\n'
local newline2 = '\\n'

local tab = '\t'
local tab2 = '\\t'

local function mutate(str, q)
    local mutated = {}
    local length = #str
    local i = 0
    while i < length do
        i = i + 1

        local c = sub(str, i, i)
        if c == newline then
            c = newline2
        elseif c == tab then
            c = tab2
        else
            if (q == 1 or q == 3) and c == "'" then
                c = "\\'"
            end

            if (q == 2 or q == 3) and c == '"' then
                c = '\\"'
            end
        end

        insert(mutated, c)
    end

    return concat(mutated)
end

local function quotes(str)
    local dq = find(str, '"')
    local sq = find(str, "'")

    local c = 0
    if dq then c = c + 2 end
    if sq then c = c + 1 end

    return format('"%s"', mutate(str, c))
end

local function serializedata(data)
    if not data then
        return 'nil'
    end

    local typeof = type(data)

    if typeof == 'string' then
        return quotes(data)
    elseif typeof == 'boolean' then
        return (data and 'true' or 'false')
    end

    local ts = tostring(data)

    if typeof == 'number' then
        if data == huge then
            return 'math.huge'
        elseif data == nhuge then
            return '-math.huge'
        end

        if settings.prioritizecompression then
            local h = format('0x%x', data)
            if #h < #ts then
                return (h)
            end
        end
    elseif typeof == 'function' then
        if settings.prioritizecompression then
            return format('--[[%s]]', ts)
        else
            return format("function(...) return loadstring(\"%s\")(...); end",
                gsub(dump(data), ".", function(k) return "\\" .. byte(k); end))
        end
    elseif typeof == 'table' then
        return nil
    end

    return (ts)
end

local function serializetable(tbl, level, checked)
    checked = checked or {}
    level = level or 1

    if checked[tbl] then
        return 'tbl'
    end

    checked[tbl] = true

    local result = { '{\n' }
    for i, v in pairs(tbl) do
        local sd = serializedata(v)
        if sd ~= nil then
            insert(result, format('%s[%s] = %s,\n', rep("\t", level), serializedata(i) or '', sd))
        else
            insert(result, format('%s[%s] = %s,\n', rep("\t", level), serializedata(i), serializetable(v, level + 1, checked)))
        end
    end

    result = concat(result)
    result = format("%s\n%s}", sub(result, 0, #result - 2), rep('\t', level - 1))
    return result
end

return serializetable
