#!lua name=loomlib

local function revision_match_increment(keys, args)
  local counter_key = keys[1]
  local expected_revision = args[1]
  local current_counter = redis.call('GET', counter_key)


 local revision_match =
    (expected_revision == 'any') or
    (expected_revision == 'no_stream' and tonumber(current_counter) == 0) or
    (expected_revision == 'stream_exists' and tonumber(current_counter) > 0) or
    (expected_revision == current_counter)

  if revision_match then
    return redis.call('INCR', counter_key)
  else
    return 'MISMATCH'
  end
end

redis.register_function('revision_match_increment', revision_match_increment)
