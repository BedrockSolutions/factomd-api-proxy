local cjson = require('cjson')

local codes = require('json_rpc_codes')

local shared = require('shared')
local is_status_ok = shared.is_status_ok
local set_response_error = shared.set_response_error

local clock_spread_tolerance, max_block_age, name, version

local function init(config)
  clock_spread_tolerance = config.clock_spread_tolerance
  max_block_age = config.max_block_age
  name = config.name
  version = config.version
end

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

  return ngx.location.capture('/factomdApi', options)
end

local function factomd_cpanel_call()
  return ngx.location.capture('/factomdControlPanel')
end

local function nanoseconds_to_seconds(ns)
  return math.floor((ns / 1000000000) + 0.5)
end

local function get_response_data(res)
  return cjson.decode(res.body).result
end

local function create_data_object(heights_res, current_minute_res, properties_res, cpanel_res)
  local heights_data = get_response_data(heights_res)
  local current_minute_data = get_response_data(current_minute_res)
  local properties_data = get_response_data(properties_res)
  local cpanel_data = get_response_data(cpanel_res)

  local dblockLoadingHeight = cpanel_data[1].Height
  local leaderHeight = cpanel_data[2].Height
  local entryblockLoadingHeight = cpanel_data[3].Height
  local ignoreDone = not not(cpanel_data[4] and cpanel_data[4].IgnoreDone)

  local data = {
    isHealthy = false,
    clocks = {
      factomd = nanoseconds_to_seconds(current_minute_data.currenttime),
      proxy = os.time(),
      spreadTolerance = clock_spread_tolerance,
    },
    currentBlock = {
      maxAge = max_block_age,
      startTime = nanoseconds_to_seconds(current_minute_data.currentblockstarttime),
    },
    currentMinute = {
      minute = current_minute_data.minute,
      startTime = nanoseconds_to_seconds(current_minute_data.currentminutestarttime),
    },
    flags = {
      isIgnore = not ignoreDone,
      isSynced = entryblockLoadingHeight + 1 >= dblockLoadingHeight and entryblockLoadingHeight + 1 >= leaderHeight and ignoreDone,
    },
    heights = {
      directoryBlock = heights_data.directoryblockheight,
      entry = heights_data.entryheight,
      entryBlock = heights_data.entryblockheight,
      leader = heights_data.leaderheight,
    },
    system = {
      proxyName = name,
      proxyVersion = version,
      factomdVersion = properties_data.factomdversion,
      factomdApiVersion = properties_data.factomdapiversion,
    }
  }

  data.clocks.spread = math.abs(data.clocks.proxy - data.clocks.factomd)
  data.flags.isClockSpreadOk = data.clocks.spread <= data.clocks.spreadTolerance

  if data.flags.isSynced then
    data.currentBlock.age = data.clocks.proxy - data.currentBlock.startTime
    data.currentMinute.age = data.clocks.proxy - data.currentMinute.startTime
  end

  data.flags.isCurrentBlockAgeValid = data.flags.isSynced and data.currentBlock.age <= data.currentBlock.maxAge
  data.flags.isHealthy = data.flags.isSynced and data.flags.isClockSpreadOk and data.flags.isCurrentBlockAgeValid

  return data
end

local function perform_check(response)
  local heights_res = factomd_api_call('heights')

  if not is_status_ok(heights_res.status) then
    local data = { heightsResponse = heights_res }
    set_response_error{response=response, code=codes.HEALTH_CHECK_ERROR, data=data, message='Error getting heights', status=ngx.HTTP_SERVICE_UNAVAILABLE}
    return
  end

  local current_minute_res = factomd_api_call('current-minute')

  if not is_status_ok(current_minute_res.status) then
    local data = { heightsResponse = heights_res, currentMinuteResponse = current_minute_res }
    set_response_error{response=response, code=codes.HEALTH_CHECK_ERROR, data=data, message='Error getting current minute', status=ngx.HTTP_SERVICE_UNAVAILABLE}
    return
  end

  local properties_res = factomd_api_call('properties')

  if not is_status_ok(properties_res.status) then
    local data = { heightsResponse = heights_res, currentMinuteResponse = current_minute_res, propertiesResponse = properties_res }
    set_response_error{response=response, code=codes.HEALTH_CHECK_ERROR, data=data, message='Error getting properties', status=ngx.HTTP_SERVICE_UNAVAILABLE}
    return
  end

  local cpanel_res = factomd_cpanel_call()

  if not is_status_ok(cpanel_res.status) then
    local data = { heightsResponse = heights_res, currentMinuteResponse = current_minute_res, propertiesResponse = properties_res, cpanelResponse = cpanel_res }
    set_response_error{response=response, code=codes.HEALTH_CHECK_ERROR, data=data, message='Error getting control panel data', status=ngx.HTTP_SERVICE_UNAVAILABLE}
    return
  end

  local data = create_data_object(heights_res, current_minute_res, properties_res, cpanel_res)

  local message

  -- If the proxy and factomd clocks are too far apart...
  if not data.flags.isClockSpreadOk then
    message = 'Proxy and factomd clocks out of sync'

  -- If not synced...
  elseif not data.flags.isSynced then
    message = 'Not synced'

  -- If not following minutes...
  elseif not data.flags.isFollowingMinutes then
    message = 'Not following minutes'

  -- If the block is too old...
  elseif not data.flags.isCurrentBlockAgeValid then
    message='Block expired'

  -- If we get here, health check passed...
  else
    message='Health check succeeded'
  end

  if data.isHealthy then
    response.status = ngx.HTTP_OK
    response.json_rpc.result = {
      data = data,
      message = message,
    }
  else
    response.status = ngx.HTTP_SERVICE_UNAVAILABLE
    response.json_rpc.error = {
      code = codes.HEALTH_CHECK_ERROR,
      data = data,
      message = message,
    }
  end
end

return {
  init = init,
  perform_check = perform_check,
}