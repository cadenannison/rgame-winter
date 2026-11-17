--!strict

export type Assets = {
	[string]: string,
}

-- Asset ids ("rbxassetid://..."). Log every imported asset in docs/ART.md.
local Assets: Assets = {}

return Assets
