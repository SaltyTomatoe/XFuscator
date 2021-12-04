local function Disassemble(chunk)
    local bit = LAT.Lua51.bit
    local Chunk, Local, Constant, Upvalue, Instruction = LAT.Lua51.Chunk, LAT.Lua51.Local, LAT.Lua51.Constant, LAT.Lua51.Upvalue, LAT.Lua51.Instruction
    local Luafile = LAT.Lua51.LuaFile
    local GetNumberType = LAT.Lua51.GetNumberType
	print("#",#chunk)
    if chunk == nil then
        error("File is nil!")
    end
	local index = 1
	local big = false;
    local file = LAT.Lua51.LuaFile:new()
    local loadNumber = nil
    local function Read(len)
        len = len or 1
        local c = chunk:sub(index, index + len - 1)
        index = index + len
        if file.BigEndian then
            c = string.reverse(c)
        else
        end
        return c
    end
	
	local function ReadInt8()		
		local a = chunk:sub(index, index):byte()
		index = index + 1
		return a
	end
    
	local function ReadNumber()
        return loadNumber(Read(file.NumberSize))
	end
	
	local function GetString(len)
		local str = chunk:sub(index, index + len - 1)
		index = index + len
		return str
	end

    local function ReadInt32()
        local a, b, c, d = chunk:byte(index, index + 3);
        index = index + 4;
        return d*16777216 + c*65536 + b*256 + a
    end

	local function ReadInt64()
        local a = ReadInt32();
        local b = ReadInt32();
        return b*4294967296 + a;
    end

	local function ReadString()
		if(file.SizeT == 8)then
			local size = ReadInt64()
			return GetString(size):sub(1, -2) -- Strip last '\0'
		end
		return GetString(ReadInt32()):sub(1, -2) -- Strip last '\0'
	end
    
	local function ReadFunction()
		local c = Chunk:new()
		c.Name = ReadString()
		c.FirstLine = ReadInt32()
		c.LastLine = ReadInt32()
		c.UpvalueCount = ReadInt8() -- Upvalues
		c.ArgumentCount = ReadInt8()
		c.Vararg = ReadInt8()
		c.MaxStackSize = ReadInt8()
		
        -- Instructions
		--c.Instructions.Count = ReadInt32()
        local count = ReadInt32()
        for i = 1, count do
            local op = ReadInt32();
            local opcode = bit.get(op, 1, 6)
            local instr = Instruction:new(opcode + 1, i)
            instr.Raw = op
            if instr.OpcodeType == "ABC" then
                instr.A = bit.get(op, 7, 14)
                instr.B = bit.get(op, 24, 32)
                instr.C = bit.get(op, 15, 23)
            elseif instr.OpcodeType == "ABx" then
                instr.A = bit.get(op, 7, 14)
                instr.Bx = bit.get(op, 15, 32)
            elseif instr.OpcodeType == "AsBx" then
                instr.A = bit.get(op, 7, 14)
                instr.sBx = bit.get(op, 15, 32) - 131071
            end
            c.Instructions[i - 1] = instr
        end
		
		-- Constants
        --c.Constants.Count = ReadInt32()
        count = ReadInt32()
        for i = 1, count do
            local cnst = Constant:new()
            local t = ReadInt8()
            cnst.Number = i-1
            
            if t == 0 then
                cnst.Type = "Nil"
                cnst.Value = ""
            elseif t == 1 then
                cnst.Type = "Bool"
                cnst.Value = ReadInt8() ~= 0
            elseif t == 3 then
                cnst.Type = "Number"
                cnst.Value = ReadNumber()
            elseif t == 4 then
                cnst.Type = "String"
                cnst.Value = ReadString()
            end
            c.Constants[i - 1] = cnst
        end

        -- Protos
        --c.Protos.Count = ReadInt32()
        count = ReadInt32()
        for i = 1, count do
            c.Protos[i - 1] = ReadFunction()
        end
        
        -- Line numbers
        for i = 1, ReadInt32() do 
            c.Instructions[i - 1].LineNumber = ReadInt32()
		end
        
        -- Locals
        --c.Locals.Count = ReadInt32()
		print(index)
        count = ReadInt32()
		print(index)
        for i = 1, count do
			print(index)
            c.Locals[i - 1] = Local:new(ReadString(), ReadInt32(), ReadInt32())
			print("Continue")
        end
        -- Upvalues
        --c.Upvalues.Count = ReadInt32()
        count = ReadInt32()
        for i = 1, count do 
            c.Upvalues[i - 1] = Upvalue:new(ReadString())
        end
		
		return c
	end
	
	file.Identifier = GetString(4) -- \027Lua
    if file.Identifier ~= "\027Lua" then
        error("Not a valid Lua bytecode chunk")
    end
	file.Version = ReadInt8() -- 0x51
    if file.Version ~= 0x51 then
        error(string.format("Invalid bytecode version, 0x51 expected, got 0x%02x", file.Version))
    end
	file.Format = ReadInt8() == 0 and "Official" or "Unofficial"
    if file.Format == "Unofficial" then
        error("Unknown binary chunk format")
    end
	file.BigEndian = ReadInt8() == 0
	file.IntegerSize = ReadInt8()
	file.SizeT = ReadInt8() 	
	file.InstructionSize = ReadInt8()
	file.NumberSize = ReadInt8()
	file.IsFloatingPoint = ReadInt8() == 0
    loadNumber = GetNumberType(file)
    if file.InstructionSize ~= 4 then
        error("Unsupported instruction size '" .. file.InstructionSize .. "', expected '4'")
    end
	file.Main = ReadFunction()
	return file
end

return Disassemble
