--!strict
-- Enrutador de instancias: cada jugador ve el registro de la instancia donde está, o el del mundo general.
local ServerScriptService = game:GetService("ServerScriptService")
local InstanceRouter = require(ServerScriptService.Instances.InstanceRouter)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

-- Registro falso: solo importa su identidad, así que cada uno es una tabla distinta.
local function lookup(name: string): InstanceRouter.TargetLookup
	return {
		get = function(_targetId: string): any
			return name
		end,
		near = function(_origin: Vector3, _radius: number): { any }
			return { name }
		end,
	}
end

local function newRouter()
	local overworld = lookup("overworld")
	return InstanceRouter.new(overworld), overworld
end

return {
	run = function(): boolean
		return TestHarness.run("InstanceRouter", {
			["sin instancia, el jugador usa el mundo general"] = function()
				local router, overworld = newRouter()
				expect(router.registryFor(1) == overworld, "debe devolver el overworld")
				expect(router.instanceOf(1) == nil, "no debe tener instancia")
			end,

			["entrar a una instancia cambia su registro"] = function()
				local router = newRouter()
				local arena = lookup("arena")
				router.create("oleadas-1", arena)
				expect(router.enter(1, "oleadas-1"), "debe poder entrar")
				expect(router.registryFor(1) == arena, "debe ver el registro de la arena")
				expect(router.instanceOf(1) == "oleadas-1", "debe reportar su instancia")
			end,

			["entrar a una instancia inexistente se rechaza sin cambiar nada"] = function()
				local router, overworld = newRouter()
				expect(router.enter(1, "no-existe") == false, "debe rechazar la entrada")
				expect(router.registryFor(1) == overworld, "debe seguir en el mundo general")
			end,

			["salir devuelve al mundo general"] = function()
				local router, overworld = newRouter()
				router.create("jefes-1", lookup("sala"))
				router.enter(1, "jefes-1")
				router.leave(1)
				expect(router.registryFor(1) == overworld, "tras salir debe volver al mundo")
				expect(router.instanceOf(1) == nil, "tras salir no debe tener instancia")
			end,

			["destruir una instancia devuelve a sus jugadores al mundo"] = function()
				local router, overworld = newRouter()
				router.create("jefes-1", lookup("sala"))
				router.enter(1, "jefes-1")
				router.enter(2, "jefes-1")
				router.destroy("jefes-1")
				expect(router.registryFor(1) == overworld, "el jugador 1 debe volver al mundo")
				expect(router.registryFor(2) == overworld, "el jugador 2 debe volver al mundo")
			end,

			["destruir una instancia no toca a los jugadores de otra"] = function()
				local router = newRouter()
				local other = lookup("otra")
				router.create("a", lookup("a"))
				router.create("b", other)
				router.enter(1, "a")
				router.enter(2, "b")
				router.destroy("a")
				expect(router.registryFor(2) == other, "el jugador de la instancia b no debe moverse")
			end,

			["dos instancias no pueden usar el mismo id"] = function()
				local router = newRouter()
				router.create("x", lookup("x"))
				local ok = pcall(function()
					router.create("x", lookup("x2"))
				end)
				expect(not ok, "un id repetido debe fallar")
			end,

			["un jugador solo está en una instancia a la vez"] = function()
				local router = newRouter()
				local second = lookup("segunda")
				router.create("a", lookup("a"))
				router.create("b", second)
				router.enter(1, "a")
				router.enter(1, "b")
				expect(router.instanceOf(1) == "b", "debe quedar en la última a la que entró")
				expect(router.registryFor(1) == second, "debe ver solo el registro actual")
			end,
		})
	end,
}
