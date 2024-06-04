function! s:ScanForPrompts()
    let l:prompts = {}
    let l:start = search('###', 'bnW')
    let l:end = search('###', 'nW')
    if l:end == 0
        let l:end = line('$')
    endif
    let l:lines = getline(l:start, l:end)
    for l:line in l:lines
        if l:line =~ '^# @'
            let l:parts = split(substitute(l:line, '^# @', '', ''), ' ')
            let l:settingName = l:parts[0]
            if l:settingName == 'prompt' && len(l:parts) > 2
                let l:varName = l:parts[1]
                let l:question = join(l:parts[2:], ' ')
                let l:prompts[l:varName] = input(l:question . ': ')
            endif
        endif
    endfor
    return l:prompts
endfunction

function! s:ExtractLocalVariables()
    let l:local_vars = {}
    let l:line_num = search('###', 'nW')
    if l:line_num == 0
        let l:line_num = line('$')
    else
        let l:line_num -= 1
    endif
    while l:line_num > 0
        let l:line = getline(l:line_num)
        if l:line =~ '^@\w\+ = .\+'
            let l:parts = split(l:line, ' = ')
            let l:var_name = substitute(l:parts[0], '^@', '', '')
            if has_key(l:local_vars, l:var_name) == 0
                let l:local_vars[l:var_name] = l:parts[1]
            endif
        endif
        let l:line_num -= 1
    endwhile
    return l:local_vars
endfunction

function! s:LoadEnvFile()
    let l:current_file_dir = expand('%:p:h')
    let l:env_file = findfile('http-client.env.json', l:current_file_dir . ';')
    if l:env_file == ''
        return {}
    endif
    let l:env_json = system('cat ' . l:env_file)
    let l:env_dict = json_decode(l:env_json)
    return l:env_dict
endfunction

function! s:ReplacePlaceholders(text, env_vars)
    let l:text = a:text
    for [l:key, l:value] in items(a:env_vars)
        if type(l:value) == type({})
            let l:value = string(l:value)
        endif
        let l:text = substitute(l:text, '{{' . l:key . '}}', l:value, 'g')
    endfor
    return l:text
endfunction

function! s:ExtractHttpRequest()
    let l:start = search('###', 'bnW')
    let l:end = search('###', 'nW')
    if l:end == 0
        let l:end = line('$')
    endif
    let l:lines = getline(l:start, l:end)
    let l:lines = filter(l:lines, 'v:val !~ "^#"')
    return l:lines
endfunction

function! s:ParseHttpRequest()
    let l:lines = s:ExtractHttpRequest()

    let l:methods =  ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS', 'CONNECT', 'TRACE']
    let l:method = ''
    let l:path = ''
    let l:protocol = 'HTTP/1.1'
    let l:headers = []
    let l:body = ''
    let l:is_file = 0
    let l:i = 0

    " Find the line that starts with a method
    while l:i < len(l:lines)
        if l:lines[l:i] =~ '^\s*$'
            let l:i += 1
            continue
        endif
        let l:parts = split(l:lines[l:i], ' ')
        if index(l:methods, l:parts[0]) != -1
            let l:method = l:parts[0]
            let l:path = l:parts[1]
            if len(l:parts) > 2
                let l:protocol = l:parts[2]
            endif
            let l:i += 1
            break
        endif
        let l:i += 1
    endwhile

    " If no valid method found, return an error
    if l:method == ''
        echo 'Invalid HTTP method'
        return
    endif

    " Continue with the rest of the function as before
    while l:i < len(l:lines) && l:lines[l:i] != ''
        call add(l:headers, l:lines[l:i])
        let l:i += 1
    endwhile

    let l:body_lines = filter(l:lines[l:i:], 'v:val != ""')
    let l:body = join(l:body_lines, "\n")

    if l:body =~ '^<'
        let l:is_file = 1
        let l:body = substitute(l:body, '^<', '', '')
    endif

    return {
                \ 'method': l:method,
                \ 'path': l:path,
                \ 'headers': l:headers,
                \ 'body': l:body,
                \ 'is_file': l:is_file,
                \ 'protocol': l:protocol
                \ }
endfunction

function! s:HttpRun(is_json, env_name)
    let l:env_dict = s:LoadEnvFile()
    let l:local_vars = s:ExtractLocalVariables()
    let l:prompts = s:ScanForPrompts()

    let l:env_vars = get(l:env_dict, a:env_name, {})
    let l:env_vars = extend(l:env_vars, l:local_vars)
    let l:env_vars = extend(l:env_vars, l:prompts)


    let l:res = s:ParseHttpRequest()
    let l:method = l:res['method']
    let l:path = s:ReplacePlaceholders(l:res['path'], l:env_vars)
    let l:headers = map(copy(l:res['headers']), {_, v -> s:ReplacePlaceholders(v, l:env_vars)})
    let l:body = s:ReplacePlaceholders(l:res['body'], l:env_vars)

    let l:cmd = 'curl --http1.1 -s -X ' . l:method . ' "' . l:path . '"'
    if l:res['protocol'] == 'HTTP/2'
        let l:cmd = 'curl --http2 -s -X ' . l:method . ' "' . l:path . '"'
    endif
    for l:header in l:headers
        let l:cmd .= ' -H "' . l:header . '"'
    endfor
    if l:body != ''
        if l:res['is_file']
            let l:cmd .= " -d @" . l:body
        else
            let l:cmd .= " -d '" . l:body . "'"
        endif
    endif

    if a:is_json
        let l:cmd .= ' | jq .'
    endif

    echo l:cmd
    let l:output = system(l:cmd)
    enew
    put =l:output
    setlocal nomodifiable
    setlocal buftype=nofile

    if a:is_json
        setlocal filetype=json
    endif
endfunction

command! -nargs=? RestClient call s:HttpRun(0, <q-args>)
command! -nargs=? RestClientJSON call s:HttpRun(1, <q-args>)

function! s:ReadEnvironments()
    let l:env_dict = s:LoadEnvFile()
    for [l:env_name, l:env_vars] in items(l:env_dict)
        echo 'Environment: ' . l:env_name
        for [l:var_name, l:var_value] in items(l:env_vars)
            echo '  ' . l:var_name . ': ' . l:var_value
        endfor
    endfor
endfunction

command! RestClientEnv call s:ReadEnvironments()
