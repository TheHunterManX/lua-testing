local ins = {
	[0] = "mov_reg",
	[1] = "mov_val",
	[2] = "print",
	[3] = "add",
	[4] = "sub",
	[5] = "add_32",
	[6] = "sub_32",
	[0xD0] = "goto",
	[0xD1] = "bx",
	[0xFE] = "end",
	[0xFF] = "white",
}

local ins_len = {
	[0] = 3,
	[1] = 2,
	[2] = 1,
	[3] = 3,
	[4] = 3,
	[5] = 6,
	[6] = 6,
	[0xD0] = 4,
	[0xD1] = 3,
	[0xFE] = 1,
	[0xFF] = 1,
}

local reg = {
	[1] = "acc",
	[0xE] = "lr",
	[0xF] = "pc",
	[0xF0] = "var",
	[0xF1] = "custom",
	[0xFE] = "eol",
	[0xFF] = "eol",
}
local G = {}

local function read_uint16(f)
    local b = f:read(2)
    return b and b:byte(1) | (b:byte(2) << 8)
end

local function read_uint32(f)
    local b = f:read(4)
    return b and b:byte(1) | (b:byte(2) << 8) | (b:byte(3) << 16) | (b:byte(4) << 24)
end

local function interpret(f)
	local fs = f:seek("end")
	f:seek("set", 0)
	G.pc = 0
	while true do
		if G.pc > fs then break end
		f:seek("set", G.pc)
		local b = f:read(1)
		if not b then break end
		local c = string.byte(b)
		print("EXECUTING LINE " .. G.pc .. " INSTRUCTION " .. c)
		local _c = ins[c]
		if _c then
			G.pc = G.pc + ins_len[c]
			if _c == "print" then
				local p = ""
				while true do
					f:seek("set", G.pc)
					local l = f:read(5)
					if not l or #l < 5 then G.pc = G.pc + 1 break end
					local r = reg[l:byte(1)] or "custom"
					if r == "var" then
						_r = l:byte(2) | (l:byte(3) << 8)
						p = p .. tostring(G[_r] or 0)
						G.pc = G.pc + 3
					elseif r == "custom" then
						local _l = l:byte(2) | (l:byte(3) << 8) | (l:byte(4) << 16) | (l:byte(5) << 24)
						p = p .. utf8.char(_l)
						G.pc = G.pc + 5
					elseif r == "eol" then
						G.pc = G.pc + 1
						break
					else
						G.pc = G.pc + 1
						_r = G[r] or 0
						p = p .. _r
					end
				end
				print(p)
			elseif _c == "mov_reg" then
				local r = string.byte(f:read(1))
				local _r = reg[r] or 0
				if _r == "var" then
					_r = read_uint16(f)
					G.pc = G.pc + 2
				end
				local r2 = string.byte(f:read(1))
				local _r2 = reg[r2]
				if _r2 == "var" then
					_r2 = read_uint16(f)
					G.pc = G.pc + 2
				end
				G[_r] = G[_r2]
			elseif _c == "mov_val" then
				local r = string.byte(f:read(1))
				local _r = reg[r]
				if _r then
					if _r == "var" then
						_r = read_uint16(f)
						G.pc = G.pc + 2
					end
					local v = read_uint16(f)
					G.pc = G.pc + 2
					if not G[_r] then G[_r] = 0 end
					G[_r] = v
				else
					print("MOV_VAL ERROR: UNKNOWN REG: " .. r)
					break
				end
				
			elseif _c == "add" then
				local l = string.byte(f:read(1))
				local _l = reg[l]
				if _l then
					if _l == "var" then
						_l = read_uint16(f)
						G.pc = G.pc + 2
					end
					local a = string.byte(f:read(1))
					if not G[_l] then G[_l] = 0 end
					G[_l] = G[_l] + a
				else
					print("ADD ERROR: UNKNOWN REG: " .. r)
					break
				end
				
			elseif _c == "sub" then
				local l = string.byte(f:read(1))
				local _l = reg[l]
				if _l then
					if _l == "var" then
						_l = read_uint16(f)
						G.pc = G.pc + 2
					end
					local a = string.byte(f:read(1))
					if not G[_l] then G[_l] = 0 end
					G[_l] = G[_l] - a
				else
					print("SUB ERROR: UNKNOWN REG: " .. r)
					break
				end
				
			elseif _c == "add_32" then
				local l = string.byte(f:read(1))
				local _l = reg[l]
				if _l then
					if _l == "var" then
						_l = read_uint16(f)
						G.pc = G.pc + 2
					end
					local _a = read_uint32(f)
					if not G[_l] then G[_l] = 0 end
					G[_l] = G[_l] + _a
				else
					print("ADD_32 ERROR: UNKNOWN REG: " .. r)
					break
				end
				
			elseif _c == "sub_32" then
				local l = string.byte(f:read(1))
				local _l = reg[l]
				if _l then
					if _l == "var" then
						_l = read_uint16(f)
						G.pc = G.pc + 2
					end
					local _a = read_uint32(f)
					if not G[_l] then G[_l] = 0 end
					G[_l] = G[_l] - _a
				else
					print("SUB_32 ERROR: UNKNOWN REG: " .. r)
					break
				end
				
			elseif _c == "goto" then
				local _o = read_uint32(f)
				G.pc = _o
				
			elseif _c == "bx" then
				local l = string.byte(f:read(1))
				local _l = reg[l]
				if _l then
					if _l == "var" then
						_l = read_uint16(f)
						G.pc = G.pc + 2
					end
					if G[_l] then
						G.pc = G[_l]
					end
				else
					print("BX ERROR: UNKNOWN REG: " .. r)
					break
				end
				
			elseif _c == "end" then
				print("END INSTRUCTION SENT. CLOSING PROGRAM.")
				break
			end
		else
			print(string.format("ERROR, UNKNOWN COMMAND: 0x%X", c))
			break
		end
	end
end

local function main()
	io.write("Type a file to run: ")
	local f = io.read()
	if f then
		local _f, _e = io.open(f, "rb")
		if not _f then
			print("Error opening file " .. _e)
		else
			interpret(_f)
			_f:close()
		end
	end
	return true
end

while true do
	if not main() then
		break
	end
	G = {}
end