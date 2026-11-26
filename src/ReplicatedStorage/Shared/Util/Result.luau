--!strict
--[[
	Tipo Result para errores esperados (validación, reglas de negocio).
	Los errores inesperados siguen usando error(); esto evita pcall en cada capa.
]]

export type Ok<T> = { ok: true, value: T }
export type Err = { ok: false, error: string }
export type Result<T> = Ok<T> | Err

local Result = {}

function Result.ok<T>(value: T): Ok<T>
	return { ok = true, value = value }
end

function Result.err(message: string): Err
	return { ok = false, error = message }
end

return table.freeze(Result)
