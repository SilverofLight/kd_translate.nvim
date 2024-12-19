local M = {}
local api = vim.api
local fn = vim.fn

-- 默认配置
M.config = {
    -- 翻译命令配置
}
local translate_cmd = "kd"

-- 添加一个全局变量来跟踪当前的翻译窗口
local current_window = nil

-- 获取选中的文本
local function get_visual_selection()
    local mode = api.nvim_get_mode().mode
    if mode ~= 'v' and mode ~= 'V' then
        return fn.expand('<cword>')  -- 如果不在可视模式，返回光标下的词
    end

    -- 保存当前选区
    vim.cmd('noau normal! "vy"')
    
    -- 从 v 寄存器获取选中的文本
    local text = fn.getreg('v')
    
    -- 清理寄存器
    fn.setreg('v', {})
    
    return text
end

---@class TranslateWindow
local TranslateWindow = {}
TranslateWindow.__index = TranslateWindow

-- 默认窗口配置
local default_win_opts = {
    style = 'minimal',
    border = 'rounded',
    relative = 'cursor',
    focusable = true,
    title = ' 翻译结果 ',
    title_pos = 'center',
}

---创建新的翻译窗口
---@param text string 要显示的文本内容
---@return TranslateWindow
function TranslateWindow.new(text)
    local self = setmetatable({}, TranslateWindow)
    
    -- 创建缓冲区
    self.bufnr = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(self.bufnr, 0, -1, false, vim.split(text, '\n'))
    api.nvim_buf_set_option(self.bufnr, 'modifiable', false)
    api.nvim_buf_set_option(self.bufnr, 'filetype', 'markdown')
    
    -- 计算窗口尺寸
    local width = math.min(80, vim.o.columns - 4)
    local height = math.min(10, vim.o.lines - 4)
    
    -- 设置窗口配置
    self.win_opts = vim.tbl_extend('force', default_win_opts, {
        width = width,
        height = height,
        row = 1,  -- 在光标下方显示
        col = 0,
    })
    
    -- 创建窗口
    self:open()
    
    -- 设置按键映射
    self:setup_keymaps()
    
    return self
end
function TranslateWindow:open()
    self.winid = api.nvim_open_win(self.bufnr, true, self.win_opts)
    api.nvim_win_set_option(self.winid, 'wrap', true)
end

---设置按键映射
function TranslateWindow:setup_keymaps()
    local opts = {noremap = true, silent = true}
    api.nvim_buf_set_keymap(self.bufnr, 'n', 'q', ':q<CR>', opts)
    api.nvim_buf_set_keymap(self.bufnr, 'n', '<ESC>', ':q<CR>', opts)
end

---检查窗口是否有效
---@return boolean
function TranslateWindow:is_valid()
    return self.winid and api.nvim_win_is_valid(self.winid)
end

---关闭窗口
function TranslateWindow:close()
    if self:is_valid() then
        api.nvim_win_close(self.winid, true)
    end
end

-- 修改翻译函数
function M.translate()
    -- 如果存在旧窗口，先关闭它
    if current_window and current_window:is_valid() then
        current_window:close()
    end

    local text = get_visual_selection()
    
    -- 去除首尾空格后检查是否包含内部空格（多个单词）
    local trimmed_text = text:match("^%s*(.-)%s*$")  -- 去除首尾空格
    local cmd = { translate_cmd }
    if trimmed_text:find("%s+") then  -- 检查是否包含内部空格
        table.insert(cmd, "-t")
    end
    table.insert(cmd, text)

    -- vim.notify(vim.inspect(cmd))
    
    vim.system(
        cmd,
        { text = true },
        function(obj)
            if obj.code == 0 then
                vim.schedule(function()
                    -- 创建新窗口并保存引用
                    current_window = TranslateWindow.new(obj.stdout)
                end)
            else
                vim.schedule(function()
                    vim.notify("翻译失败: " .. (obj.stderr or "未知错误"), vim.log.levels.ERROR)
                    -- 确保错误时也清除旧窗口引用
                    current_window = nil
                end)
            end
        end
    )
end

-- 设置函数
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end


return M
