-- Logical geometry matches the Claret Hotbuild keyboard. No Hotbuild dependency.
Rows = {
    {0, 0, {{'Esc','Esc'}, {'F1','F1',1,1}, {'F2','F2'}, {'F3','F3'}, {'F4','F4'}, {'F5','F5',1,0.35}, {'F6','F6'}, {'F7','F7'}, {'F8','F8'}, {'F9','F9',1,0.35}, {'F10','F10'}, {'F11','F11'}, {'F12','F12'}}},
    {0, 70, {{'~','Tilde'},{'1','1'},{'2','2'},{'3','3'},{'4','4'},{'5','5'},{'6','6'},{'7','7'},{'8','8'},{'9','9'},{'0','0'},{'-','Minus'},{'=','Equals'},{'Backspace','Backspace',2}}},
    {0, 126, {{'Tab','Tab',1.5},{'Q','Q'},{'W','W'},{'E','E'},{'R','R'},{'T','T'},{'Y','Y'},{'U','U'},{'I','I'},{'O','O'},{'P','P'},{'[','LeftBracket'},{']','RightBracket'},{'\\','Backslash',1.5}}},
    {0, 182, {{'Caps','CapsLock',1.75},{'A','A'},{'S','S'},{'D','D'},{'F','F'},{'G','G'},{'H','H'},{'J','J'},{'K','K'},{'L','L'},{';','Semicolon'},{"'",'Quote'},{'Enter','Enter',2.25}}},
    {0, 238, {{'Shift',false,2.25,0,'shift'},{'Z','Z'},{'X','X'},{'C','C'},{'V','V'},{'B','B'},{'N','N'},{'M','M'},{',','Comma'},{'.','Period'},{'/','Slash'},{'Shift',false,2.75,0,'shift'}}},
    {0, 294, {{'Ctrl',false,1.25,0,'ctrl'},{'Alt',false,1.25,1.25,'alt'},{'Space','Space',6.25},{'Alt',false,1.25,0,'alt'},{'Ctrl',false,1.25,2.5,'ctrl'}}},
    {850, 0, {{'Print','PrintScreen'},{'Scroll','ScrollLock'},{'Pause','Pause'}}},
    {850, 70, {{'Insert','Insert'},{'Home','Home'},{'Page Up','PageUp'}}},
    {850, 126, {{'Delete','Delete'},{'End','End'},{'Page Down','PageDown'}}},
    {850, 238, {{'Mouse 5','XButton2',1.5}}},
    {850, 294, {{'Mouse 4','XButton1',1.5}}},
    {0, 370, {{'Num Lock','NumLock'},{'/','NumSlash'},{'*','NumStar'},{'-','NumMinus'}}},
    {0, 424, {{'Num7','Num7'},{'Num8','Num8'},{'Num9','Num9'},{'+','NumPlus',1,0,false,104}}},
    {0, 478, {{'Num4','Num4'},{'Num5','Num5'},{'Num6','Num6'}}},
    {0, 532, {{'Num1','Num1'},{'Num2','Num2'},{'Num3','Num3'}}},
    {0, 586, {{'Num0','Num0',2},{'.','NumPeriod'}}},
}

function Chord(key, ctrl, shift, alt)
    return (ctrl and 'Ctrl-' or '') .. (shift and 'Shift-' or '') .. (alt and 'Alt-' or '') .. key
end

local allowed = {}
for _, row in ipairs(Rows) do
    for _, key in ipairs(row[3]) do
        if key[2] and key[2] ~= 'Esc' then
            for mask = 0, 7 do
                allowed[Chord(key[2], math.mod(mask, 2) == 1, math.mod(math.floor(mask / 2), 2) == 1, mask >= 4)] = true
            end
        end
    end
end

function IsAssignable(key)
    return type(key) == 'string' and allowed[key] == true
end
