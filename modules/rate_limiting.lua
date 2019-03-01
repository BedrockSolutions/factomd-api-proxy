local limit_req = require("resty.limit.req")
local limit_count = require("resty.limit.count")
local limit_traffic = require("resty.limit.traffic")

local codes = require('json_rpc_codes')
local shared = require('shared')
local set_response_error = shared.set_response_error

local req_limiter, count_limiter
local write_methods = {}
local max_burst_writes_per_second, max_writes_per_second, max_writes_per_block, block_duration

local function init(config)
  require("resty.core")

  ngx.shared.rate_limit_store:flush_all()

  max_burst_writes_per_second = config.max_burst_writes_per_second
  max_writes_per_second = config.max_writes_per_second
  max_writes_per_block = config.max_writes_per_block
  block_duration = config.block_duration

  for _, method in ipairs(config.write_methods) do
    write_methods[method] = true
  end

  req_limiter, err =
    limit_req.new('rate_limit_store', max_writes_per_second, max_burst_writes_per_second - max_writes_per_second)

  assert(req_limiter, err)

  count_limiter, err =
    limit_count.new('rate_limit_store', max_writes_per_block, block_duration)

  assert(count_limiter, err)
end

local function get_block_time_remaining()
  return ngx.shared.rate_limit_store:ttl('count')
end

local function get_block_writes_remaining()
  return math.max(ngx.shared.rate_limit_store:get('count'), 0)
end

local function get_block_reset_time()
  return math.ceil(ngx.now() + get_block_time_remaining())
end

local function block_headers(response, delay, err_or_remaining)
  response.headers['X-RateLimit-BlockDuration'] = block_duration
  response.headers['X-RateLimit-BlockResetTime'] = get_block_reset_time()
  response.headers['X-RateLimit-BlockWritesRemaining'] = get_block_writes_remaining()
  response.headers['X-RateLimit-MaxWritesPerBlock'] = max_writes_per_block

  if not delay and err_or_remaining == 'rejected' then
    response.headers['Retry-After'] = math.ceil(get_block_time_remaining())
  end
end

local function writes_per_second_headers(response, delay, err_or_excess)
  response.headers['X-RateLimit-MaxBurstWritesPerSecond'] = max_burst_writes_per_second
  response.headers['X-RateLimit-MaxWritesPerSecond'] = max_writes_per_second

  if not delay and err_or_excess == 'rejected' then
    response.headers['Retry-After'] = math.ceil(max_burst_writes_per_second / max_writes_per_second)
  end

  if delay and delay > 0.001 then
      response.headers['X-RateLimit-WriteDelay'] = delay
      response.headers['X-RateLimit-WritesPerSecond'] = max_writes_per_second + err_or_excess
  end
end

local function error_data(req_delay, req_err_or_excess, count_delay, count_err_or_remaining)
  local data = {
    blockDuration = block_duration,
    blockResetTime = get_block_reset_time(),
    blockTimeRemaining = math.ceil(get_block_time_remaining()),
    blockWritesRemaining = get_block_writes_remaining(),
    maxBurstWritesPerSecond = max_burst_writes_per_second,
    maxWritesPerBlock = max_writes_per_block,
    maxWritesPerSecond = max_writes_per_second,
  }

  if req_delay and req_delay > 0.001 then
    data.writeDelay = req_delay
    data.writesPerSecond = max_writes_per_second + req_err_or_excess
  end

  return data
end

local function enforce_limits(request, response)
  local method = request.json_rpc.method

  if write_methods[method] then
    local req_delay, req_err = req_limiter:incoming("req", true)
    writes_per_second_headers(response, req_delay, req_err)

    local count_delay, count_err
    if req_delay then
      count_delay, count_err = count_limiter:incoming("count", true)
    end
    block_headers(response, count_delay, count_err)

    if not (req_delay and count_delay) then
      local message
      if not req_delay then
        if req_err == 'rejected' then
          message = 'Max writes per second exceeded'
        else
          message = req_err
        end
      else
        if count_err == 'rejected' then
          message = 'Block write quota exceeded'
        else
          message = count_err
        end
      end

      local status
      if req_err == 'rejected' or count_err == 'rejected' then
        status = ngx.HTTP_TOO_MANY_REQUESTS
      else
        status = ngx.HTTP_SERVICE_UNAVAILABLE
      end

      local data = error_data(req_delay, req_err, count_delay, count_err)
      set_response_error{response=response, code=codes.RATE_LIMIT_ERROR, data=data, message=message, status=status }

    elseif req_delay > 0.001 then
      ngx.sleep(req_delay)
    end
  end
end

return {
  init = init,
  enforce_limits = enforce_limits,
}