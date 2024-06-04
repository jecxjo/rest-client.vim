# rest-client.vim
A vim port of the VSCode Rest Client.

With a simple `*.http` or `*.rest` file in your project you can trigger API
requests and view the responses directly in vim.

## Installation
Use your favorite plugin manager to install.

```vim
" vim-plug
Plug 'jecxjo/rest-client.vim'
```

Or install it manually:

**Vim 8**:
```sh
mkdir -p ~/.vim/pack/jecxjo/start
cd ~/.vim/pack/jecxjo/start
git clone https://github.com/jecxjo/rest-client.vim.git
vim -u NONE -c "helptags rest-client.vim/doc" -c q
```

**Neovim**:
```sh
mkdir -p ~/.config/nvim/pack/jecxjo/start
cd ~/.config/nvim/pack/jecxjo/start
git clone https://github.com/jecxjo/rest-client.vim.git
nvim -u NONE -c "helptags rest-client.vim/doc" -c q
```

Only dependencies are `curl` and `jq`.


## Current Features (compared to VSCode client)

- [X] Send Requests with all methods
- [ ] Configurable response output
- [X] JSON Parsing
- [X] Variables in API (local)
- [X] Config File Variables
- [X] Prompts
- [ ] API Specific config
- [ ] Cookie support
- [ ] Form support
- [ ] Multi-part data support
- [ ] Process variables / guid / dotenv / randomInt / timestamps
- [ ] Curl specific settings
- [ ] Certs support

## Usage

Create a simple text file containing your API requests.

```
# My API

###
# Hello World API
GET http://localhost:3000/hello?name=World

###
# Create User
POST http://localhost:3000/new-user
Content-Type: application/json

{
  "name": "Alice",
  "age": 30
}
```

Move your cursor to an API (between the `###` lines) and run `:RestClient`. If the output is JSON and you want it cleaned run `:RestClientJSON`.

### Local and Environment Variables

The plugin supports variables via the environment file `http-client.env.json`. The format is as follows:

```json
{
  "local": {
    "host": "http://localhost:3000"
  },
  "test": {
    "host": "https://uat.example.com"
  }
  "prod": {
    "host": "https://example.com"
  }
}
```

In the API file you can reference the variables wrapping them in double curly braces.

```
###
# Hello World
GET {{host}}/hello?name=World
```

To pick the environment to use run `:RestClient <env>` or `RestClientJSON <env>`. To see what environments are available and what variables exist run `:RestClientEnv`.

To use local variables start a line with `@` in or above the API block.

```
###
@host = http://localhost:3000
GET {{host}}/api
```


### API File format

The format is simple. Each API is between `###` or the end of file. Each API has the format:

```
METHOD URL
[<Header Name: Header Value>]

[<Body>]
```

Multiple headers can be added, one to each line.

The body for `POST` and `PUT` start after the first empty line after method/url and headers. If a file is being send the body should be `< filename`

```
###
# Upload File
POST {{host}}/Upload

< ./data.txt
```

### Highlighting

There is also a syntax file for the API files. To enable add the following to your RC file:

```vim
au BufRead,BufNewFile *.http,*.rest set filetype=http
```

## Acknowledgements

This plugin is inspirred by the [VSCode Rest Client](https://github.com/Huachao/vscode-restclient)

## License

BSD-3, see [LICENSE](LICENSE)

