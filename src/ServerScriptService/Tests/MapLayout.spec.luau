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

			["los spawns de mobs están en las islas satélite, no en la isla grande"] = function()
				for name, point in MapLayout.spawnPoints() do
					expect(point.Magnitude > MapLayout.ISLAND_RADIUS, `{name} debe quedar fuera de la isla grande`)
				end
			end,

			["hay un puente por cada isla satélite"] = function()
				local satellites = 0
				for _, island in MapLayout.islands() do
					if island.id ~= "principal" then
						satellites += 1
					end
				end
				expect(satellites == 4, "debe haber cuatro islas satélite")
				expect(#MapLayout.bridges() == satellites, "cada satélite necesita su puente")
			end,

			["cada puente va de una meseta a otra"] = function()
				for _, bridge in MapLayout.bridges() do
					expect(MapLayout.onLand(bridge.from, 0), `el puente {bridge.id} debe empezar sobre la meseta grande`)
					expect(MapLayout.onLand(bridge.to, 0), `el puente {bridge.id} debe acabar sobre la meseta del satélite`)
				end
			end,

			["entre la isla grande y cada satélite hay mar"] = function()
				for _, bridge in MapLayout.bridges() do
					local middle = (bridge.from + bridge.to) / 2
					expect(MapLayout.height(middle.X, middle.Y) < MapLayout.SEA_LEVEL, `bajo el puente {bridge.id} debe haber agua`)
				end
			end,

			["los puentes y caminos no tienen decoración encima"] = function()
				for _, bridge in MapLayout.bridges() do
					expect(not MapLayout.isClear(bridge.from, 0), `el inicio del puente {bridge.id} debe estar reservado`)
				end
				for _, road in MapLayout.roads() do
					local middle = (road.from + road.to) / 2
					expect(not MapLayout.isClear(middle, 0), "el camino debe estar libre de decoración")
				end
			end,

			["el borde de la isla grande baja en terrazas hasta el mar"] = function()
				local function at(distanceFromShore: number): number
					local r = MapLayout.ISLAND_RADIUS - distanceFromShore
					return MapLayout.height(0, -r)
				end
				local plateau = at(MapLayout.RIM_WIDTH + 5)
				local high = at(MapLayout.RIM_WIDTH * 0.65)
				local low = at(MapLayout.RIM_WIDTH * 0.4)
				expect(plateau > high + 2, "la terraza alta debe quedar bajo la meseta")
				expect(high > low + 2, "la terraza baja debe quedar bajo la alta")
				expect(low > MapLayout.SEA_LEVEL, "la terraza baja debe quedar sobre el agua")
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
