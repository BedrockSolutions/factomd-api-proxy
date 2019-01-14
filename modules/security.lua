local finish_request = require("shared").finish_request

local function main(allow_origin)
  local method = ngx.req.get_method()

  if method ~= 'OPTIONS' and method ~= 'POST'
  then
    finish_request(ngx.HTTP_BAD_REQUEST, 'The HTTP method %q is not allowed', method)
  end
end

return {
  main = main,
}