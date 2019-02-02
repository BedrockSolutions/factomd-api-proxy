local function go(request, response)
  local options = {
    body = request.body,
    method = ngx.HTTP_POST,
  }

  local api_response = ngx.location.capture('/factomd', options)

  response.status = api_response.status
  response.raw_body = api_response.body
end

return {
  go = go,
}
