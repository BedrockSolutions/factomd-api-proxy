local function go(config, request)
  local options = {
    body = request.body,
    method = ngx.HTTP_POST,
  }

  local response = ngx.location.capture('/factomd', options)

  ngx.status = response.status
  ngx.header['Content-Length'] = response.header['Content-Length']
  ngx.print(response.body)
end

return {
  go = go,
}
