local cjson = require('cjson')

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

local function nanoseconds_to_seconds(ns)
  return math.floor((ns / 1000000000) + 0.5)
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

local function get_response_data(res)
  return cjson.decode(res.body).result
end

local function create_data_object(arg)
  local heights_data = get_response_data(arg.heights_res)
  local current_minute_data = get_response_data(arg.current_minute_res)

  local data = {
    clocks = {
      factomd = nanoseconds_to_seconds(current_minute_data.currenttime),
      proxy = os.time(),
      spread_tolerance = arg.config.clock_spread_tolerance,
    },
    current_block = {
      max_age = arg.config.max_block_age,
      start_time = nanoseconds_to_seconds(current_minute_data.currentblockstarttime),
    },
    current_minute = {
      minute = current_minute_data.minute,
      start_time = nanoseconds_to_seconds(current_minute_data.currentminutestarttime),
    },
    flags = {},
    heights = {
      directory_block = heights_data.directoryblockheight,
      entry = heights_data.entryheight,
      entry_block = heights_data.entryblockheight,
      leader = heights_data.leaderheight,
    },
  }

  data.flags.is_synced = data.heights.leader <= data.heights.directory_block + 1 and data.heights.leader <= data.heights.entry + 1

  data.clocks.spread = math.abs(data.clocks.proxy - data.clocks.factomd)
  data.flags.is_clock_spread_ok = data.clocks.spread <= data.clocks.spread_tolerance

  if data.flags.is_synced then
    data.current_block.age = data.clocks.proxy - data.current_block.start_time
    data.flags.is_current_block_valid = data.current_block.age <= data.current_block.max_age
    data.flags.is_following_minutes = data.current_minute.start_time > 0

    if data.flags.is_following_minutes then
      data.current_minute.age = data.clocks.proxy - data.current_minute.start_time
    end
  end

  return data
end

local function go(config)
  local heights_res = factomd_api_call('heights')

  if not is_status_ok(heights_res.status) then
    send_response({
      message = 'Error getting heights',
      raw_responses = {
        heights = heights_res,
      }
    }, ngx.HTTP_SERVICE_UNAVAILABLE)

    return
  end

  local current_minute_res = factomd_api_call('current-minute')

  if not is_status_ok(current_minute_res.status) then
    send_response({
      message = 'Error getting current minute',
      raw_responses = {
        heights = heights_res,
        current_minute = current_minute_res,
      }
    }, ngx.HTTP_SERVICE_UNAVAILABLE)

    return
  end

  local data = create_data_object{heights_res=heights_res, current_minute_res=current_minute_res, config=config}

  local message
  local factomd_is_healthy = false

  -- If the proxy and factomd clocks are too far apart...
  if not data.flags.is_clock_spread_ok then
    message = 'Proxy and factomd clocks out of sync'

  -- If not synced...
  elseif not data.flags.is_synced then
    message = 'Not synced'

  -- If not following minutes...
  elseif not data.flags.is_following_minutes then
    message = 'Not following minutes'

  -- If the block is too old...
  elseif not data.flags.is_current_block_valid then
    message='Block expired'

  -- If we get here, health check passed...
  else
    message='Health check succeeded'
    factomd_is_healthy = true
  end

  local status = factomd_is_healthy and ngx.HTTP_OK or ngx.HTTP_SERVICE_UNAVAILABLE

  local response = {
    message = message,
    data = data,
  }

  send_response(response, status)
end

return {
  go = go,
}
