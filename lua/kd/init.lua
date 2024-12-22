local M = {}
local api = vim.api
local fn = vim.fn

-- 默认配置
M.config = {
    -- 翻译命令配置
    window = {
        width = 80,        -- 最大宽度
        height = 10,       -- 最大高度
        border = 'rounded', -- 边框样式
        title = ' 翻译结果 ', -- 标题
        title_pos = 'center', -- 标题位置
        style = 'minimal',    -- 窗口样式
        relative = 'cursor',  -- 窗口位置相对于光标
        focusable = true,    -- 是否可以获得焦点
        row = 1,             -- 相对于光标的垂直偏移
        col = 0,             -- 相对于光标的水平偏移
    },
    -- 添加高亮组配置
    highlights = {
        word = {
            fg = "#FF0000",    -- 前景色
            -- bg = "#FFFFFF",    -- 背景色
            bold = false,       -- 是否粗体
            italic = false,    -- 是否斜体
            underline = true  -- 是否下划线
        },
        phonetic = {          -- 音标高亮
            fg = "#00FF00",
            bg = "NONE",
            bold = false,
            italic = true,
            underline = false
        },
        -- 可以添加更多高亮组...
    }
}
local translate_cmd = "kd"

-- 添加一个全局变量来跟踪当前的翻译窗口
local current_window = nil

-- 获取选中的文本
local function get_visual_selection()
    -- 获取可视模式类型
    -- 获取选区的起始和结束位置
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local start_row, start_col = start_pos[2], start_pos[3]
    local end_row, end_col = end_pos[2], end_pos[3]

    -- 检查是否跨行
    if start_row == end_row then
        -- 单行选区：提取范围内的文本
        local line = vim.api.nvim_get_current_line()
        return line:sub(start_col, end_col)
    else
        -- 多行选区：提取范围内的多行文本
        local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)

        -- 处理第一行和最后一行的边界
        lines[1] = lines[1]:sub(start_col)
        lines[#lines] = lines[#lines]:sub(1, end_col)

        -- 拼接为字符串（多行间添加换行符）
        return table.concat(lines, "\n")
    end
end

-- 将 set_highlights 定义为 M 的方法
function M.set_highlights()
    local highlights = M.config.highlights

    -- 设置单词高亮
    if highlights.word then
        local word_hl = "highlight kdWord"
        if highlights.word.fg then word_hl = word_hl .. " guifg=" .. highlights.word.fg end
        if highlights.word.bg then word_hl = word_hl .. " guibg=" .. highlights.word.bg end

        local gui = {}
        if highlights.word.bold then table.insert(gui, "bold") end
        if highlights.word.italic then table.insert(gui, "italic") end
        if highlights.word.underline then table.insert(gui, "underline") end

        if #gui > 0 then
            word_hl = word_hl .. " gui=" .. table.concat(gui, ",")
        end

        vim.cmd(word_hl)
    end

    -- 设置音标高亮
    if highlights.phonetic then
        local phonetic_hl = "highlight kdPhonetic"
        if highlights.phonetic.fg then phonetic_hl = phonetic_hl .. " guifg=" .. highlights.phonetic.fg end
        if highlights.phonetic.bg then phonetic_hl = phonetic_hl .. " guibg=" .. highlights.phonetic.bg end

        local gui = {}
        if highlights.phonetic.bold then table.insert(gui, "bold") end
        if highlights.phonetic.italic then table.insert(gui, "italic") end
        if highlights.phonetic.underline then table.insert(gui, "underline") end

        if #gui > 0 then
            phonetic_hl = phonetic_hl .. " gui=" .. table.concat(gui, ",")
        end

        vim.cmd(phonetic_hl)
    end
end

---@class TranslateWindow
local TranslateWindow = {}
TranslateWindow.__index = TranslateWindow

---创建新的翻译窗口
---@param text string 要显示的文本内容
---@return TranslateWindow
function TranslateWindow.new(text)
    local self = setmetatable({}, TranslateWindow)

    -- 创建缓冲区
    self.bufnr = api.nvim_create_buf(false, true)
    -- 过滤掉包含特定关键字的行
    local lines = vim.split(text, '\n')
    local filtered_lines = {}
    for _, line in ipairs(lines) do
        if not line:find("未找到守护进程") and not line:find("成功启动守护进程") then
            table.insert(filtered_lines, line)
        end
    end
    api.nvim_buf_set_lines(self.bufnr, 0, -1, false, filtered_lines)

    -- 设置缓冲区选项
    api.nvim_buf_set_option(self.bufnr, 'modifiable', false)
    api.nvim_buf_set_option(self.bufnr, 'filetype', 'kd')  -- 这会自动加载我们的语法文件

    -- 确保语法高亮开启并应用自定义高亮
    vim.api.nvim_buf_call(self.bufnr, function()
        vim.cmd('syntax enable')
        M.set_highlights()  -- 使用 M.set_highlights
    end)

    -- 计算窗口尺寸
    local width = math.min(M.config.window.width, vim.o.columns - 4)
    local height = math.min(M.config.window.height, vim.o.lines - 4)

    -- 设置窗口配置
    self.win_opts = vim.tbl_extend('force', M.config.window, {
        width = width,
        height = height,
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
    -- 确保窗口中启用语法高亮
    vim.api.nvim_win_call(self.winid, function()
        vim.cmd('syntax enable')
    end)
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
function M.translate(mode)
    -- 如果存在旧窗口，先关闭它
    if current_window and current_window:is_valid() then
        current_window:close()
    end

    local text = ""

    if mode ~= 'v' and mode ~= 'V' and mode ~= '\x16' then
        text = vim.fn.expand('<cword>')  -- 如果不在可视模式，返回光标下的词
    else
        text = get_visual_selection()
    end

    -- 去除首尾空格后检查是否包含内部空格（多个单词）
    local trimmed_text = text:match("^%s*(.-)%s*$")  -- 去除首尾空格
    local cmd = { translate_cmd }
    -- 检查是否包含中文字符或内部空格
    if trimmed_text:find("[\xE4-\xE9][\x80-\xBF][\x80-\xBF]") or trimmed_text:find("%s+") then
        print("here")
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

-- 修改 setup 函数
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    -- 初始设置高亮
    M.set_highlights()
end


return M
