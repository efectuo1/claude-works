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

			["la plaza central está reservada"] = function()
				expect(not MapLayout.isClear(Vector2.zero, 0), "el centro debe estar reservado")
			end,

		})
	end,
}
