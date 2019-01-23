local cjson = require('cjson')

local block_history = ngx.shared.health_check

local function factomd_api_call(method)
  local json_rpc = {
    id = 0,
    jsonrpc = '2.0',
    method = method,
  }

  local options = {
    body = cjson.encode(json_rpc),
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
  local heights_res = factomd_api_call('heights')

  if not is_status_ok(heights_res.status) then
    send_response({
      message='Error getting heights',
      server_status= heights_res.status,
      details= heights_res.body,
    }, ngx.HTTP_SERVICE_UNAVAILABLE)

    return
  end

  local current_minute_res = factomd_api_call('current-minute')

  if not is_status_ok(current_minute_res.status) then
    send_response({
      message='Error getting current minute',
      server_status= current_minute_res.status,
      details= current_minute_res.body,
    }, ngx.HTTP_SERVICE_UNAVAILABLE)

    return
  end

  local heights = cjson.decode(heights_res.body).result
  local directory_block_height = heights['directoryblockheight']
  local entry_height = heights['entryheight']
  local entry_block_height = heights['entryblockheight']
  local leader_height = heights['leaderheight']

  local current_minute = cjson.decode(current_minute_res.body).result.minute

  local block_from_history, timestamp_from_history = get_block_history()
  local max_block_age = config.max_block_age
  local current_timestamp = os.time()

  local message
  local factomd_is_healthy = true
  local block_age = 0

  -- If not synced...
  if entry_height < directory_block_height then
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
    block_age = current_timestamp - timestamp_from_history

  -- If block has expired...
  elseif block_age > max_block_age then
    message='Expired block'
    factomd_is_healthy = false
    block_age = current_timestamp - timestamp_from_history

  -- Should never get here...
  else
    message='Unknown state'
  end

  local status = factomd_is_healthy and ngx.HTTP_OK or ngx.HTTP_SERVICE_UNAVAILABLE

  send_response({
    message=message,
    server_status= heights_res.status,
    directory_block_height=directory_block_height,
    entry_height=entry_height,
    entry_block_height=entry_block_height,
    leader_height=leader_height,
    current_minute=current_minute,
    block_age=block_age,
    max_block_age=max_block_age,
  }, status)
end

return {
  go = go,
}
