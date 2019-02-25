local limit_req = require("resty.limit.req")
local limit_count = require("resty.limit.count")
local limit_traffic = require("resty.limit.traffic")

local codes = require('json_rpc_codes')
local shared = require('shared')
local set_response_error = shared.set_response_error

local limiters
local keys = {"req", "count"}
local write_methods = {}

local burst_writes_per_second, max_writes_per_second, max_writes_per_block, block_duration

local function init(config)
  ngx.shared.rate_limit_store:flush_all()

  burst_writes_per_second = config.burst_writes_per_second
  max_writes_per_second = config.max_writes_per_second
  max_writes_per_block = config.max_writes_per_block
  block_duration = config.block_duration

  for _, method in ipairs(config.write_methods) do
    write_methods[method] = true
  end

  local req_limiter, err =
    limit_req.new("rate_limit_store", max_writes_per_second, burst_writes_per_second - max_writes_per_second)

  assert(req_limiter, err)

  local count_limiter, err =
    limit_count.new("rate_limit_store", max_writes_per_block, block_duration)

  assert(count_limiter, err)

  limiters = { req_limiter, count_limiter }
end

local function enforce_limits(request, response)
  local method = request.json_rpc.method

  if write_methods[method] then
    local states = {}

    local delay, err = limit_traffic.combine(limiters, keys, states)
    local block_time_remaining_raw = ngx.shared.rate_limit_store:ttl("count")
    local block_time_remaining = math.ceil(block_time_remaining_raw)
    local block_writes_remaining = math.max(ngx.shared.rate_limit_store:get("count"), -1)
    local block_reset = math.ceil(ngx.now() + block_time_remaining_raw)

    response.headers['X-RateLimit-BlockDuration'] = block_duration
    response.headers['X-RateLimit-MaxWritesPerBlock'] = max_writes_per_block
    response.headers['X-RateLimit-BlockWritesRemaining'] = block_writes_remaining
    response.headers['X-RateLimit-BlockResetTime'] = block_reset

    response.headers['X-RateLimit-MaxBurstWritesPerSecond'] = burst_writes_per_second
    response.headers['X-RateLimit-MaxWritesPerSecond'] = max_writes_per_second

    print("delay: ", delay, ", excess: ", states[1])

    if not delay then
      local message, status

      local data = {
        blockDuration = block_duration,
        blockQuota = max_writes_per_block,
        blockQuotaRemaining = block_writes_remaining,
        blockResetTime = block_reset,
        throttleRejectRate = burst_writes_per_second,
        throttleStartRate = max_writes_per_second,
      }

      if err == 'rejected' then
        status = ngx.HTTP_TOO_MANY_REQUESTS
        if block_writes_remaining == -1 then
          message = 'Block write quota exceeded'
          response.headers['Retry-After'] = block_time_remaining
        else
          message = 'Max writes per second exceeded'
          response.headers['Retry-After'] = math.ceil(burst_writes_per_second / max_writes_per_second)
        end

      else
        message = err
        status = ngx.HTTP_SERVICE_UNAVAILABLE
      end

      set_response_error{response=response, code=codes.RATE_LIMIT_ERROR, data=data, message=message, status=status}

    elseif delay > 0.001 then
      response.headers['X-RateLimit-WriteDelay'] = delay
      response.headers['X-RateLimit-WritesPerSecond'] = max_writes_per_second + states[1]
      ngx.sleep(delay)
    end
  end
end

return {
  init = init,
  enforce_limits = enforce_limits,
}