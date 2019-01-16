local finish_request = require('shared').finish_request
local cors = require('cors')

local function init(config)
  cors.init(config)
end

local function go()
  local method = ngx.req.get_method()
  local uri = ngx.var.uri

  ngx.log(ngx.ERR, string.format('Method: %s, URI: %s', method, uri))

  if uri == '/' and method == 'GET'
  then
    ngx.exit(ngx.HTTP_OK)

  elseif uri == '/v2' and method == 'OPTIONS'
  then
    cors.go()
    ngx.exit(ngx.HTTP_OK)

  elseif uri == '/v2' and method == 'POST'
  then
    cors.go()

  else
    ngx.exit(ngx.HTTP_NOT_FOUND)
  end
end

return {
  init = init,
  go = go,
}