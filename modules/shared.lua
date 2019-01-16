local function finish_request(status, message, ...)
  ngx.status = status
  ngx.say(string.format(message, ...))
  ngx.exit(status)
end

local function get_header(name)
  return ngx.req.get_headers()[name] or ''
end

return {
  finish_request = finish_request,
  get_header = get_header,
}