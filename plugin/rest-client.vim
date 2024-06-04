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
    let l:method = split(l:lines[0], ' ')[0]
    if index(l:methods, l:method) == -1
        echo 'Invalid HTTP method'
        return
    endif

    let l:path = split(l:lines[0], ' ')[1]

    let l:protocol = 'HTTP/1.1'
    if len(split(l:lines[0], ' ')) > 2
        let l:protocol = split(l:lines[0], ' ')[2]
    endif

    let l:headers = []
    let l:i = 1
    while l:i < len(l:lines) && l:lines[l:i] != ''
        call add(l:headers, l:lines[l:i])
        let l:i += 1
    endwhile

    let l:body_lines = filter(l:lines[l:i:], 'v:val != ""')
    let l:body = join(l:body_lines, "\n")

    let l:is_file = 0
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
    let l:env_vars = get(l:env_dict, a:env_name, {})

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
