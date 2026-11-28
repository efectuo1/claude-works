--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local MapLayout = require(ServerScriptService.World.MapLayout)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

local function isFlat(x: number, z: number): boolean
	return math.abs(MapLayout.height(x, z) - MapLayout.FLAT_HEIGHT) < 1e-6
end

return {
	run = function(): boolean
		return TestHarness.run("MapLayout", {
			["la plaza de inicio es plana"] = function()
				expect(isFlat(0, 0), "el centro debe ser plano")
			end,

			["la tienda y la arena de modalidades son planas"] = function()
				for _, region in MapLayout.regions() do
					expect(isFlat(region.center.X, region.center.Y), `{region.id} no es plana`)
				end
			end,

			["cada zona cabe dentro del mapa"] = function()
				for _, region in MapLayout.regions() do
					local edge = math.max(math.abs(region.center.X), math.abs(region.center.Y)) + region.radius
					expect(edge < MapLayout.HALF_SIZE - MapLayout.EDGE_WIDTH, `{region.id} se sale del mapa`)
				end
			end,

			["los spawns de mobs están libres de zonas y caminos"] = function()
				for name, point in MapLayout.spawnPoints() do
					expect(MapLayout.isClear(point, 0), `{name} está dentro de una zona o camino`)
				end
			end,

			["los spawns de mobs caen dentro de una isla, lejos del acantilado"] = function()
				for name, point in MapLayout.spawnPoints() do
					expect(MapLayout.onLand(point, 4), `{name} queda en el acantilado o en el mar`)
				end
			end,

			["los spawns de mobs están en la isla del campo, no en el hub"] = function()
				for name, point in MapLayout.spawnPoints() do
					expect(point.X > 100, `{name} debe quedar fuera de la isla del hub`)
				end
			end,

			["las dos islas están separadas por mar"] = function()
				expect(MapLayout.height(115, 0) < MapLayout.SEA_LEVEL, "entre las islas debe haber agua")
			end,

			["el puente va de una meseta a la otra"] = function()
				local bridge = MapLayout.BRIDGE
				expect(MapLayout.onLand(bridge.from, 0), "el puente debe empezar sobre la meseta del hub")
				expect(MapLayout.onLand(bridge.to, 0), "el puente debe acabar sobre la meseta del campo")
			end,

			["el puente no tiene decoración encima"] = function()
				expect(not MapLayout.isClear(Vector2.new(72, 0), 0), "el paso del puente debe estar libre de decoración")
			end,

			["fuera de la isla el terreno está bajo el nivel del agua"] = function()
				local far = Vector2.new(0, -(MapLayout.ISLAND_RADIUS + 40))
				expect(MapLayout.height(far.X, far.Y) < MapLayout.SEA_LEVEL, "el mar debe quedar bajo el nivel del agua")
			end,

			["dentro de la isla la meseta queda sobre el agua"] = function()
				local inside = Vector2.new(MapLayout.ISLAND_RADIUS - MapLayout.RIM_WIDTH - 20, 0)
				expect(MapLayout.height(inside.X, inside.Y) > MapLayout.SEA_LEVEL, "la tierra debe quedar sobre el agua")
			end,

			["la plaza central está reservada"] = function()
				expect(not MapLayout.isClear(Vector2.zero, 0), "el centro debe estar reservado")
			end,

		})
	end,
}
