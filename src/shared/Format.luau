-- Makes big numbers readable: 1234 -> "1.23K", 5600000 -> "5.6M"

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.number(n: number): string
	if n ~= n then
		return "0"
	end
	if math.abs(n) < 1000 then
		if n == math.floor(n) then
			return tostring(math.floor(n))
		end
		return string.format("%.1f", n)
	end
	local index = math.floor(math.log10(math.abs(n)) / 3)
	if index >= #SUFFIXES then
		return string.format("%.2e", n)
	end
	local scaled = n / 1000 ^ index
	local text = string.format("%.2f", scaled):gsub("%.?0+$", "")
	return text .. SUFFIXES[index + 1]
end

function Format.multiplier(n: number): string
	local text = string.format("%.2f", n):gsub("%.?0+$", "")
	return "x" .. text
end

return Format
