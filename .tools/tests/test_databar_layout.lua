local file = assert(io.open("EllesmereUIDataBars/EllesmereUIDataBars.lua"))
local source = file:read("*a")
file:close()
local solver = assert(source:match("(local EDGE_PAD = 0.-)\n%-%-+\n%-%-  Theme rendering"))
local ns = {}
local chunk = assert(loadstring(solver))
setfenv(chunk, setmetatable({ ns = ns, floor = math.floor, max = math.max }, { __index = _G }))
chunk()

local function block(id, alignment, width)
    return { id = id, type = "clock", alignment = alignment, width = width, contentGap = 0 }
end
local function solve(blocks, mode)
    return ns.SolveLayout({ blocks = blocks, sizingMode = mode }, 300, function(b) return b.width end)
end
assert(#solve({}) == 0)
local left, center, right = block(1, "left", 40), block(2, "center", 30), block(3, "right", 20)
for _, mode in ipairs({ "auto", "even" }) do
    local s = solve({ left, center, right }, mode)
    assert(s[1].at == 0 and s[2].at + s[2].px / 2 == 150 and s[3].at + s[3].px == 300)
    s = solve({ center, right }, mode)
    assert(s[1].at + s[1].px / 2 == 150)
end
local s = solve({ block(1, nil, 40), center })
assert(s[1].at == 0 and s[2].at == 135)
s = solve({ block(1, "left", 0), center })
assert(s[1].px == 0 and s[2].at == 135)
s = solve({ block(1, "left", 400), block(2, "center", 200), block(3, "right", 400) })
assert(s[1].at + s[1].px <= s[2].at)
assert(s[2].at + s[2].px <= s[3].at)
s = solve({ block(1, nil, 40), block(2, nil, 20) }, "even")
assert(s[1].px == 150 and s[2].px == 150)
s = solve({ block(1, nil, 40), block(2, nil, 20) })
assert(s[1].px == 40 and s[2].px == 260)
print("Data bar layout tests passed")
