--!strict
--[[
	Señal tipada para eventos de dominio.
	Cada listener se ejecuta aislado: si uno falla, se registra y los demás siguen.
]]

export type Connection = { disconnect: () -> () }

export type Signal<T> = {
	connect: (listener: (payload: T) -> ()) -> Connection,
	fire: (payload: T) -> (),
}

local Signal = {}

function Signal.new<T>(): Signal<T>
	local listeners: { [number]: (payload: T) -> () } = {}
	local nextId = 0

	local signal = {}

	function signal.connect(listener: (payload: T) -> ()): Connection
		nextId += 1
		local id = nextId
		listeners[id] = listener
		return {
			disconnect = function()
				listeners[id] = nil
			end,
		}
	end

	function signal.fire(payload: T)
		-- Copia: un listener puede desconectarse o conectar otro durante el disparo.
		local snapshot = table.clone(listeners)
		for _, listener in snapshot do
			local ok, err = pcall(listener, payload)
			if not ok then
				warn(`[Signal] un listener falló: {err}`)
			end
		end
	end

	return signal
end

return Signal
