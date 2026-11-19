--!strict
-- Pure layout math for the backpack panel shell (no Roblox APIs, headless-tested at phone and PC sizes):
-- the panel rectangle inside the gui area (below the Roblox top bar), and the header row where the title,
-- Drop and X buttons must never overlap each other or the body below.

export type Rect = { x: number, y: number, w: number, h: number }
export type Header = { title: Rect, drop: Rect, close: Rect, height: number }
export type Params = {
	pad: number, -- inner padding / edge gap
	gap: number, -- space between header items
	button: number, -- X button size (square) and header row height
	dropWidth: number,
	topInset: number, -- px between header row top and the panel top
}

local BackpackLayout = {}

-- Panel rect inside a gui of guiW x guiH (already below the top bar when IgnoreGuiInset is false).
function BackpackLayout.panel(
	guiW: number,
	guiH: number,
	widthScale: number,
	maxWidth: number,
	maxHeight: number,
	topMargin: number,
	bottomMargin: number
): Rect
	local w = math.max(math.min(guiW * widthScale, maxWidth), 0)
	local h = math.max(math.min(guiH - topMargin - bottomMargin, maxHeight), 0)
	return { x = (guiW - w) / 2, y = topMargin, w = w, h = h }
end

-- Header row for a panel of width w: title (left), Drop, X (right). Items are laid out right to left and the
-- title takes what remains (never negative).
function BackpackLayout.header(w: number, p: Params): Header
	local closeX = w - p.pad - p.button
	local dropX = closeX - p.gap - p.dropWidth
	local titleW = math.max(dropX - p.gap - p.pad, 0)
	local y = p.topInset
	return {
		title = { x = p.pad, y = y, w = titleW, h = p.button },
		drop = { x = dropX, y = y, w = p.dropWidth, h = p.button },
		close = { x = closeX, y = y, w = p.button, h = p.button },
		height = y + p.button + p.gap,
	}
end

function BackpackLayout.overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

return BackpackLayout
