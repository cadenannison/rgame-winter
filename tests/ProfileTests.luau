--!strict
-- Tests for ProfileSchema (default, validate, migrate).

local Config = require("../src/shared/Config")
local ProfileSchema = require("../src/shared/logic/ProfileSchema")

return function(check: (string, boolean) -> ())
	check("profile default validates", ProfileSchema.validate(ProfileSchema.default()))
	check("profile negative coins invalid", not ProfileSchema.validate({
		schemaVersion = Config.SchemaVersion,
		coins = -1,
	}))
	check("profile nan coins invalid", not ProfileSchema.validate({
		schemaVersion = Config.SchemaVersion,
		coins = 0 / 0,
	}))
	check("profile non-table invalid", not ProfileSchema.validate(nil))

	local fresh: any = {}
	check("migrate empty ok", ProfileSchema.migrate(fresh))
	check("migrate empty validates", ProfileSchema.validate(fresh))

	local dirty: any = { coins = 1e99 }
	check("migrate clamps coins", ProfileSchema.migrate(dirty) and dirty.coins == Config.MaxCoins)

	local newer: any = { schemaVersion = Config.SchemaVersion + 1, coins = 5 }
	check("migrate refuses newer schema", not ProfileSchema.migrate(newer) and newer.coins == 5)
	check("migrate refuses non-table", not ProfileSchema.migrate("x"))
end
