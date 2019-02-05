local codes = require('json_rpc_codes')
local ip_utils = require("ip_utils")
local set_response_error = require('shared').set_response_error

local whitelist

local function init_whitelist(whitelist_ips)
  ip_utils.enable_lrucache()
  whitelist = ip_utils.parse_cidrs(whitelist_ips)
end

local function check_access(request, response)
  local is_access_allowed = ip_utils.ip_in_cidrs(request.client_ip, whitelist)

  if not is_access_allowed then
    local data = { clientIp = request.client_ip }
    set_response_error{response=response, code=codes.ACCESS_CONTROL_ERROR, data=data, message='Access Denied', status=ngx.HTTP_FORBIDDEN}
  end
end

return {
  init_whitelist = init_whitelist,
  check_access = check_access,
}
