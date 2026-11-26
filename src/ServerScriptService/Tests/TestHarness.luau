--!strict
-- Utilidad mínima de pruebas compartida por las suites nuevas.
local TestHarness = {}

function TestHarness.expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

function TestHarness.run(suite: string, tests: { [string]: () -> () }): boolean
	local total = 0
	local failures = 0
	for name, test in tests do
		total += 1
		local ok, err = pcall(test)
		if not ok then
			failures += 1
			warn(`[FAIL] {suite} :: {name}: {err}`)
		end
	end
	print(`[{suite}] {total - failures}/{total} OK`)
	return failures == 0
end

return TestHarness
