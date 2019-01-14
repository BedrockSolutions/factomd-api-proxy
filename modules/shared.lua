local function finish_request(status, message, ...)
  ngx.status = status
  ngx.say(string.format(message, ...))
  ngx.exit(status)
end

return {
  finish_request = finish_request,
}