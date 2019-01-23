local cjson = require('cjson')

local block_history = ngx.shared.health_check

local heights_json_rpc = cjson.encode({
  id = 0,
  jsonrpc = '2.0',
  method = 'heights',
})

local function get_heights()
  ngx.req.read_body()

  local options = {
    body = heights_json_rpc,
    method = ngx.HTTP_POST,
  }

  return ngx.location.capture('/factomd', options)
end

local function is_status_ok(status)
  return status >= 200 and status < 300
end

local function send_response(payload, status)
  local json_payload = cjson.encode(payload)
  ngx.status = status
  ngx.header['Content-Length'] = string.len(json_payload)
  ngx.print(json_payload)
end

local function get_block_history()
  local block = block_history:get('block')
  local timestamp = block_history:get('timestamp')

  return block, timestamp
end

local function save_block_history(block)
  block_history:set('block', block)
  block_history:set('timestamp', os.time())
end

local function go(config)
  local res = get_heights()

  if is_status_ok(res.status) then
    local heights = cjson.decode(res.body).result
    local directory_block_height = heights['directoryblockheight']
    local entry_height = heights['entryheight']
    local entry_block_height = heights['entryblockheight']
    local leader_height = heights['leaderheight']
    local block_from_history, timestamp_from_history = get_block_history()
    local max_block_age = config.max_block_age
    local current_timestamp = os.time()
    local block_age = timestamp_from_history and (current_timestamp - timestamp_from_history) or 0

    local message
    local factomd_is_healthy = true

    -- If not synced...
    if entry_block_height < directory_block_height then
      message = 'Not synced'
      factomd_is_healthy = false

    -- If no block history...
    elseif not block_from_history then
      save_block_history(leader_height)
      message='First block'

    -- If block is new...
    elseif leader_height > block_from_history then
      save_block_history(leader_height)
      message='New block'

    -- If block hasn't expired...
    elseif block_age <= max_block_age then
      message='Valid block'

    -- If block has expired...
    elseif block_age > max_block_age then
      message='Expired block'
      factomd_is_healthy = false

    -- Should never get here...
    else
      message='Unknown state'
    end

    local status = factomd_is_healthy and ngx.HTTP_OK or ngx.HTTP_SERVICE_UNAVAILABLE

    send_response({
      message=message,
      server_status=res.status,
      directory_block_height=directory_block_height,
      entry_height=entry_height,
      entry_block_height=entry_block_height,
      leader_height=leader_height,
      block_age=block_age,
      max_block_age=max_block_age,
    }, status)

  else
    send_response({
      message='Server error',
      server_status=res.status,
      details=res.body,
    }, ngx.HTTP_SERVICE_UNAVAILABLE)
  end
end

return {
  go = go,
}