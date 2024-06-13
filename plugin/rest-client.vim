let s:last_run = {}

function! s:ProcessAuthorizationHeader(headers)
    let l:headers_dict = {}
    let l:auth_type = 'None'
    let l:username = ''
    let l:password = ''

    for l:header in a:headers
        let l:parts = split(l:header, ':')
        let l:key = trim(l:parts[0])
        let l:value = trim(join(l:parts[1:], ':'))
        let l:headers_dict[l:key] = l:value
    endfor

    if has_key(l:headers_dict, 'Authorization')
        let l:auth = l:headers_dict['Authorization']
        if l:auth =~ '^Basic '
            unlet l:headers_dict['Authorization']
            let l:auth_type = 'Basic'
            let l:credentials = split(substitute(l:auth, '^Basic ', '', ''), ' ')
            if len(l:credentials) == 2
                let l:username = l:credentials[0]
                let l:password = l:credentials[1]
            elseif len(l:credentials) == 1 && l:credentials[0] =~ ':'
                let l:credentials = split(l:credentials[0], ':')
                let l:username = l:credentials[0]
                let l:password = l:credentials[1]
            elseif len(l:credentials) == 1
                let l:cred_string = system('echo -n ' . l:credentials[0] . ' | base64 -d')
                let l:credentials = split(l:cred_string, ':')
                let l:username = l:credentials[0]
                let l:password = l:credentials[1]
            endif
        elseif l:auth =~ '^Digest '
            unlet l:headers_dict['Authorization']
            let l:auth_type = 'Digest'
            let l:credentials = split(substitute(l:auth, '^Digest ', '', ''), ' ')
            if len(l:credentials) == 2
                let l:username = l:credentials[0]
                let l:password = l:credentials[1]
            else
                echo 'Error: Invalid Digest Authorization header'
                return {}
            endif
        endif
    endif

    let l:headers = []
    for [l:key, l:value] in items(l:headers_dict)
        call add(l:headers, l:key . ': ' . l:value)
    endfor

    return [l:headers, l:auth_type, l:username, l:password]
endfunction

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
            let l:path = join(l:parts[1:])
            let l:i += 1
            break
        endif
        let l:i += 1
    endwhile

    " Append query parameters to path
    while l:i < len(l:lines) && (l:lines[l:i] =~ '^\s*[?&]')
        let l:path .= trim(l:lines[l:i])
        let l:i += 1
    endwhile

    " Check if path has two parts (path and protocol)
    let l:path_parts = split(l:path, ' ')
    if len(l:path_parts) == 2
        let l:path = l:path_parts[0]
        let l:protocol = l:path_parts[1]
    endif

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

    let l:body = join(l:lines[l:i+1:], "\n")

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

function! s:ParseUrlencodedBody(body)
    let l:body = join(split(a:body, "\n"), "&")
    let l:form_data = {}
    let l:parts = split(l:body, '&')
    for l:part in l:parts
        let l:pair = split(l:part, '=')
        if len(l:pair) == 2
            let l:key = l:pair[0]
            let l:value = l:pair[1]
            let l:form_data[l:key] = l:value
        endif
    endfor
    return l:form_data
endfunction

function! s:ParseMultipartBody(body, boundary)
    let l:parts = split(a:body, '\V' . '--' . a:boundary . '\(--\)\?', '')
    let l:multipart_data = []
    for l:part in l:parts
        let l:lines = split(l:part, "\n")
        let l:found = 0
        let l:headers = []
        let l:content = ''
        let l:is_file = 0
        let l:filename = ''
        let l:file_path = ''
        let l:name = ''
        for l:line in l:lines
            if l:line =~ 'Content-Disposition: form-data;'
                let l:headers = split(l:line, ';')
                for l:header in l:headers
                    if l:header =~ 'filename='
                        let l:found = 1
                        let l:is_file = 1
                        let l:filename = matchstr(l:header, 'filename=".*"')
                        let l:filename = substitute(l:filename, 'filename=', '', '')
                        let l:filename = substitute(l:filename, '"', '', 'g')
                    elseif l:header =~ 'name='
                        let l:found = 1
                        let l:name = matchstr(l:header, 'name=".*"')
                        let l:name = substitute(l:name, 'name=', '', '')
                        let l:name = substitute(l:name, '"', '', 'g')
                    endif
                endfor
            elseif l:line =~ '^<'
                let l:found = 1
                let l:file_path = substitute(l:line, '^<', '', '')
            else
                let l:content .= l:line
            endif
        endfor
        if l:found == 1
            let l:multipart_data += [{'name': l:name, 'headers': l:headers, 'content': l:content, 'is_file': l:is_file, 'filename': l:filename, 'file_path': l:file_path}]
        endif
    endfor
    return l:multipart_data
endfunction

