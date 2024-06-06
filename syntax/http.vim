" Vim syntax file
" Language:     HTTP
" Maintainer:   Jeff Parent <jeff@sh0.xyz>
" Filenames:    *.http

if exists("b:current_syntax")
    finish
endif

" Comments
syntax match httpComment "#.*$"

" HTTP methods
syntax keyword httpMethod GET POST PUT DELETE PATCH HEAD OPTIONS CONNECT TRACE

" URLs
syntax match httpUrl "\vhttps\?://(\S+|\s*[?&]\S+)+"

" Headers
syntax match httpHeader "^\s*\zs[^:]\+\ze:"

" JSON payloads
syntax region jsonPayload start=/^\s*{$/ end=/^\s*}$/ contains=jsonString,jsonNumber,jsonBoolean,jsonNull,jsonBraces,jsonComma,jsonColon
syntax match jsonString /"\zs[^"]\+\ze"/
syntax match jsonNumber /\d\+\(\.\d\+\)\?/
syntax match jsonBoolean /true\|false/
syntax match jsonNull /null/
syntax match jsonBraces /[{}]/
syntax match jsonComma /,/
syntax match jsonColon /:/

" Link everything
hi def link httpComment Comment
hi def link httpMethod Statement
hi def link httpUrl String
hi def link httpHeader Identifier
hi def link jsonString String
hi def link jsonNumber Number
hi def link jsonBoolean Boolean
hi def link jsonNull Constant
hi def link jsonBraces Delimiter
hi def link jsonComma Delimiter
hi def link jsonColon Delimiter

let b:current_syntax = "http"
