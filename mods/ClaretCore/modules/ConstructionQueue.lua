-- Read-only projection of FAF's already ordered, possibly enhancement-integrated queue.
-- sourceIndex refers only to this input presentation queue; enhancement insertion can make
-- it differ from raw factory command indices. Build never issues or edits commands.

function Create()
    local function Build(queue, opts)
        opts = opts or {}
        local rows, errors = {}, {}
        local logicalPosition = 1
        local lastFactoryId = nil
        local lastFactoryPosition = nil
        local dragging = opts.dragging == true

        if type(queue) ~= 'table' then
            return { entries = rows, errors = { 'queue must be a table' } }
        end

        local maxIndex = 0
        for key in pairs(queue) do
            if type(key) == 'number' and key >= 1 and key < math.huge and key == math.floor(key) then
                if key > maxIndex then maxIndex = key end
            else
                table.insert(errors, { sourceIndex = key, reason = 'queue key must be a positive integer' })
            end
        end

        for sourceIndex = 1, maxIndex do
            local item = queue[sourceIndex]
            if item == nil then
                table.insert(rows, { kind = 'invalid', sourceIndex = sourceIndex, reason = 'missing queue entry' })
                table.insert(errors, { sourceIndex = sourceIndex, reason = 'missing queue entry' })
                lastFactoryId, lastFactoryPosition = nil, nil
            elseif type(item) ~= 'table' then
                table.insert(rows, { kind = 'invalid', sourceIndex = sourceIndex, reason = 'entry must be a table' })
                table.insert(errors, { sourceIndex = sourceIndex, reason = 'entry must be a table' })
                lastFactoryId, lastFactoryPosition = nil, nil
            elseif item.type == 'enhancementqueue' then
                table.insert(rows, {
                    kind = 'enhancement',
                    sourceIndex = sourceIndex,
                    id = item.id,
                    unitID = item.id or item.unitID,
                    icon = item.icon,
                    name = item.name,
                    enhancement = item.enhancement,
                })
                -- FAF's SetSecondaryDisplay does not advance queue position for these rows,
                -- and leaves the prior unit stack eligible for same-id position grouping.
            elseif item.type == nil or item.type == 'queuestack' then
                local id = item.id
                local count = item.displayCount or item.count
                local validCount = type(count) == 'number' and count > 0
                    and count < math.huge and count == math.floor(count)
                if id == nil or id == '' or not validCount then
                    local reason = 'count must be a positive integer'
                    if id == nil or id == '' then reason = 'missing unit id' end
                    table.insert(rows, { kind = 'invalid', sourceIndex = sourceIndex, id = id, reason = reason })
                    table.insert(errors, { sourceIndex = sourceIndex, reason = reason })
                    lastFactoryId, lastFactoryPosition = nil, nil
                else
                    local position
                    if not dragging and lastFactoryId == id then
                        position = lastFactoryPosition
                    else
                        position = logicalPosition
                        logicalPosition = logicalPosition + 1
                    end
                    table.insert(rows, {
                        kind = 'factory',
                        sourceIndex = sourceIndex,
                        id = id,
                        count = count,
                        position = position,
                    })
                    lastFactoryId, lastFactoryPosition = id, position
                end
            else
                local reason = 'unsupported queue entry type: ' .. tostring(item.type)
                table.insert(rows, { kind = 'invalid', sourceIndex = sourceIndex, reason = reason })
                table.insert(errors, { sourceIndex = sourceIndex, reason = reason })
                lastFactoryId, lastFactoryPosition = nil, nil
            end
        end

        return { entries = rows, errors = errors }
    end

    return { Build = Build }
end
