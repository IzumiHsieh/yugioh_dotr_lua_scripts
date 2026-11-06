local UInt64 = require("UInt64")

local rng_seed_addr = 0x28f850

function mult32(a, b)
    local a1 = (a >> 16)
    local a0 = (a & 0xFFFF)
    local b1 = (b >> 16)
    local b0 = (b & 0xFFFF)

    local c0 = a0*b0
    local c1 = a1*b0 + a0*b1
    local c2 = a1*b1

    local aux = ((c1 & 0xFFFF) << 16) + c0
    local lo = aux & 0xffffffff
    local cy = (aux >> 32)
    local hi = (c1 >> 16) + c2 + cy

    return UInt64.new(lo, hi)
end

function add32(a, b)
    return (a + b) & 0xFFFFFFFF
end

function add64(a, b)
    local a1 = a:higher()
    local a0 = a:lower()

    local b1 = b:higher()
    local b0 = b:lower()

    local aux = a0 + b0
    local cy = (aux >> 32)
    return UInt64.new(aux & 0xffffffff, (a1+b1+cy) & 0xffffffff)
end

function mult64(a, b)
    local a1 = a:higher()
    local a0 = a:lower()

    local b1 = b:higher()
    local b0 = b:lower()

    local c1 = UInt64.new(0, add32(mult32(a1, b0):lower(), mult32(a0, b1):lower()))
    local c0 = mult32(a0, b0)

    return add64(c1, c0)
end

local a = {}
local c = {}

function init_lcg_params()
    table.insert(a, UInt64.new(0x4C957F2D, 0x5851F42D))
    table.insert(c, UInt64.new(1, 0))
    for i=1,63 do
        local last_a = a[#a]
        local last_c = c[#c]
        next_a = mult64(last_a, last_a)
        next_c = add64(mult64(last_a, last_c), last_c)
        table.insert(a, next_a)
        table.insert(c, next_c)
    end
end

function get_pos(seed)
    local val = UInt64.new(1, 0)
    local pos = UInt64.new(0, 0)
    for i=1,63 do
        local mask = UInt64.new(0, 0)
        if i < 32 then
            mask = UInt64.new((1<<i)- 1, 0)
        else
            mask = UInt64.new(0xffffffff, (1<<(i-32)) - 1)
        end
        if (val & mask) ~= (seed & mask) then
            val = add64(mult64(a[i], val),c[i])
            pos = (pos | (UInt64.new(1,0) << (i-1)))
        end
    end
    if val ~= seed then
        pos = (pos | UInt64.new(1,0) << 63)
    end
    return pos
end

function next_seed(seed)
    return add64(mult64(UInt64.new(0x4C957F2D, 0x5851F42D), seed), UInt64.new(1, 0))
end

function show_rng()
    local seed = UInt64.new(memory.read_u32_le(rng_seed_addr), memory.read_u32_le(rng_seed_addr+4))
    local pos = get_pos(seed)
    gui.text(10, 40, string.format('seed: %s\npos: %s\n', seed:tohex(16),tostring(pos)))
end

init_lcg_params()
event.onframeend(show_rng)
