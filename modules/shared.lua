local cjson = require('cjson')

local function get_header(name)
  return ngx.req.get_headers()[name] or ''
end

local function get_json_rpc_request()
  ngx.req.read_body()
  local req_body = ngx.req.get_body_data()

  return cjson.decode(req_body) or {}
end

local function is_status_ok(status)
  return status >= 200 and status < 300
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
  is_status_ok = is_status_ok,
}