function! s:HttpRun(is_json, ...) abort
    let l:args = a:000
    let l:env_name = ''
    let l:show_headers = '-i'

    for l:arg in l:args
        if l:arg == '-h'
            let l:show_headers = ''
        else
            let l:env_name = l:arg
        endif
    endfor

    let l:env_dict = s:LoadEnvFile()
    let l:local_vars = s:ExtractLocalVariables()
    let l:prompts = s:ScanForPrompts()

    let l:env_vars = get(l:env_dict, l:env_name, {})
    let l:env_vars = extend(l:env_vars, l:local_vars)
    let l:env_vars = extend(l:env_vars, l:prompts)

    let l:res = s:ParseHttpRequest()
    let l:method = l:res['method']
    let l:path = s:ReplacePlaceholders(l:res['path'], l:env_vars)
    let l:headers = map(copy(l:res['headers']), {_, v -> s:ReplacePlaceholders(v, l:env_vars)})
    let l:header_info = s:ProcessAuthorizationHeader(l:headers)
    let l:headers = l:header_info[0]
    let l:auth_type = l:header_info[1]
    let l:username = l:header_info[2]
    let l:password = l:header_info[3]

    let l:body = s:ReplacePlaceholders(l:res['body'], l:env_vars)

    " Check if Content-Type is multipart/form-data
    let l:is_multipart = 0
    let l:boundary = ''
    for l:header in l:headers
        if l:header =~ 'Content-Type: multipart/form-data;'
            let l:is_multipart = 1
            let l:boundary = matchstr(l:header, 'boundary=.*')
            let l:boundary = substitute(l:boundary, 'boundary=', '', '')
            let l:headers = filter(l:headers, {_, v -> v != l:header})
            break
        endif
    endfor

    " Check if Content-Type is application/x-www-form-urlencoded
    let l:is_urlencoded = 0
    for l:header in l:headers
        if l:header =~ 'Content-Type: application/x-www-form-urlencoded'
            let l:is_urlencoded = 1
            break
        endif
    endfor

    " curl command generation
    let l:cmd = 'curl --http1.1 ' . l:show_headers . ' -s -X ' . l:method . ' "' . l:path . '"'
    if l:res['protocol'] == 'HTTP/2'
        let l:cmd = 'curl --http2 ' . l:show_headers . ' -s -X ' . l:method . ' "' . l:path . '"'
    endif
    if l:auth_type == 'Basic'
        let l:cmd .= ' -u ' . l:username . ':' . l:password
    endif
    if l:auth_type == 'Digest'
        let l:cmd .= ' --digest -u ' . l:username . ':' . l:password
    endif
    for l:header in l:headers
        let l:cmd .= ' -H "' . l:header . '"'
    endfor

    " Cookie support, default location is next to current file
    if !exists("g:rest_client_cookie_file")
        let g:rest_client_cookie_file = expand('%:p:h') . '/cookie.txt'
    endif
    let l:cmd .= ' -c ' . g:rest_client_cookie_file . ' -b ' . g:rest_client_cookie_file

    " If it is, parse the body and modify the curl command
    if l:is_multipart
        let l:cmd .= ' -H "Content-Type: multipart/form-data" '
        let l:multipart_data = s:ParseMultipartBody(l:body, l:boundary)
        for l:part in l:multipart_data
            if l:part['is_file']
                let l:cmd .= ' -F "' . l:part['name'] . '=@' . l:part['file_path'] . '"'
            else
                let l:cmd .= ' -F "' . l:part['name'] . '=' . l:part['content'] . '"'
            endif
        endfor
    elseif l:is_urlencoded
        let l:form_data = s:ParseUrlencodedBody(l:body)
        for [l:key, l:value] in items(l:form_data)
            let l:cmd .= ' -d ' . l:key . '=' . l:value
        endfor
    else
        if l:body != ''
            if l:res['is_file']
                let l:cmd .= " -d @" . l:body
            else
                let l:cmd .= " -d '" . l:body . "'"
            endif
        endif
    endif

    let s:last_run = {
                \ 'cmd': l:cmd,
                \ 'is_json': a:is_json
                \ }
    echo l:cmd
    let l:output = system(l:cmd . " | tr -d '\r'")
    enew
    put =l:output

    if a:is_json
        normal G
        ?^$
        .+1,$!jq .
        setlocal filetype=json
    endif

    setlocal nomodifiable
    setlocal buftype=nofile
endfunction

function! s:HttpReRun()
    if s:last_run == {}
        echo 'No previous request to run'
        return
    endif
    let l:cmd = s:last_run['cmd']
    let l:is_json = s:last_run['is_json']

    echo l:cmd
    let l:output = system(l:cmd . " | tr -d '\r'")
    enew
    put =l:output

    if l:is_json
        normal G
        .!jq .
        setlocal filetype=json
    endif

    setlocal nomodifiable
    setlocal buftype=nofile
endfunction

command! -nargs=* RestClient call s:HttpRun(0, <f-args>)
command! -nargs=* RestClientJSON call s:HttpRun(1, <f-args>)
command! -nargs=0 RestClientReRun call s:HttpReRun()

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
