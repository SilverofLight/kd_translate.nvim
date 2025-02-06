local api, fn = vim.api, vim.fn

local kd = require("kd")
local command = api.nvim_create_user_command

command("TranslateNormal", function()
	kd._translate("n")
end, { desc = "Translate selected word" })

command("TranslateVisual", function()
	kd._translate("v")
end, { desc = "Translate selected word", range = true })
