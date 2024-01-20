
--[[
****************************************
Author: neorrrr123
CreateDate: 2023-07-28
Brief: 全分词查找管理器
****************************************
Desc:    
    测试记录：
    40w个名字，构建索引耗时20-25s，占用 < 2G（用敏感词库拼接测试） 实际情况例如公会，限制名称长度为6个汉字会构建更快

    使用流程：
    0. local SEARCH_MGR = require("search_mgr")
    1. local search_mgr = SEARCH_MGR:New() 创建对象
    2. search_mgr:AddIndex(uid, name) 添加索引
    3. local result_list = search_mgr:Search(name) 模糊查找
    4. local result_list = search_mgr:FullMatchSearch(name) 全匹配查找
    5. search_mgr:DelIndex(uid) 删除索引

    使用模块：
    1.公会名查找
]]
local utf8_codes = utf8.codes
local utf8_char  = utf8.char

local s_sub = string.sub

local ipairs = ipairs
local pairs  = pairs
local next   = next

local _type_fuzzy <const> = 1 -- 模糊查询
local _type_full <const>  = 2 -- 全匹配

local SearchMgr = {}

-- 初始化
function SearchMgr:New()
    local o = {
        _NameSplitMap = {}, -- 存储分词索引
        _Size = 0,
    }
    return setmetatable(o, { __index = self })
end

-- 缓存表 用于存储备选词
local _tmp_add_key_map = {}
-- 缓存表 用于存储分词位置
local _tmp_keys_list = {}
-- 拆词
local function __SplitWords(name)
    local len = 0
    for i, c in utf8_codes(name) do
        -- 记录单字分词
        _tmp_add_key_map[utf8_char(c)] = _type_fuzzy
        len = len + 1
        -- 缓存起始位置
        _tmp_keys_list[len] = i
    end
    if len == 0 then return end
    -- 补充最后一个词的结束位置
    -- +1 便于下面取值同时-1
    _tmp_keys_list[len + 1] = #name + 1
    -- 直接存储全词，并且设置为全匹配，便于全匹配查询
    _tmp_add_key_map[name] = _type_full
    local _sub_start_idx
    for i = 1, len - 1, 1 do
        _sub_start_idx = _tmp_keys_list[i]
        -- (i == 1 and len - 1 or len) 用于跳过全词
        for j = i + 1, (i == 1 and len - 1 or len), 1 do
            -- 由于存储的是起始位置，所以需要-1
            _tmp_add_key_map[s_sub(name, _sub_start_idx, _tmp_keys_list[j + 1] - 1)] = _type_fuzzy
        end
    end
    for index, _ in ipairs(_tmp_keys_list) do
        _tmp_keys_list[index] = nil
    end
end

-- 添加索引
function SearchMgr:AddIndex(uid, name)
    __SplitWords(name)
    if not next(_tmp_add_key_map) then return end
    local search_map
    local _NameSplitMap = self._NameSplitMap
    for key, type in pairs(_tmp_add_key_map) do
        _tmp_add_key_map[key] = nil
        search_map = _NameSplitMap[key]
        if not search_map then
            search_map = {}
            _NameSplitMap[key] = search_map
        end
        search_map[uid] = type
    end
    self._Size = self._Size + 1
end

-- 删除索引
function SearchMgr:DelIndex(uid, name)
    __SplitWords(name)
    if not next(_tmp_add_key_map) then return end
    local search_map
    local _NameSplitMap = self._NameSplitMap
    for key, _ in pairs(_tmp_add_key_map) do
        _tmp_add_key_map[key] = nil
        search_map = _NameSplitMap[key]
        if search_map then
            search_map[uid] = nil
            if not next(search_map) then
                _NameSplitMap[key] = nil
            end
        end
    end
    self._Size = self._Size - 1
end

function SearchMgr:Reset()
    self._NameSplitMap = {}
    self._Size = 0
end

-- 模糊查询
function SearchMgr:Search(name, max_cnt)
    local result = {}
    local search_map = self._NameSplitMap[name]
    if not search_map then
        return result
    end

    local amount = 0
    for uid, _ in pairs(search_map) do
        amount = amount + 1
        result[amount] = uid
        if max_cnt and amount >= max_cnt then break end
    end
    return result
end

-- 全匹配查询
function SearchMgr:FullMatchSearch(name)
    local result = {}
    local search_map = self._NameSplitMap[name]
    if not search_map then
        return result
    end

    local amount = 0
    for uid, type in pairs(search_map) do
        if type == _type_full then
            amount = amount + 1
            result[amount] = uid
        end
    end
    return result
end

return SearchMgr
