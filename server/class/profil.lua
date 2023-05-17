---@class CharsProfilsNuiProps
---@field firstname string
---@field lastname string
---@field sex string
---@field age number
---@field stats table

---@class ProfileNuiProps
---@field chars? CharsProfilsNuiProps
---@field username string
---@field stats table
---@field permission string

---@class AddCharProps
---@field firstname string
---@field lastname string
---@field dob string
---@field sex string
---@field height number
---@field model string

---@class LoadCharsProps[]
---@field firstname string
---@field lastname string
---@field dob string
---@field model string
---@field sex string
---@field height number
---@field skin table
---@field stats table
---@field isDead boolean

sl.profils = {}

---@param source integer
---@return table
local function GetAllIdentifiers(self, source) ---@todo move in module
    local listId = { steam = true, license = true, xbl = true, ip = true, discord = true, live = true }
    self.identifiers = {}
    for _,v in ipairs(GetPlayerIdentifiers(source)) do
        if listId[v:match('([^:]+)')] then
            self.identifiers[v:match('([^:]+)')] = v:gsub('([^:]+):', '')
        end
    end
    self.identifiers.token = GetPlayerToken(source)
    return self.identifiers
end

---@return boolean|void
local function GetProfilsDb(self, from)
    local query, db = nil, {}

    if from == 'token' then
        query = MySQL.query.await('SELECT * FROM profils WHERE previousId = ?', {self.identifiers.token})
    else
        query = MySQL.query.await('SELECT * FROM profils WHERE user = ? AND password = ?', {self.username, self.password})
    end

    if query ~= '[]' then
        for i = 1, #query do
            local result <const> = query[i]
            db.id = result.id
            db.username = result.user
            db.password = result.password
            db.permission = result.permission
            db.stats = json.decode(result.stats)
            db.createdBy = json.decode(result.createdBy)
            db.metadata = json.decode(result.metadata)
            return db
        end 
    end
end

---@return boolean
local function Disconnected(self)
    MySQL.update.await('UPDATE profils SET previousId = ? WHERE id = ?', {nil, self.id})
    sl.profils[self.source] = nil
    return true
end

---@param key string
---@param value any
local function SetMetadata(self, key, value)
    self.metadata[key] = value
end

---@param key string
---@return any
local function GetMetadata(self, key)
    return self.metadata[key]
end

---@return loadNuiProfiles
local function LoadNuiProfiles(self)
    local query <const> = MySQL.query.await('SELECT * FROM characters WHERE user = ?', {self.id})

    if query == '[]' then return false end

    local data = {}
    data.chars = {}

    for i = 1, #query do
        local char <const> = query[i]

        data.chars[i] = {
            firstname = char.firstname,
            lastname = char.lastname,
            sex = char.sex,
            dob = char.dateofbirth
        }
    end

    data.username = self.username
    data.permission = self.permission
    data.stats = self.stats
    data.logo = self.metadata.logo
    
    return data
end

---@return void
local function UpdateDb(self)
    local query = 'UPDATE profils SET user = ?, password = ?, stats = ?, metadata = ? WHERE id = ?'
    local update <const> = MySQL.update.await(query, {self.username, self.password, json.encode(self.stats or {}), json.encode(self.metadata), self.id})
    if update then 
        print('Update profil: '..self.username)
    else
        print('Error update profil: '..self.username)
    end
end

---@param reason string
local function KickPlayer(self, reason)
    if self.save then self:save() end
    DropPlayer(self.source, reason)
end

---@param key string
---@param value any
local function SetData(self, key, value)
    self[key] = value
end

---@param key string
---@return any
local function GetData(self, key)
    return self[key]
end

---@param data AddCharProps
---@return boolean
local function NewChar(self, data)
    local query <const> = 'INSERT INTO `characters` (`user`, `firstname`, `lastname`, `sex`, `dateofbirth`, `height`, `model`) VALUES (?, ?, ?, ?, ?, ?, ?)'
    local insert <const> = MySQL.insert.await(query, {self.id, data.firstname, data.lastname, data.sex, data.dob, data.height, data.model})
    if insert then
        return true
    end
    return false
end

---@param select string 'simple'
---@param data table ---@todo add type
local function Notify(self, select, data)
    sl.notify(self.source, select, data)
end

---@return array|false
local function LoadChars(self)
    local query <const> = MySQL.query.await('SELECT * FROM characters WHERE user = ?', {self.id})
    if query == '[]' then return false end
    local data = {} ---@type LoadCharsProps[]
    for i = 1, #query do
        local r = query[i]
        data[i] = {
            firstname = r.firstname,
            lastname = r.lastname,
            dob = r.dateofbirth,
            height = r.height,
            sex = r.sex,
            stats = json.decode(r.stats) or {},
            skin = json.decode(r.skin) or {},
            isDead = r.isDead or false,
            model = r.model
        }
    end
    return data
end

---@param args string|number|table|boolean
---@return boolean
local function HavePermission(self, args)
    if type(args) == 'string' and self.permission == args then return true
    elseif type(args) == 'number' and self.permission >= args then return true
    elseif type(args) == 'boolean' then return not args
    elseif type(args) == 'table' then
        if table.type(args) == 'array' then
            for i = 1, #args do
                if self.permission == args[i] then
                    return true
                end
            end
        elseif table.type == 'hash' then
            if args[self.permission] then
                return true
            end
        end
    end
    return false
end

---@param source integer
---@param username string
---@param password string
---@param external? boolean
---@return table|false
local function CreateProilsObj(source, username, password, external)
    local self = {}

    self.source = source
    self.kick = KickPlayer
    self.identifiers = GetAllIdentifiers(self, source)
    self.username = username

    password = password:gsub('%s+', '')

    self.password = joaat(password)

    local db = GetProfilsDb(self, external)
    if db then
        self.remove = Disconnected
        self.save = UpdateDb
        self.loadNuiProfiles = LoadNuiProfiles
        self.setMetadata = SetMetadata
        self.getMetadata = GetMetadata
        self.set = SetData
        self.get = GetData
        self.addCharacter = NewChar
        self.loadCharacters = LoadChars
        self.notify = Notify
        self.gotPerm = HavePermission
        self.spawned = false
        self.id = db.id
        self.username = db.username
        self.password = db.password
        self.stats = db.stats
        self.permission = db.permission
        self.createdBy = db.createdBy
        self.metadata = db.metadata
        sl.profils[source] = self
        sl.previousId[self.identifiers.token] = nil
        return self
    else 
        return false
    end
end

local function GetProfile(source)
    return sl.profils[source] or false
end

sl.createPlayerObj = CreateProilsObj
sl.getProfileFromId = GetProfile