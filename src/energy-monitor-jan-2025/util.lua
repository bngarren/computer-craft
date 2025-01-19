local util = {}

function util.round(number, digit_position)
    local precision = math.pow(10, digit_position)
    number = number + (precision / 2);
    return math.floor(number / precision) * precision
end

return util