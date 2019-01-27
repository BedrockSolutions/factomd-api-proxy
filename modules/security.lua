local get_json_rpc_request = require('shared').get_json_rpc_request

local function global_headers(ssl_enabled)
  ngx.header['Content-Security-Policy'] = "default-src 'none'"
  ngx.header['Content-Type'] = 'application/json; charset=utf-8'
  ngx.header['Referrer-Policy'] = 'same-origin'
  ngx.header['X-Content-Type-Options'] = 'nosniff'
  ngx.header['X-Frame-Options'] = 'SAMEORIGIN'
  ngx.header['X-XSS-Protection'] = '1; mode=block'

  if ssl_enabled then
    ngx.header['Strict-Transport-Security'] = 'max-age=63072000;'
  end
end

local function is_rpc_request_valid()
  local is_json_valid, result = pcall(get_json_rpc_request)

  if not is_json_valid then
    return false, result
  end

  if type(result) ~= 'table' then
    return false, string.format('Execpted RPC request to be a table. Got %s', tostring(result))

  elseif result.jsonrpc ~= '2.0' then
    return false, string.format('Expected jsonrpc field to be 2.0. Got %s', tostring(result.jsonrpc))

  elseif not result.id then
    return false, 'Expected id field to not be empty'

  elseif not result.method then
    return false, 'Expected method field to not be empty'

  else
    return true
  end
end

local function go(config, globals)
  local method = ngx.req.get_method()
  local uri = ngx.var.uri

  global_headers(config.ssl_enabled)

  if method == 'POST' and uri == '/v2' then
    local req_valid, error = is_rpc_request_valid()
    globals.is_rpc_request_valid = req_valid
    globals.rpc_request_validation_error = error
  end
end

return {
  go = go,
}