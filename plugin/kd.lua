local api, fn = vim.api, vim.fn

local kd = require 'kd'
local command = api.nvim_create_user_command

command('translate', function() kd.translate() end,
    { desc = 'Translate selected word' })
