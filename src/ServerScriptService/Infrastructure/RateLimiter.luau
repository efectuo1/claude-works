--!strict
--[[
	Limitador de peticiones por ventana fija. Clave = userId.
	El reloj se inyecta para poder testearlo sin esperar.
]]

export type RateLimiter = {
	allow: (key: number) -> boolean,
	forget: (key: number) -> (),
}

type Bucket = { count: number, windowStart: number }

local RateLimiter = {}

function RateLimiter.new(maxPerWindow: number, windowSeconds: number, now: () -> number): RateLimiter
	local buckets: { [number]: Bucket } = {}

	local limiter = {}

	function limiter.allow(key: number): boolean
		local currentTime = now()
		local bucket = buckets[key]
		if bucket == nil or currentTime - bucket.windowStart >= windowSeconds then
			buckets[key] = { count = 1, windowStart = currentTime }
			return true
		end
		if bucket.count >= maxPerWindow then
			return false
		end
		bucket.count += 1
		return true
	end

	function limiter.forget(key: number)
		buckets[key] = nil
	end

	return limiter
end

return RateLimiter
