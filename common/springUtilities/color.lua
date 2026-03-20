if not Game then
	return -- some parser environments such as modrules don't have it, but they don't need colored text either
end

local floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pow = math.pow
local schar = string.char

local colorIndicator = Game.textColorCodes.Color
local colorAndOutlineIndicator = Game.textColorCodes.ColorAndOutline

local minTextContrast = 5 -- WCAG 2 text contrast should be 4.5 to 7 minimum
local textOutlineColor = 0.2
local textOutlineAlpha = 2
local darkTextLuminance = 0.07 -- 0.07 was selected because its the lower than all 16 colors in the BAR 8v8 color palette.
local textOutlineAlphaDark = 0.75 -- not alpha? idk

local function ColorStringEx(r, g, b, a, oR, oG, oB, oA)
	-- Formats alpha and also outline color.
	return colorAndOutlineIndicator .. schar(floor(r * 255)) .. schar(floor(g * 255)) ..
		schar(floor(b * 255)) .. schar(floor(a * 255)) ..
		schar(floor(oR * 255)) .. schar(floor(oG * 255)) ..
		schar(floor(oB * 255)) .. schar(floor(oA * 255))
end

local function ColorArray(r, g, b)
	return floor(r * 255), floor(g * 255), floor(b * 255)
end

local function ColorString(r, g, b)
	-- Standard R, G, B color code.
	r = floor(r * 255)
	g = floor(g * 255)
	b = floor(b * 255)
	-- avoid special char used by i18n
	if r == 37 then r = 38 end	-- 37 = %
	if g == 37 then g = 38 end	-- 37 = %
	if b == 37 then b = 38 end	-- 37 = %
	return colorIndicator .. schar(r) .. schar(g) .. schar(b)
end

-- Convert Gamma corrected RGB (0-1) to linear RGB
-- See https://en.wikipedia.org/wiki/SRGB#From_sRGB_to_CIE_XYZ for an explanation of this transfert function
local function RgbToLinear(c)
    if c <= 0.04045 then
        return c / 12.92
    end
    return math_pow((c + 0.055) / 1.055, 2.4)
end

-- Convert Gamma corrected RGB (0-1) to the Y' relative luminance of XYZ
local function RgbToY(r, g, b)
    local linearR = RgbToLinear(r)
    local linearG = RgbToLinear(g)
    local linearB = RgbToLinear(b)
    return linearR * 0.2126729 + linearG * 0.7151522 + linearB * 0.0721750
end

local function YToRgb(c)
    if c <= 0.0031308 then
        c = c * 12.92
    else
        c = 1.055 * (c ^ (1 / 2.4)) - 0.055
    end
    return math.clamp(c, 0, 1)
end

-- Input color is a gamma corrected RGB (0-1) color
local function ColorIsDark(red, green, blue)
	Spring.Echo("luminances", RgbToY(red, green, blue), darkTextLuminance)
	return RgbToY(red, green, blue) < darkTextLuminance
end

local function IsDark(luminance)
	return luminance <= darkTextLuminance
end

local function IsReadableContrast(luminance1, luminance2)
	return (luminance1 + 0.05) / (luminance2 + 0.05) >= minTextContrast
end

local function GetTextOutlineColor(pr, pg, pb, br, bg, bb)
    local luminancePlayer     = RgbToY(pr, pg, pb)
    local luminanceBackground = RgbToY(br, bg, bb)

	local luminance1 = math_max(luminancePlayer, luminanceBackground)
	local luminance2 = math_min(luminancePlayer, luminanceBackground)

	if not IsDark(luminance1) or IsReadableContrast(luminance1, luminance2) then
		local c = textOutlineColor
		return c, c, c, textOutlineAlpha
	else
		-- Get the minimum-luminance text outline color to yield a readable text contrast:
		local contrastTarget = minTextContrast / math.clamp(textOutlineAlphaDark, 0.1, 1)
		local luminanceOutline = math_min(contrastTarget * (luminance1 + 0.05) - 0.05, 1)
		local c = YToRgb(luminanceOutline)
		return c, c, c, textOutlineAlphaDark
	end
end

local function GetDarkOutlineColor(red, green, blue)
	local luminance = RgbToY(red, green, blue)
	local luminanceOutline = math_min(minTextContrast * (luminance + 0.05) - 0.05, 1)
	local c = YToRgb(luminanceOutline)
	return c, c, c, textOutlineAlphaDark
end

return {
	ToString = ColorString,
	ToStringEx = ColorStringEx,
	ToIntArray = ColorArray,
	ColorIsDark = ColorIsDark,
	GetTextOutlineColor = GetTextOutlineColor,
	GetDarkOutlineColor = GetDarkOutlineColor,
}
