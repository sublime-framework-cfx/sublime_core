return { -- ps: false no one can change / true everyone can change / table only specific permission can change

    profiles = {
        username = {['owner'] = true, ['admin'] = true}, -- change username
        password = true, -- change password 
        logo = true,
    },

    resource = {
        stop = {['dev'] = true, ['owner'] = true, ['admin'] = true}, -- stop resource
    },

    command = {
        -- not implemented yet!
    }
}