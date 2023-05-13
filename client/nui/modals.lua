local p, nui <const> = nil, require 'client.modules.nui'

---@param data boolean
nui.RegisterReactCallback('sl:modal:closedCondirm', function(data, cb)
    if p then p:resolve(data) end p = nil
    cb(1)
end, true)

---@param data table
nui.RegisterReactCallback('sl:modal:closedCustom', function(data, cb)
    if p then
        local temp = {}
        for k, v in pairs(data) do
            temp[tonumber(k)+1] = v
        end
        p:resolve(temp)
    end p = nil
    cb(1)
end, true)

---@class ModalConfrim
---@field type 'confirm'
---@field title? string
---@field subtitle? string
---@field description? string

---@class ModalCustom
---@field type 'custom'
---@field title? string
---@field options {type: 'checkbox' | 'input' | 'select' | 'textarea'}

--- supv.openModal
---@param data ModalConfrim|ModalCustom|...
---@return boolean
function sl.openModal(data)
    if type(data) ~= 'table' then return end
    if type(data.type) ~= 'string' then return end
    if p then return end

    if data.type == 'custom' and (not data.options or #data.options < 1) then return end

    nui.SendReactMessage(true, {
        action = 'sl:modal:opened',
        data = data
    }, {
        focus = true
    })

    p = promise.new()
    return sl.await(p)
end