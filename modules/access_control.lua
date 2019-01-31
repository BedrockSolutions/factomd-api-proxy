local ip_utils = require("ip_utils")

local whitelist

local function init_whitelist(whitelist_ips)
  ngx.log(ngx.NOTICE, 'in access_control init_whitelist')
  ip_utils.enable_lrucache()
  whitelist = ip_utils.parse_cidrs(whitelist_ips)
end

local function is_access_allowed()
  ngx.log(ngx.NOTICE, 'in check access')
  return ip_utils.ip_in_cidrs(ngx.var.remote_addr, whitelist)
end

return {
  init_whitelist = init_whitelist,
  is_access_allowed = is_access_allowed,
}
