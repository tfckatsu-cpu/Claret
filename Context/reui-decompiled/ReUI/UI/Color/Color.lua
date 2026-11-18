-- Generated research-only output. Original SHA256: 506f1b7f92a8f5f176428b9366e3df0d666ad4322c352faa0894497ecbd0e967. Not for game execution.
Version = "1.0.0"
ReUI.Require({
  "ReUI.Core >= 1.0.0"
})

function Main(isReplay)
  local _tonumber = tonumber
  local MathFloor = math.floor
  local MathClamp = math.clamp
  local StringFormat = string.format
  local StringSub = string.sub
  
  local function ToHexString(int)
    return StringFormat("%02X", int)
  end
  
  local function SetAlpha(color, alpha)
    return ToHexString(alpha) .. StringSub(color, 3)
  end
  
  local function SetRed(color, red)
    return StringSub(color, 1, 2) .. ToHexString(red) .. StringSub(color, 5)
  end
  
  local function SetGreen(color, green)
    return StringSub(color, 1, 4) .. ToHexString(green) .. StringSub(color, 7)
  end
  
  local function SetBlue(color, blue)
    return StringSub(color, 1, 6) .. ToHexString(blue)
  end
  
  local function GetAlpha(color)
    return _tonumber(StringSub(color, 1, 2), 16)
  end
  
  local function GetRed(color)
    return _tonumber(StringSub(color, 3, 4), 16)
  end
  
  local function GetGreen(color)
    return _tonumber(StringSub(color, 5, 6), 16)
  end
  
  local function GetBlue(color)
    return _tonumber(StringSub(color, 7, 8), 16)
  end
  
  local function ColorRGBA(r, g, b, a)
    return StringFormat("%02x%02x%02x%02x", a or 255, r, g, b)
  end
  
  local function UnpackColor(color)
    return GetRed(color), GetGreen(color), GetBlue(color), GetAlpha(color)
  end
  
  local function ColorMult(color, mult)
    local r, g, b = UnpackColor(color)
    r = MathFloor(MathClamp(r * mult, 0, 255))
    g = MathFloor(MathClamp(g * mult, 0, 255))
    b = MathFloor(MathClamp(b * mult, 0, 255))
    return ColorRGBA(r, g, b)
  end
  
  return {
    SetAlpha = SetAlpha,
    SetRed = SetRed,
    SetGreen = SetGreen,
    SetBlue = SetBlue,
    GetAlpha = GetAlpha,
    GetRed = GetRed,
    GetGreen = GetGreen,
    GetBlue = GetBlue,
    ColorMult = ColorMult,
    ColorRGBA = ColorRGBA,
    UnpackColor = UnpackColor
  }
end
