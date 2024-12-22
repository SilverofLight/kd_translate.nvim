if exists("b:current_syntax")
    finish
endif

" 设置主要的语法规则
syntax match kdWord /\%1l[^    \[]\+/
syntax match kdPhonetic /\%1l\[.*\]/

" 不在这里设置高亮链接，让 Lua 代码来处理
" highlight default link kdWord Error
" highlight default link kdPhonetic Special
let b:current_syntax = "kd"
