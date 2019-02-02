local cjson = require('cjson')

local function get_header(name)
  return ngx.req.get_headers()[name]
end

local function get_json_rpc_request()
  ngx.req.read_body()
  local req_body = ngx.req.get_body_data()

  return cjson.decode(req_body) or {}
end

local function is_status_ok(status)
  return status >= 200 and status < 300
end

local function is_response_error(response)
  return response.json_rpc.error ~= nil
end

local function set_response_error(arg)
  arg.response.status = arg.status or ngx.HTTP_BAD_REQUEST
  arg.response.json_rpc.error = {
    code = arg.code,
    data = arg.data,
    message = arg.message
  }
end

local function set_response_message(arg)
  if not is_response_error(arg.response) then
    arg.response.status = ngx.HTTP_OK
    arg.response.json_rpc.result = {
      data = arg.data,
      message = arg.message
    }
  end
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

return {
  dump = dump,
  get_header = get_header,
  get_json_rpc_request = get_json_rpc_request,
  is_response_error = is_response_error,
  is_status_ok = is_status_ok,
  set_response_error = set_response_error,
  set_response_message = set_response_message
}