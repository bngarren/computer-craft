local expect = require("cc.expect")
local expect, field = expect.expect, expect.field

local util = {}

local ui = (function()
    -- PrimeUI by JackMacWindows
    -- Public domain/CC0

    local expect = require "cc.expect".expect

    -- Initialization code
    local PrimeUI = {}
    do
        local coros = {}
        local restoreCursor

        --- Adds a task to run in the main loop.
        ---@param func function The function to run, usually an `os.pullEvent` loop
        function PrimeUI.addTask(func)
            expect(1, func, "function")
            local t = {
                coro = coroutine.create(func)
            }
            coros[#coros + 1] = t
            _, t.filter = coroutine.resume(t.coro)
        end

        --- Sends the provided arguments to the run loop, where they will be returned.
        ---@param ... any The parameters to send
        function PrimeUI.resolve(...)
            coroutine.yield(coros, ...)
        end

        --- Clears the screen and resets all components. Do not use any previously
        --- created components after calling this function.
        function PrimeUI.clear()
            -- Reset the screen.
            term.setCursorPos(1, 1)
            term.setCursorBlink(false)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.clear()
            -- Reset the task list and cursor restore function.
            coros = {}
            restoreCursor = nil
        end

        --- Sets or clears the window that holds where the cursor should be.
        ---@param win window|nil The window to set as the active window
        function PrimeUI.setCursorWindow(win)
            expect(1, win, "table", "nil")
            restoreCursor = win and win.restoreCursor
        end

        --- Gets the absolute position of a coordinate relative to a window.
        ---@param win window The window to check
        ---@param x number The relative X position of the point
        ---@param y number The relative Y position of the point
        ---@return number x The absolute X position of the window
        ---@return number y The absolute Y position of the window
        function PrimeUI.getWindowPos(win, x, y)
            if win == term then
                return x, y
            end
            while win ~= term.native() and win ~= term.current() do
                if not win.getPosition then
                    return x, y
                end
                local wx, wy = win.getPosition()
                x, y = x + wx - 1, y + wy - 1
                _, win = debug.getupvalue(select(2, debug.getupvalue(win.isColor, 1)), 1) -- gets the parent window through an upvalue
            end
            return x, y
        end

        --- Runs the main loop, returning information on an action.
        ---@return any ... The result of the coroutine that exited
        function PrimeUI.run()
            while true do
                -- Restore the cursor and wait for the next event.
                if restoreCursor then
                    restoreCursor()
                end
                local ev = table.pack(os.pullEvent())
                -- Run all coroutines.
                for _, v in ipairs(coros) do
                    if v.filter == nil or v.filter == ev[1] then
                        -- Resume the coroutine, passing the current event.
                        local res = table.pack(coroutine.resume(v.coro, table.unpack(ev, 1, ev.n)))
                        -- If the call failed, bail out. Coroutines should never exit.
                        if not res[1] then
                            error(res[2], 2)
                        end
                        -- If the coroutine resolved, return its values.
                        if res[2] == coros then
                            return table.unpack(res, 3, res.n)
                        end
                        -- Set the next event filter.
                        v.filter = res[2]
                    end
                end
            end
        end
    end

    --- Draws a thin border around a screen region.
    ---@param win window The window to draw on
    ---@param x number The X coordinate of the inside of the box
    ---@param y number The Y coordinate of the inside of the box
    ---@param width number The width of the inner box
    ---@param height number The height of the inner box
    ---@param fgColor color|nil The color of the border (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    function PrimeUI.borderBox(win, x, y, width, height, fgColor, bgColor)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, width, "number")
        expect(5, height, "number")
        fgColor = expect(6, fgColor, "number", "nil") or colors.white
        bgColor = expect(7, bgColor, "number", "nil") or colors.black
        -- Draw the top-left corner & top border.
        win.setBackgroundColor(bgColor)
        win.setTextColor(fgColor)
        win.setCursorPos(x - 1, y - 1)
        win.write("\x9C" .. ("\x8C"):rep(width))
        -- Draw the top-right corner.
        win.setBackgroundColor(fgColor)
        win.setTextColor(bgColor)
        win.write("\x93")
        -- Draw the right border.
        for i = 1, height do
            win.setCursorPos(win.getCursorPos() - 1, y + i - 1)
            win.write("\x95")
        end
        -- Draw the left border.
        win.setBackgroundColor(bgColor)
        win.setTextColor(fgColor)
        for i = 1, height do
            win.setCursorPos(x - 1, y + i - 1)
            win.write("\x95")
        end
        -- Draw the bottom border and corners.
        win.setCursorPos(x - 1, y + height)
        win.write("\x8D" .. ("\x8C"):rep(width) .. "\x8E")
    end

    --- Creates a clickable button on screen with text.
    ---@param win window The window to draw on
    ---@param x number The X position of the button
    ---@param y number The Y position of the button
    ---@param text string The text to draw on the button
    ---@param action function|string A function to call when clicked, or a string to send with a `run` event
    ---@param fgColor color|nil The color of the button text (defaults to white)
    ---@param bgColor color|nil The color of the button (defaults to light gray)
    ---@param clickedColor color|nil The color of the button when clicked (defaults to gray)
    ---@param periphName string|nil The name of the monitor peripheral, or nil (set if you're using a monitor - events will be filtered to that monitor)
    function PrimeUI.button(win, x, y, text, action, fgColor, bgColor, clickedColor, periphName)
        expect(1, win, "table")
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, text, "string")
        expect(5, action, "function", "string")
        fgColor = expect(6, fgColor, "number", "nil") or colors.white
        bgColor = expect(7, bgColor, "number", "nil") or colors.gray
        clickedColor = expect(8, clickedColor, "number", "nil") or colors.lightGray
        periphName = expect(9, periphName, "string", "nil")
        -- Draw the initial button.
        win.setCursorPos(x, y)
        win.setBackgroundColor(bgColor)
        win.setTextColor(fgColor)
        win.write(" " .. text .. " ")
        -- Get the screen position and add a click handler.
        PrimeUI.addTask(function()
            local screenX, screenY = PrimeUI.getWindowPos(win, x, y)
            local buttonDown = false
            while true do
                local event, button, clickX, clickY = os.pullEvent()
                if event == "mouse_click" and periphName == nil and button == 1 and clickX >= screenX and clickX <
                    screenX + #text + 2 and clickY == screenY then
                    -- Initiate a click action (but don't trigger until mouse up).
                    buttonDown = true
                    -- Redraw the button with the clicked background color.
                    win.setCursorPos(x, y)
                    win.setBackgroundColor(clickedColor)
                    win.setTextColor(fgColor)
                    win.write(" " .. text .. " ")
                elseif (event == "monitor_touch" and periphName == button and clickX >= screenX and clickX < screenX +
                        #text + 2 and clickY == screenY) or (event == "mouse_up" and button == 1 and buttonDown) then
                    -- Finish a click event.
                    if clickX >= screenX and clickX < screenX + #text + 2 and clickY == screenY then
                        -- Trigger the action.
                        if type(action) == "string" then
                            PrimeUI.resolve("button", action)
                        else
                            action()
                        end
                    end
                    -- Redraw the original button state.
                    win.setCursorPos(x, y)
                    win.setBackgroundColor(bgColor)
                    win.setTextColor(fgColor)
                    win.write(" " .. text .. " ")
                end
            end
        end)
    end

    --- Draws a line of text, centering it inside a box horizontally.
    ---@param win window The window to draw on
    ---@param x number The X position of the left side of the box
    ---@param y number The Y position of the box
    ---@param width number The width of the box to draw in
    ---@param text string The text to draw
    ---@param fgColor color|nil The color of the text (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    function PrimeUI.centerLabel(win, x, y, width, text, fgColor, bgColor)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, width, "number")
        expect(5, text, "string")
        fgColor = expect(6, fgColor, "number", "nil") or colors.white
        bgColor = expect(7, bgColor, "number", "nil") or colors.black
        assert(#text <= width, "string is too long")
        win.setCursorPos(x + math.floor((width - #text) / 2), y)
        win.setTextColor(fgColor)
        win.setBackgroundColor(bgColor)
        win.write(text)
    end

    --- Draws a horizontal line at a position with the specified width.
    ---@param win window The window to draw on
    ---@param x number The X position of the left side of the line
    ---@param y number The Y position of the line
    ---@param width number The width/length of the line
    ---@param fgColor color|nil The color of the line (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    function PrimeUI.horizontalLine(win, x, y, width, fgColor, bgColor)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, width, "number")
        fgColor = expect(5, fgColor, "number", "nil") or colors.white
        bgColor = expect(6, bgColor, "number", "nil") or colors.black
        -- Use drawing characters to draw a thin line.
        win.setCursorPos(x, y)
        win.setTextColor(fgColor)
        win.setBackgroundColor(bgColor)
        win.write(("\x8C"):rep(width))
    end

    --- Runs a function or action repeatedly after a specified time period until canceled.
    --- If a function is passed as an action, it may return a number to change the
    --- period, or `false` to stop it.
    ---@param time number The amount of time to wait for each time, in seconds
    ---@param action function|string The function to call when the timer completes, or a `run` event to send
    ---@return function cancel A function to cancel the timer
    function PrimeUI.interval(time, action)
        expect(1, time, "number")
        expect(2, action, "function", "string")
        -- Start the timer.
        local timer = os.startTimer(time)
        -- Add a task to wait for the timer.
        PrimeUI.addTask(function()
            while true do
                -- Wait for a timer event.
                local _, tm = os.pullEvent("timer")
                if tm == timer then
                    -- Fire the timer action.
                    local res
                    if type(action) == "string" then
                        PrimeUI.resolve("timeout", action)
                    else
                        res = action()
                    end
                    -- Check the return value and adjust time accordingly.
                    if type(res) == "number" then
                        time = res
                    end
                    -- Set a new timer if not canceled.
                    if res ~= false then
                        timer = os.startTimer(time)
                    end
                end
            end
        end)
        -- Return a function to cancel the timer.
        return function()
            os.cancelTimer(timer)
        end
    end

    --- Adds an action to trigger when a key is pressed.
    ---@param key key The key to trigger on, from `keys.*`
    ---@param action function|string A function to call when clicked, or a string to use as a key for a `run` return event
    function PrimeUI.keyAction(key, action)
        expect(1, key, "number")
        expect(2, action, "function", "string")
        PrimeUI.addTask(function()
            while true do
                local _, param1 = os.pullEvent("key") -- wait for key
                if param1 == key then
                    if type(action) == "string" then
                        PrimeUI.resolve("keyAction", action)
                    else
                        action()
                    end
                end
            end
        end)
    end

    --- Draws a line of text at a position.
    ---@param win window The window to draw on
    ---@param x number The X position of the left side of the text
    ---@param y number The Y position of the text
    ---@param text string The text to draw
    ---@param fgColor color|nil The color of the text (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    function PrimeUI.label(win, x, y, text, fgColor, bgColor)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, text, "string")
        fgColor = expect(5, fgColor, "number", "nil") or colors.white
        bgColor = expect(6, bgColor, "number", "nil") or colors.black
        win.setCursorPos(x, y)
        win.setTextColor(fgColor)
        win.setBackgroundColor(bgColor)
        win.write(text)
    end

    --- Creates a progress bar, which can be updated by calling the returned function.
    ---@param win window The window to draw on
    ---@param x number The X position of the left side of the bar
    ---@param y number The Y position of the bar
    ---@param width number The width of the bar
    ---@param fgColor color|nil The color of the activated part of the bar (defaults to white)
    ---@param bgColor color|nil The color of the inactive part of the bar (defaults to black)
    ---@param useShade boolean|nil Whether to use shaded areas for the inactive part (defaults to false)
    ---@return function redraw A function to call to update the progress of the bar, taking a number from 0.0 to 1.0
    function PrimeUI.progressBar(win, x, y, width, fgColor, bgColor, useShade)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, width, "number")
        fgColor = expect(5, fgColor, "number", "nil") or colors.white
        bgColor = expect(6, bgColor, "number", "nil") or colors.black
        expect(7, useShade, "boolean", "nil")
        local function redraw(progress)
            expect(1, progress, "number")
            if progress < 0 or progress > 1 then
                error("bad argument #1 (value out of range)", 2)
            end
            -- Draw the active part of the bar.
            win.setCursorPos(x, y)
            win.setBackgroundColor(bgColor)
            win.setBackgroundColor(fgColor)
            win.write((" "):rep(math.floor(progress * width)))
            -- Draw the inactive part of the bar, using shade if desired.
            win.setBackgroundColor(bgColor)
            win.setTextColor(fgColor)
            win.write((useShade and "\x7F" or " "):rep(width - math.floor(progress * width)))
        end
        redraw(0)
        return redraw
    end

    --- Creates a list of entries that can each be selected.
    ---@param win window The window to draw on
    ---@param x number The X coordinate of the inside of the box
    ---@param y number The Y coordinate of the inside of the box
    ---@param width number The width of the inner box
    ---@param height number The height of the inner box
    ---@param entries string[] A list of entries to show, where the value is whether the item is pre-selected (or `"R"` for required/forced selected)
    ---@param action function|string A function or `run` event that's called when a selection is made
    ---@param selectChangeAction function|string|nil A function or `run` event that's called when the current selection is changed
    ---@param fgColor color|nil The color of the text (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    function PrimeUI.selectionBox(win, x, y, width, height, entries, action, selectChangeAction, fgColor, bgColor)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, width, "number")
        expect(5, height, "number")
        expect(6, entries, "table")
        expect(7, action, "function", "string")
        expect(8, selectChangeAction, "function", "string", "nil")
        fgColor = expect(9, fgColor, "number", "nil") or colors.white
        bgColor = expect(10, bgColor, "number", "nil") or colors.black
        -- Check that all entries are strings.
        if #entries == 0 then
            error("bad argument #6 (table must not be empty)", 2)
        end
        for i, v in ipairs(entries) do
            if type(v) ~= "string" then
                error("bad item " .. i .. " in entries table (expected string, got " .. type(v), 2)
            end
        end
        -- Create container window.
        local entrywin = window.create(win, x, y, width, height)
        local selection, scroll = 1, 1
        -- Create a function to redraw the entries on screen.
        local function drawEntries()
            -- Clear and set invisible for performance.
            entrywin.setVisible(false)
            entrywin.setBackgroundColor(bgColor)
            entrywin.clear()
            -- Draw each entry in the scrolled region.
            for i = scroll, scroll + height - 1 do
                -- Get the entry; stop if there's no more.
                local e = entries[i]
                if not e then
                    break
                end
                -- Set the colors: invert if selected.
                entrywin.setCursorPos(2, i - scroll + 1)
                if i == selection then
                    entrywin.setBackgroundColor(fgColor)
                    entrywin.setTextColor(bgColor)
                else
                    entrywin.setBackgroundColor(bgColor)
                    entrywin.setTextColor(fgColor)
                end
                -- Draw the selection.
                entrywin.clearLine()
                entrywin.write(#e > width - 1 and e:sub(1, width - 4) .. "..." or e)
            end
            -- Draw scroll arrows.
            entrywin.setBackgroundColor(bgColor)
            entrywin.setTextColor(fgColor)
            entrywin.setCursorPos(width, 1)
            entrywin.write("\30")
            entrywin.setCursorPos(width, height)
            entrywin.write("\31")
            -- Send updates to the screen.
            entrywin.setVisible(true)
        end
        -- Draw first screen.
        drawEntries()
        -- Add a task for selection keys.
        PrimeUI.addTask(function()
            while true do
                local event, key, cx, cy = os.pullEvent()
                if event == "key" then
                    if key == keys.down and selection < #entries then
                        -- Move selection down.
                        selection = selection + 1
                        if selection > scroll + height - 1 then
                            scroll = scroll + 1
                        end
                        -- Send action if necessary.
                        if type(selectChangeAction) == "string" then
                            PrimeUI.resolve("selectionBox", selectChangeAction, selection)
                        elseif selectChangeAction then
                            selectChangeAction(selection)
                        end
                        -- Redraw screen.
                        drawEntries()
                    elseif key == keys.up and selection > 1 then
                        -- Move selection up.
                        selection = selection - 1
                        if selection < scroll then
                            scroll = scroll - 1
                        end
                        -- Send action if necessary.
                        if type(selectChangeAction) == "string" then
                            PrimeUI.resolve("selectionBox", selectChangeAction, selection)
                        elseif selectChangeAction then
                            selectChangeAction(selection)
                        end
                        -- Redraw screen.
                        drawEntries()
                    elseif key == keys.enter then
                        -- Select the entry: send the action.
                        if type(action) == "string" then
                            PrimeUI.resolve("selectionBox", action, entries[selection])
                        else
                            action(entries[selection])
                        end
                    end
                elseif event == "mouse_click" and key == 1 then
                    -- Handle clicking the scroll arrows.
                    local wx, wy = PrimeUI.getWindowPos(entrywin, 1, 1)
                    if cx == wx + width - 1 then
                        if cy == wy and selection > 1 then
                            -- Move selection up.
                            selection = selection - 1
                            if selection < scroll then
                                scroll = scroll - 1
                            end
                            -- Send action if necessary.
                            if type(selectChangeAction) == "string" then
                                PrimeUI.resolve("selectionBox", selectChangeAction, selection)
                            elseif selectChangeAction then
                                selectChangeAction(selection)
                            end
                            -- Redraw screen.
                            drawEntries()
                        elseif cy == wy + height - 1 and selection < #entries then
                            -- Move selection down.
                            selection = selection + 1
                            if selection > scroll + height - 1 then
                                scroll = scroll + 1
                            end
                            -- Send action if necessary.
                            if type(selectChangeAction) == "string" then
                                PrimeUI.resolve("selectionBox", selectChangeAction, selection)
                            elseif selectChangeAction then
                                selectChangeAction(selection)
                            end
                            -- Redraw screen.
                            drawEntries()
                        end
                    elseif cx >= wx and cx < wx + width - 1 and cy >= wy and cy < wy + height then
                        local sel = scroll + (cy - wy)
                        if sel == selection then
                            -- Select the entry: send the action.
                            if type(action) == "string" then
                                PrimeUI.resolve("selectionBox", action, entries[selection])
                            else
                                action(entries[selection])
                            end
                        else
                            selection = sel
                            -- Send action if necessary.
                            if type(selectChangeAction) == "string" then
                                PrimeUI.resolve("selectionBox", selectChangeAction, selection)
                            elseif selectChangeAction then
                                selectChangeAction(selection)
                            end
                            -- Redraw screen.
                            drawEntries()
                        end
                    end
                elseif event == "mouse_scroll" then
                    -- Handle mouse scrolling.
                    local wx, wy = PrimeUI.getWindowPos(entrywin, 1, 1)
                    if cx >= wx and cx < wx + width and cy >= wy and cy < wy + height then
                        if key < 0 and selection > 1 then
                            -- Move selection up.
                            selection = selection - 1
                            if selection < scroll then
                                scroll = scroll - 1
                            end
                            -- Send action if necessary.
                            if type(selectChangeAction) == "string" then
                                PrimeUI.resolve("selectionBox", selectChangeAction, selection)
                            elseif selectChangeAction then
                                selectChangeAction(selection)
                            end
                            -- Redraw screen.
                            drawEntries()
                        elseif key > 0 and selection < #entries then
                            -- Move selection down.
                            selection = selection + 1
                            if selection > scroll + height - 1 then
                                scroll = scroll + 1
                            end
                            -- Send action if necessary.
                            if type(selectChangeAction) == "string" then
                                PrimeUI.resolve("selectionBox", selectChangeAction, selection)
                            elseif selectChangeAction then
                                selectChangeAction(selection)
                            end
                            -- Redraw screen.
                            drawEntries()
                        end
                    end
                end
            end
        end)
    end

    --- Draws a block of text inside a window with word wrapping, optionally resizing the window to fit.
    ---@param win window The window to draw in
    ---@param text string The text to draw
    ---@param resizeToFit boolean|nil Whether to resize the window to fit the text (defaults to false). This is useful for scroll boxes.
    ---@param fgColor color|nil The color of the text (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    ---@return number lines The total number of lines drawn
    function PrimeUI.drawText(win, text, resizeToFit, fgColor, bgColor)
        expect(1, win, "table")
        expect(2, text, "string")
        expect(3, resizeToFit, "boolean", "nil")
        fgColor = expect(4, fgColor, "number", "nil") or colors.white
        bgColor = expect(5, bgColor, "number", "nil") or colors.black
        -- Set colors.
        win.setBackgroundColor(bgColor)
        win.setTextColor(fgColor)
        -- Redirect to the window to use print on it.
        local old = term.redirect(win)
        -- Draw the text using print().
        local lines = print(text)
        -- Redirect back to the original terminal.
        term.redirect(old)
        -- Resize the window if desired.
        if resizeToFit then
            -- Get original parameters.
            local x, y = win.getPosition()
            local w = win.getSize()
            -- Resize the window.
            win.reposition(x, y, w, lines)
        end
        return lines
    end

    --- Creates a text box that wraps text and can have its text modified later.
    ---@param win window The parent window of the text box
    ---@param x number The X position of the box
    ---@param y number The Y position of the box
    ---@param width number The width of the box
    ---@param height number The height of the box
    ---@param text string The initial text to draw
    ---@param fgColor color|nil The color of the text (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    ---@return function redraw A function to redraw the window with new contents
    function PrimeUI.textBox(win, x, y, width, height, text, fgColor, bgColor)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, width, "number")
        expect(5, height, "number")
        expect(6, text, "string")
        fgColor = expect(7, fgColor, "number", "nil") or colors.white
        bgColor = expect(8, bgColor, "number", "nil") or colors.black
        -- Create the box window.
        local box = window.create(win, x, y, width, height)
        -- Override box.getSize to make print not scroll.
        function box.getSize()
            return width, math.huge
        end

        -- Define a function to redraw with.
        local function redraw(_text)
            expect(1, _text, "string")
            -- Set window parameters.
            box.setBackgroundColor(bgColor)
            box.setTextColor(fgColor)
            box.clear()
            box.setCursorPos(1, 1)
            -- Redirect and draw with `print`.
            local old = term.redirect(box)
            print(_text)
            term.redirect(old)
        end
        redraw(text)
        return redraw
    end

    --- Creates a scrollable window, which allows drawing large content in a small area.
    ---@param win window The parent window of the scroll box
    ---@param x number The X position of the box
    ---@param y number The Y position of the box
    ---@param width number The width of the box
    ---@param height number The height of the outer box
    ---@param innerHeight number The height of the inner scroll area
    ---@param allowArrowKeys boolean|nil Whether to allow arrow keys to scroll the box (defaults to true)
    ---@param showScrollIndicators boolean|nil Whether to show arrow indicators on the right side when scrolling is available, which reduces the inner width by 1 (defaults to false)
    ---@param fgColor number|nil The color of scroll indicators (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    ---@return window inner The inner window to draw inside
    ---@return fun(pos:number) scroll A function to manually set the scroll position of the window
    function PrimeUI.scrollBox(win, x, y, width, height, innerHeight, allowArrowKeys, showScrollIndicators, fgColor,
                               bgColor)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, width, "number")
        expect(5, height, "number")
        expect(6, innerHeight, "number")
        expect(7, allowArrowKeys, "boolean", "nil")
        expect(8, showScrollIndicators, "boolean", "nil")
        fgColor = expect(9, fgColor, "number", "nil") or colors.white
        bgColor = expect(10, bgColor, "number", "nil") or colors.black
        if allowArrowKeys == nil then
            allowArrowKeys = true
        end
        -- Create the outer container box.
        local outer = window.create(win == term and term.current() or win, x, y, width, height)
        outer.setBackgroundColor(bgColor)
        outer.clear()
        -- Create the inner scrolling box.
        local inner = window.create(outer, 1, 1, width - (showScrollIndicators and 1 or 0), innerHeight)
        inner.setBackgroundColor(bgColor)
        inner.clear()
        -- Draw scroll indicators if desired.
        if showScrollIndicators then
            outer.setBackgroundColor(bgColor)
            outer.setTextColor(fgColor)
            outer.setCursorPos(width, height)
            outer.write(innerHeight > height and "\31" or " ")
        end
        -- Get the absolute position of the window.
        x, y = PrimeUI.getWindowPos(win, x, y)
        -- Add the scroll handler.
        local scrollPos = 1
        PrimeUI.addTask(function()
            while true do
                -- Wait for next event.
                local ev = table.pack(os.pullEvent())
                -- Update inner height in case it changed.
                innerHeight = select(2, inner.getSize())
                -- Check for scroll events and set direction.
                local dir
                if ev[1] == "key" and allowArrowKeys then
                    if ev[2] == keys.up then
                        dir = -1
                    elseif ev[2] == keys.down then
                        dir = 1
                    end
                elseif ev[1] == "mouse_scroll" and ev[3] >= x and ev[3] < x + width and ev[4] >= y and ev[4] < y +
                    height then
                    dir = ev[2]
                end
                -- If there's a scroll event, move the window vertically.
                if dir and (scrollPos + dir >= 1 and scrollPos + dir <= innerHeight - height) then
                    scrollPos = scrollPos + dir
                    inner.reposition(1, 2 - scrollPos)
                end
                -- Redraw scroll indicators if desired.
                if showScrollIndicators then
                    outer.setBackgroundColor(bgColor)
                    outer.setTextColor(fgColor)
                    outer.setCursorPos(width, 1)
                    outer.write(scrollPos > 1 and "\30" or " ")
                    outer.setCursorPos(width, height)
                    outer.write(scrollPos < innerHeight - height and "\31" or " ")
                end
            end
        end)
        -- Make a function to allow external scrolling.
        local function scroll(pos)
            expect(1, pos, "number")
            pos = math.floor(pos)
            expect.range(pos, 1, innerHeight - height)
            -- Scroll the window.
            scrollPos = pos
            inner.reposition(1, 2 - scrollPos)
            -- Redraw scroll indicators if desired.
            if showScrollIndicators then
                outer.setBackgroundColor(bgColor)
                outer.setTextColor(fgColor)
                outer.setCursorPos(width, 1)
                outer.write(scrollPos > 1 and "\30" or " ")
                outer.setCursorPos(width, height)
                outer.write(scrollPos < innerHeight - height and "\31" or " ")
            end
        end
        return inner, scroll
    end

    --- Creates a text input box.
    ---@param win window The window to draw on
    ---@param x number The X position of the left side of the box
    ---@param y number The Y position of the box
    ---@param width number The width/length of the box
    ---@param action function|string A function or `run` event to call when the enter key is pressed
    ---@param fgColor color|nil The color of the text (defaults to white)
    ---@param bgColor color|nil The color of the background (defaults to black)
    ---@param replacement string|nil A character to replace typed characters with
    ---@param history string[]|nil A list of previous entries to provide
    ---@param completion function|nil A function to call to provide completion
    ---@param default string|nil A string to return if the box is empty
    function PrimeUI.inputBox(win, x, y, width, action, fgColor, bgColor, replacement, history, completion, default)
        expect(1, win, "table")
        expect(2, x, "number")
        expect(3, y, "number")
        expect(4, width, "number")
        expect(5, action, "function", "string")
        fgColor = expect(6, fgColor, "number", "nil") or colors.white
        bgColor = expect(7, bgColor, "number", "nil") or colors.black
        expect(8, replacement, "string", "nil")
        expect(9, history, "table", "nil")
        expect(10, completion, "function", "nil")
        expect(11, default, "string", "nil")
        -- Create a window to draw the input in.
        local box = window.create(win, x, y, width, 1)
        box.setTextColor(fgColor)
        box.setBackgroundColor(bgColor)
        box.clear()
        -- Call read() in a new coroutine.
        PrimeUI.addTask(function()
            -- We need a child coroutine to be able to redirect back to the window.
            local coro = coroutine.create(read)
            -- Run the function for the first time, redirecting to the window.
            local old = term.redirect(box)
            local ok, res = coroutine.resume(coro, replacement, history, completion, default)
            term.redirect(old)
            -- Run the coroutine until it finishes.
            while coroutine.status(coro) ~= "dead" do
                -- Get the next event.
                local ev = table.pack(os.pullEvent())
                -- Redirect and resume.
                old = term.redirect(box)
                ok, res = coroutine.resume(coro, table.unpack(ev, 1, ev.n))
                term.redirect(old)
                -- Pass any errors along.
                if not ok then
                    error(res)
                end
            end
            -- Send the result to the receiver.
            if type(action) == "string" then
                PrimeUI.resolve("inputBox", action, res)
            else
                action(res)
            end
            -- Spin forever, because tasks cannot exit.
            while true do
                os.pullEvent()
            end
        end)
    end

    return PrimeUI
end)()

local Cache = {}

-- when something with Cache as its metatable is missing a key, look inside Cache
Cache.__index = Cache

function Cache.new(defaultTTL)
    local self = setmetatable({}, Cache)
    self.store = {}
    -- TTL is "time to live" or how long until stale
    self.defaultTTL = defaultTTL or 60 -- Default TTL in seconds
    self.events = {
        hit = {},
        miss = {},
        set = {},
        invalidate = {}
    }
    return self
end

-- Event handling
function Cache:on(event, callback)
    if self.events[event] then
        table.insert(self.events[event], callback)
        return true
    end
    return false
end

function Cache:emit(event, ...)
    if self.events[event] then
        for _, callback in ipairs(self.events[event]) do
            callback(...)
        end
    end
end

-- Core cache methods
function Cache:get(key)
    local entry = self.store[key]

    if not entry then
        self:emit("miss", key)
        return nil
    end

    -- Check expiration
    if entry.expires and os.epoch("utc") > entry.expires then
        self.store[key] = nil
        self:emit("invalidate", key, "expired")
        return nil
    end

    entry.hits = entry.hits + 1
    self:emit("hit", key, entry.hits)
    return entry.value
end

function Cache:set(key, value, ttl)
    local expires = nil
    if ttl or self.defaultTTL then
        expires = os.epoch("utc") + ((ttl or self.defaultTTL) * 1000)
    end

    self.store[key] = {
        value = value,
        expires = expires,
        created = os.epoch("utc"),
        hits = 0
    }

    self:emit("set", key, value)
    return true
end

function Cache:invalidate(key)
    if self.store[key] then
        self.store[key] = nil
        self:emit("invalidate", key, "manual")
        return true
    end
    return false
end

function Cache:clear()
    self.store = {}
    self:emit("invalidate", "*", "clear")
end

-- Cache information and statistics
function Cache:getStats()
    local stats = {
        entries = 0,
        hits = 0,
        expired = 0,
        memory = 0 -- Rough approximation
    }

    for key, entry in pairs(self.store) do
        stats.entries = stats.entries + 1
        stats.hits = stats.hits + entry.hits
        if entry.expires and os.epoch("utc") > entry.expires then
            stats.expired = stats.expired + 1
        end
        -- Rough memory estimation
        stats.memory = stats.memory + #key + 100 -- 100 bytes overhead per entry (approximation)
    end

    return stats
end

-- ** VERSION COMPARE ** --

local VersionCompare = {}

-- Pre-release identifiers ordered by precedence
VersionCompare.PRE_RELEASE_ORDER = {
    ["alpha"] = 1,
    ["beta"] = 2,
    ["rc"] = 3
}

function VersionCompare.parse(version)
    expect(1, version, "string")

    local major, minor, patch, preRelease = version:match("^(%d+)%.?(%d*)%.?(%d*)%-?([%w]*)$")
    if not major then
        return nil
    end

    return {
        major = tonumber(major) or 0,
        minor = tonumber(minor) or 0,
        patch = tonumber(patch) or 0,
        preRelease = preRelease ~= "" and preRelease or nil
    }
end

--- Compares two version strings (semver) and returns the result in integer form
---@param v1 string: version 1
---@param v2 string: version 2
---@return number|nil: Returns 1 if version 1 is newer, 0 if versions are equal, and -1 if version 1 is behind version 2. Returns nil if missing version.
function VersionCompare.compare(v1, v2)
    local p1, p2 = VersionCompare.parse(v1), VersionCompare.parse(v2)
    if not p1 or not p2 then
        return nil
    end

    -- Compare major.minor.patch
    local nums = { "major", "minor", "patch" }
    for _, num in ipairs(nums) do
        if p1[num] ~= p2[num] then
            return p1[num] > p2[num] and 1 or -1
        end
    end

    -- If equal, compare pre-release
    if p1.preRelease == p2.preRelease then
        return 0
    end
    if not p1.preRelease and p2.preRelease then
        return 1
    end
    if p1.preRelease and not p2.preRelease then
        return -1
    end

    local pre1 = VersionCompare.PRE_RELEASE_ORDER[p1.preRelease] or 0
    local pre2 = VersionCompare.PRE_RELEASE_ORDER[p2.preRelease] or 0
    return pre1 == pre2 and 0 or (pre1 > pre2 and 1 or -1)
end

local function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

local function writeWrappedText(window, text, startX, startY, width)
    local function wrapText(str, lineWidth)
        local lines = {}
        local line = ""
        local spaceLeft = lineWidth

        for word in str:gmatch("%S+") do
            if #word + 1 > spaceLeft then
                -- Line is full, start new line
                table.insert(lines, line)
                line = word
                spaceLeft = lineWidth - #word
            else
                -- Add word to line
                if line ~= "" then
                    line = line .. " " .. word
                    spaceLeft = spaceLeft - (#word + 1)
                else
                    line = word
                    spaceLeft = spaceLeft - #word
                end
            end
        end

        -- Add the last line if there's anything left
        if line ~= "" then
            table.insert(lines, line)
        end

        return lines
    end

    local lines = wrapText(text, width)
    local cy = startY

    for _, line in ipairs(lines) do
        window.setCursorPos(startX, cy)
        window.write(line)
        cy = cy + 1
    end

    return cy -- Return the next Y position
end

-- Helper function to map over tables
function table.map(t, fn)
    local result = {}
    for k, v in pairs(t) do
        result[k] = fn(v)
    end
    return result
end

local Installer = {
    VERSION = "1.0.0",
    PROGRAM_REGISTRY_URL = "https://raw.githubusercontent.com/bngarren/computer-craft/master/registry.json",
    BASE_PATH = "/bng",
    CONFIG_PATH = "/.bng-config",
    LOG_PATH = "/bng/installer.log",

    LOG_LEVELS = {
        DEBUG = "DEBUG",
        INFO = "INFO",
        WARN = "WARN",
        ERROR = "ERROR"
    },

    MAIN_MENU = {
        options = {
            INSTALL_PROGRAM = "INSTALL_PROGRAM",
            MANAGE_PROGRAMS = "MANAGE_PROGRAMS",
            UPDATE_COMMON = "UPDATE_COMMON",
            REMOVE_ALL = "REMOVE_ALL",
            EXIT = "EXIT"
        },
        -- Add an order array to maintain specific menu ordering
        order = { "INSTALL_PROGRAM", "MANAGE_PROGRAMS", "UPDATE_COMMON", "REMOVE_ALL", "EXIT" },
        display = {
            INSTALL_PROGRAM = {
                text = "Install New Program",
                description = "Browse and install available BNG programs"
            },
            MANAGE_PROGRAMS = {
                text = "Manage Installed Programs",
                description = "View, update, or remove installed programs"
            },
            UPDATE_COMMON = {
                text = "Update Common Modules",
                description = "Change individual library/dependency to another version"
            },
            REMOVE_ALL = {
                text = "Remove All",
                description = "Remove all bng installed scripts and artifacts"
            },
            EXIT = {
                text = "Exit",
                description = "Exit the installer"
            }
        }
    },

    debug = true,

    boxSizing = {
        mainPadding = 2
    }
}

function Installer:initLogger()
    -- Ensure log directory exists
    local logDir = fs.getDir(self.LOG_PATH)
    if not fs.exists(logDir) then
        fs.makeDir(logDir)
    end

    -- Open log file with w+ (always overwrites file on each run)
    local logFile = fs.open(self.LOG_PATH, "w+")
    -- close previous log file, if needed
    if self.logFile then
        self.logFile.close()
    end
    self.logFile = logFile
    if not logFile then
        error(string.format("Failed to open log file: %s", self.LOG_PATH))
    end

    -- Create log functions for each level
    self.log = {}
    local debugEnabled = self.debug

    -- Add stack trace to error logs
    local function getStackTrace()
        local trace = {}
        for i = 3, 6 do
            local info = debug.getinfo(i)
            if not info then
                break
            end
            table.insert(trace, string.format("%s:%d", info.short_src, info.currentline))
        end
        return table.concat(trace, " <- ")
    end

    for level, levelName in pairs(self.LOG_LEVELS) do
        self.log[level:lower()] = function(msg, ...)
            if level == "DEBUG" and not debugEnabled then
                return
            end

            local formatted = string.format(msg, ...)
            local timestamp = os.date("[%Y-%m-%d %H:%M:%S]")
            local entry = string.format("%s [%s] %s", timestamp, levelName, formatted)

            if level == "ERROR" then
                entry = entry .. "\nStack: " .. getStackTrace()
            end
            logFile.writeLine(entry)
            logFile.flush()
        end
    end
end

function Installer:closeLogger()
    if self.logFile then
        self.logFile.close()
        self.logFile = nil
    end
end

function Installer:initCache()
    -- Initialize cache with 60 second TTL
    self.cache = Cache.new(60)

    -- Add cache event handlers
    self.cache:on("hit", function(key, hits)
        self.log.debug("Cache hit for '%s' (hits: %d)", key, hits)
    end)

    self.cache:on("miss", function(key)
        self.log.debug("Cache miss for '%s'", key)
    end)

    self.cache:on("set", function(key)
        self.log.debug("Cache set for '%s'", key)
    end)

    self.cache:on("invalidate", function(key, reason)
        self.log.debug("Cache invalidated for '%s' (%s)", key, reason)
    end)
end

function Installer:init()
    self:initLogger()

    self.log.info("Initializing installer v%s", self.VERSION)

    self:initCache()

    local termW, termH = term.getSize()
    self.boxSizing.contentBox = termW - self.boxSizing.mainPadding * 2 + 1
    self.boxSizing.borderBox = self.boxSizing.contentBox - 1

    self.COMMON_PATH = self.BASE_PATH .. "/common"
    self.PROGRAMS_PATH = self.BASE_PATH .. "/programs"

    -- Create base directories
    fs.makeDir(self.PROGRAMS_PATH)
    fs.makeDir(self.COMMON_PATH)

    -- init Main Menu
    -- Generate the ordered items list using the order array
    self.MAIN_MENU.items = {}
    for _, id in ipairs(self.MAIN_MENU.order) do
        table.insert(self.MAIN_MENU.items, {
            id = id,
            text = self.MAIN_MENU.display[id].text,
            description = self.MAIN_MENU.display[id].description
        })
    end
end

function Installer:httpGet(url, retries)
    expect(1, url, "string")
    expect(2, retries, "number", "nil")

    retries = retries or 3
    local attempt = 1

    while attempt <= retries do
        self.log.debug("HTTP GET %s (attempt %d/%d)", url, attempt, retries)

        local success, response = pcall(http.get, url)
        if success and response then
            return response
        end

        self.log.warn("Request failed, retrying in %d seconds", attempt)
        sleep(attempt)
        attempt = attempt + 1
    end

    return nil, "Failed after " .. retries .. " attempts"
end

function Installer:loadConfig()
    -- Try to get from cache first
    local cached = self.cache:get("config")
    if cached then
        return cached
    end

    local config = {
        installedPrograms = {},
        installedDependencies = {}
    }

    if fs.exists(self.CONFIG_PATH) then
        local file = fs.open(self.CONFIG_PATH, "r")
        if file then
            local content = file.readAll()
            file.close()

            local loaded = textutils.unserializeJSON(content)
            if loaded then
                -- Merge with defaults preserving structure
                for k, v in pairs(loaded) do
                    if type(v) == "table" then
                        config[k] = config[k] or {}
                        for sk, sv in pairs(v) do
                            config[k][sk] = sv
                        end
                    else
                        config[k] = v
                    end
                end
            end
        end
    else
        self.log.warn("No .bng-config file exists yet...Initializing default at %s", self.CONFIG_PATH)
        self:saveConfig(config)
    end
    -- Cache the config
    self.cache:set("config", config)

    return config
end

function Installer:saveConfig(config)
    expect(1, config, "table")

    local file = fs.open(self.CONFIG_PATH, "w")
    file.write(textutils.serializeJSON(config))
    file.close()

    -- Invalidate the config cache since we just wrote new data
    self.cache:invalidate("config")

    -- Immediately update the cache with the new data
    self.cache:set("config", config)
end

function Installer:getInstalledPrograms()
    local bngConfig = self:loadConfig()
    local installedPrograms = {}
    for k, v in pairs(bngConfig.installedPrograms) do
        table.insert(installedPrograms, k)
    end
    return installedPrograms
end

--- Gets the registry.json file from the programs repo. This file lists the available programs and their version info, dependencies, etc.
--- @return table|nil registry Lua table containing the registry data
function Installer:fetchRegistry()
    -- Try to get from cache first
    local cached = self.cache:get("registry")
    if cached then
        return cached
    end

    -- On cache miss, fetch from network
    local response = self:httpGet(self.PROGRAM_REGISTRY_URL)
    if not response then
        self.log.error("Failed to download registry")
        return nil
    end

    local content = response.readAll()
    response.close()

    local registry = textutils.unserializeJSON(content)
    if registry then
        -- Cache successful response
        self.cache:set("registry", registry)
    end

    return registry
end

function Installer:writeFile(path, content)
    expect(1, path, "string")
    expect(2, content, "string")

    local dir = fs.getDir(path)
    if not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local file = fs.open(path, "w")
    if file then
        file.write(content)
        file.close()
        self.log.debug("File written: %s", path)
    else
        self.log.error("Failed to write file: %s", path)
    end
end

function Installer:downloadFile(url, path, currentProgress)
    expect(1, url, "string")
    expect(2, path, "string")
    expect(3, currentProgress, "function", "nil")

    local response = self:httpGet(url)
    if not response then
        error("Failed to download: " .. url)
    end

    local content = response.readAll()
    response.close()

    self:writeFile(path, content)

    if currentProgress then
        currentProgress()
    end

    return true
end

function Installer:getInstalledCoreModules()
    local installedModules = {}
    local corePath = self.COMMON_PATH .. "/bng-cc-core"

    if fs.exists(corePath) then
        for _, file in ipairs(fs.list(corePath)) do
            -- Extract module name from filename (remove .lua extension)
            local moduleName = string.match(file, "(.+)%.lua$")
            if moduleName then
                table.insert(installedModules, moduleName)
            end
        end
    end
    self.log.debug("Installed core modules: %s", dump(installedModules))
    return installedModules
end

function Installer:checkCoreRequirements(program)
    self.log.debug("Checking core requirements for %s", program.name)

    expect(1, program, "table")

    -- Check if core is installed at correct version
    local config = self:loadConfig()
    local requiredVersion = program.core.version
    local requiredModules = program.core.modules

    -- If dev version is installed, consider it compatible with everything
    if config.core.version == "dev" then
        self.log.debug("Dev version installed, considering compatible")
    else
        -- Else do a Version check
        if not config.core.version or self.compareVersions(config.core.version, requiredVersion) ~= 0 then
            local message = string.format("Core library v%s required (current: %s)", requiredVersion,
                config.core.version or "none")
            self.log.info(message)
            return false, message
        end
    end

    -- Get installed modules by scanning directory
    local installedModules = self:getInstalledCoreModules()

    local missingModules = {}

    for _, module in ipairs(requiredModules) do
        local found = false
        for _, installedModule in ipairs(installedModules) do
            if module == installedModule then
                found = true
                break
            end
        end
        if not found then
            table.insert(missingModules, module)
        end
    end

    if #missingModules > 0 then
        local message = "Missing core module(s): "
        for _, m in ipairs(missingModules) do
            message = message .. "[" .. m .. "] "
        end
        self.log.info(message)
        return false, message
    end

    self.log.debug("All core requirements met")
    return true
end

function Installer.compareVersions(v1, v2)
    return VersionCompare.compare(v1, v2)
end

function Installer:constructCoreUrl(version)
    expect(1, version, "string")

    if version == "dev" then
        return "https://raw.githubusercontent.com/bngarren/bng-cc-core/dev/src"
    else
        return string.format("https://raw.githubusercontent.com/bngarren/bng-cc-core/refs/tags/v%s/src", version)
    end
end

--- When updating/installing bng-cc-core, we need to know the minimum required version of the core library to satisfy the programs currently installed on the machine, including any program about to be installed (which is why we allow passing additional_versions parameters)
---@param ... string: Additional versions to include in the comparisons
---@return string|nil: The minimum version (most recent semver) or nil if comparison cannot be performed
function Installer:getMinimumCoreVersion(...)
    local additional_versions = { ... }

    local installedPrograms = self:getInstalledPrograms()
    if #installedPrograms < 1 and #additional_versions < 1 then
        self.log.warn(
            "Cannot get minimum core version when no programs are installed and there are no additional versions to test")
        return nil
    end

    local registry = self:fetchRegistry()
    if not registry or #registry.programs == 0 then
        return nil
    end

    local minCoreVersion
    for _, programName in ipairs(installedPrograms) do
        for _, registryProgram in ipairs(registry.programs) do
            if registryProgram.name == programName then
                local version = registryProgram.core.version
                self.log.debug("%s requires bng-cc-core v%s", programName, version)

                if not minCoreVersion or self.compareVersions(version, minCoreVersion) >= 0 then
                    minCoreVersion = version
                    self.log.debug("Minimum core version updated to v%s", minCoreVersion)
                end
                break
            end
        end
    end

    -- test the additional_versions
    for _, add_version in ipairs(additional_versions) do
        if not minCoreVersion or self.compareVersions(add_version, minCoreVersion) then
            minCoreVersion = add_version
            self.log.debug("Minimum core version updated to v%s (due to additional tested version)", minCoreVersion)
        end
    end

    return minCoreVersion
end

function Installer:installCore(version, modules)
    expect(1, version, "string")
    expect(2, modules, "table", "nil")

    local currentTerm = term.current()
    local progress = ui.progressBar(currentTerm, self.boxSizing.mainPadding, 8, self.boxSizing.contentBox, nil, nil,
        true)
    local statusBox = ui.textBox(currentTerm, self.boxSizing.mainPadding, 6, self.boxSizing.contentBox, 1,
        "Installing core...")

    -- Construct correct URL based on version
    local coreBaseUrl = self:constructCoreUrl(version)

    self.log.info("Installing bng-cc-core v%s from %s", version, coreBaseUrl)

    -- Track steps for progress bar
    local totalSteps
    local currentStep = 0

    local modulesToInstall = {}

    if modules and #modules > 0 then
        totalSteps = #modules
        modulesToInstall = modules
    else
        -- Re-download all existing modules
        local existingModules = self:getInstalledCoreModules()
        totalSteps = #existingModules
        modulesToInstall = existingModules
        self.log.debug("Re-installing core modules: %s", dump(existingModules))
    end

    -- Create/clean core directory
    local corePath = self.BASE_PATH .. "/common/bng-cc-core"
    if fs.exists(corePath) then
        fs.delete(corePath)
    end
    fs.makeDir(corePath)

    -- Download each required module
    for _, moduleName in ipairs(modulesToInstall) do
        statusBox("Downloading core module: " .. moduleName)

        local moduleUrl = string.format("%s/%s.lua", coreBaseUrl, moduleName)
        self:downloadFile(moduleUrl, string.format("%s/common/bng-cc-core/%s.lua", self.BASE_PATH, moduleName),
            function()
                currentStep = currentStep + 1
                progress(currentStep / totalSteps)
            end)
    end

    -- Update config with core details
    local config = self:loadConfig()
    config.core = {
        version = version,
        installedAt = os.epoch("utc")
    }
    self:saveConfig(config)

    self.log.info("Core installation complete")
end

function Installer:getTempPath()
    -- Create a unique temp directory for this operation
    local tempDir = string.format("%s/.temp/%d", self.BASE_PATH, os.epoch("utc"))
    fs.makeDir(tempDir)
    return tempDir
end

function Installer:installDependency(dep, progressCallback)
    expect(1, dep, "table")
    expect(2, progressCallback, "function", "nil")

    -- Validate dependency schema
    assert(dep.name, "Dependency must have a name")
    assert(dep.version, "Dependency must have a version")
    assert(dep.source, "Dependency must have source info")
    assert(dep.source.type, "Dependency source must have type")

    local tempPath = self:getTempPath()
    local tempDepPath = fs.combine(tempPath, dep.name)
    local finalDepPath = self.COMMON_PATH .. "/" .. dep.name

    local config = self:loadConfig()
    config.installedDependencies = config.installedDependencies or {}

    -- Helper function to verify all required files exist
    local function verifyFiles(path)
        for _, file in ipairs(dep.source.files) do
            local filePath = fs.combine(path, file.target)
            if not fs.exists(filePath) then
                return false
            end
        end
        return true
    end

    -- Helper function to download files
    local function downloadFiles()
        fs.makeDir(tempDepPath)
        local totalFiles = #dep.source.files

        for i, file in ipairs(dep.source.files) do
            local url = string.format("https://github.com/%s/%s/releases/download/v%s/%s", dep.source.owner,
                dep.source.repo, dep.version, file.source)
            local targetPath = fs.combine(tempDepPath, file.target)

            -- Ensure target directory exists
            fs.makeDir(fs.getDir(targetPath))

            self.log.debug("Downloading %s to %s", url, targetPath)
            local success = self:downloadFile(url, targetPath)
            if not success then
                return false
            end

            if progressCallback then
                progressCallback(i / totalFiles)
            end
        end
        return true
    end

    local ok, result = pcall(function()
        -- Check existing installation scenarios
        if fs.exists(finalDepPath) then
            self.log.debug("%s already has a dir in %s", dep.name, self.COMMON_PATH)
            local installedDep = config.installedDependencies[dep.name]

            if installedDep then
                if installedDep.version == dep.version then
                    -- Same version - verify files and handle missing
                    if verifyFiles(finalDepPath) then
                        -- All files present - ask about overwrite
                        local result = self:showYesNoDialogView({
                            title = "Dependency Already Installed",
                            message = string.format("%s v%s is already installed.\nWould you like to reinstall it?",
                                dep.name, dep.version)
                        })
                        if result == "no" then
                            return true
                        end
                    end
                else
                    -- Different version - warn about existing programs
                    local result = self:showYesNoDialogView({
                        title = "Version Conflict",
                        message = string.format("Warning: %s v%s is already installed but v%s is required.\n" ..
                            "This may affect other installed programs.\n" ..
                            "Continue with installation?", dep.name, installedDep.version,
                            dep.version)
                    })
                    if result == "no" then
                        return false
                    end
                end
            else
                -- Directory exists but no config entry
                local files = fs.list(finalDepPath)
                local fileCount = #files

                local result = self:showYesNoDialogView({
                    title = "Untracked Installation",
                    message = string.format("Found untracked installation of %s (%d files).\n" ..
                        "Would you like to overwrite it with v%s?", dep.name, fileCount,
                        dep.version)
                })
                if result == "no" then
                    return false
                end
            end
        end

        -- Download files
        if not downloadFiles() then
            return false
        end

        -- Verify downloaded files
        self.log.debug("Verifying files in temp directory: %s", tempDepPath)
        if not verifyFiles(tempDepPath) then
            error(string.format("File verification failed for %s in temp directory", dep.name))
        end

        -- Log before moving files
        self.log.debug("Moving files from %s to %s", tempDepPath, finalDepPath)

        if fs.exists(finalDepPath) then
            self.log.debug("Removing existing directory: %s", finalDepPath)
            fs.delete(finalDepPath)
        end

        -- Ensure parent directory exists
        fs.makeDir(fs.getDir(finalDepPath))

        -- Move files
        fs.move(tempDepPath, finalDepPath)

        self.log.debug("Files moved successfully. Updating config.")

        -- Update config after successful move
        config.installedDependencies[dep.name] = {
            version = dep.version,
            installedAt = os.epoch("utc")
        }
        self:saveConfig(config)

        return true
    end)

    if not ok then
        self.log.error("Dependency installation failed: %s", result)
        -- Log the state of relevant directories
        self.log.debug("Temp directory exists: %s", fs.exists(tempPath))
        self.log.debug("Temp dependency directory exists: %s", fs.exists(tempDepPath))
        self.log.debug("Final directory exists: %s", fs.exists(finalDepPath))
    end

    fs.delete(tempPath)

    return ok and result
end

function Installer:installProgram(program)
    expect(1, program, "table")

    local currentTerm = term.current()
    local progress = ui.progressBar(currentTerm, self.boxSizing.mainPadding, 8, self.boxSizing.contentBox, nil, nil,
        true)
    local statusBox = ui.textBox(currentTerm, self.boxSizing.mainPadding, 6, self.boxSizing.contentBox, 1, "")

    local tempPath = self:getTempPath()
    local tempProgramPath = fs.combine(tempPath, program.name)
    local finalProgramPath = self.BASE_PATH .. "/programs/" .. program.name

    local ok, result = pcall(function()
        -- Calculate total steps
        local currentStep = 0
        local totalSteps = (#program.files or 0) + (#program.dependencies or 0)

        -- First handle dependencies
        if program.dependencies then
            for _, dep in ipairs(program.dependencies) do
                statusBox("Installing dependency: " .. dep.name)
                local success = self:installDependency(dep, function(depProgress)
                    local scaledProgress = (currentStep + depProgress) / totalSteps
                    progress(scaledProgress)
                end)

                if not success then
                    error(string.format("Failed to install dependency: %s", dep.name))
                end
                currentStep = currentStep + 1
                progress(currentStep / totalSteps)
            end
        end

        -- Create temporary program directory
        fs.makeDir(tempProgramPath)

        -- Install program files
        for _, file in ipairs(program.files) do
            statusBox("Installing: " .. file.path)
            -- Ensure target directory exists
            fs.makeDir(fs.getDir(fs.combine(tempProgramPath, file.path)))

            local success = self:downloadFile(file.url, fs.combine(tempProgramPath, file.path))
            if not success then
                error(string.format("Failed to install file: %s", file.path))
            end
            currentStep = currentStep + 1
            progress(currentStep / totalSteps)
        end

        -- Validate installation
        local validationSuccess, validationError = self:validateInstallation(program, tempProgramPath)
        if not validationSuccess then
            error(string.format("Installation validation failed: %s", validationError))
        end

        -- Move files to final location
        if fs.exists(finalProgramPath) then
            fs.delete(finalProgramPath)
        end
        fs.move(tempProgramPath, finalProgramPath)

        -- Save installation to config
        local config = self:loadConfig()
        config.installedPrograms[program.name] = {
            version = program.version,
            installedAt = os.epoch("utc")
        }
        self:saveConfig(config)

        return true
    end)

    if not ok then
        self.log.error("Installation failed: %s", result)
        return false, result
    end

    fs.delete(tempPath)

    return result
end

function Installer:validateInstallation(program, path)
    for _, file in ipairs(program.files) do
        local filePath = fs.combine(path, file.path)
        if not fs.exists(filePath) then
            return false, "Missing file: " .. file.path
        end
    end

    -- Verify dependencies
    for _, dep in ipairs(program.dependencies or {}) do
        local config = self:loadConfig()
        local installedDep = config.installedDependencies[dep.name]
        if not installedDep then
            return false, "Missing dependency: " .. dep.name
        end
        if self.compareVersions(installedDep.version, dep.version) < 0 then
            return false, string.format("Dependency %s version %s is incompatible (need %s)", dep.name,
                installedDep.version, dep.version)
        end
    end

    return true
end

function Installer:showDialog(options)
    expect(1, options, "table")
    field(options, "title", "string", "nil")
    field(options, "message", "string")
    field(options, "buttons", "table")
    field(options, "color", "number", "nil")
    field(options, "height", "number", "nil")

    ui.clear()

    local currentY = self.boxSizing.mainPadding + 1
    local width = self.boxSizing.contentBox - 2
    local height = options.height or 12

    ui.borderBox(term.current(), self.boxSizing.mainPadding + 1, currentY, self.boxSizing.borderBox, height)
    -- draw title
    currentY = currentY + 1
    ui.textBox(term.current(), self.boxSizing.mainPadding + 1, currentY, width, 3, options.title or "Message",
        options.color or colors.lightGray)
    -- draw separator
    currentY = currentY + 1
    ui.horizontalLine(term.current(), self.boxSizing.mainPadding + 1, currentY, width, options.color or colors.lightGray)
    -- draw message
    currentY = currentY + 2
    ui.textBox(term.current(), self.boxSizing.mainPadding + 1, currentY, width, 4, options.message or "")
    -- draw buttons
    currentY = self.boxSizing.mainPadding + height - 2
    local buttonSpacing = math.floor(width / #options.buttons)
    for i, button in ipairs(options.buttons) do
        ui.button(term.current(), self.boxSizing.mainPadding + (i - 1) * buttonSpacing + 4, currentY, button.text,
            button.action, button.color or colors.lightGray)
    end

    local _, action = ui.run()
    return action
end

function Installer:showContinueDialogView(options, buttonText)
    expect(1, options, "table")
    expect(2, buttonText, "string", "nil")

    local dialogOptions = {
        title = field(options, "title", "string", "nil") or "Message",
        message = field(options, "message", "string"),
        color = field(options, "color", "number", "nil") or colors.white,
        height = field(options, "height", "number", "nil") or 12,
        buttons = { {
            text = buttonText or "Continue",
            action = "continue"
        } }
    }

    return self:showDialog(dialogOptions)
end

function Installer:showErrorDialogView(message, ...)
    expect(1, message, "string")

    local dialogOptions = {
        title = "Error",
        message = string.format(message, ...),
        color = colors.red
    }

    return self:showContinueDialogView(dialogOptions)
end

---Shows a dialog with Yes/No buttons
---@return boolean:Returns "yes" or "no"
function Installer:showYesNoDialogView(options)
    expect(1, options, "table")

    local dialogOptions = {
        title = field(options, "title", "string", "nil") or "Confirm",
        message = field(options, "message", "string"),
        color = field(options, "color", "number", "nil") or colors.yellow,
        height = field(options, "height", "number", "nil") or 12,
        buttons = { {
            text = "Yes",
            action = "yes",
            color = colors.green
        }, {
            text = "No",
            action = "no",
            color = colors.red
        } }
    }

    return self:showDialog(dialogOptions)
end

function Installer:drawBackButton()
    expect(1, self, "table")

    -- Position in top-right corner, accounting for padding
    local termW, _ = term.getSize()
    local buttonX = termW - 6 - self.boxSizing.mainPadding
    local buttonY = 2

    ui.button(term.current(), buttonX, buttonY, "Back", "back", colors.white, colors.gray)
end

function Installer:showMainMenuView()
    ui.clear()

    ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3,
        "BNG Installer v" .. self.VERSION, colors.cyan)

    ui.textBox(term.current(), self.boxSizing.mainPadding, 4, self.boxSizing.contentBox, 3, "Select an option:")

    local display_text = {}
    local descriptions = {}
    -- the ui.selectionBox function returns the display text of the selected option so we need to convert this back to the enum (id)
    local text_to_id = {} -- Map to convert display text back to id

    for i, item in ipairs(self.MAIN_MENU.items) do
        table.insert(display_text, item.text)
        table.insert(descriptions, item.description)
        text_to_id[item.text] = self.MAIN_MENU.options[item.id] -- Map display text to enum value
    end

    ui.borderBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.borderBox, 8)

    local descriptionBox = ui.textBox(term.current(), self.boxSizing.mainPadding, 15, self.boxSizing.contentBox, 3,
        descriptions[1])

    ui.selectionBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.contentBox, 8, display_text,
        "done", function(opt)
            descriptionBox(descriptions[opt])
        end)

    local action_type, _, selected_text = ui.run()

    local selected_id = text_to_id[selected_text]
    self.log.debug("Main menu selection: %s", selected_id)

    return action_type, _, selected_id
end

function Installer:showInstallProgramSelectorView(programs)
    expect(1, programs, "table")

    ui.clear()

    ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3,
        "Select a program to install:")

    self:drawBackButton()

    -- Create arrays for selection box
    local entries = {}
    local descriptions = {}

    for _, program in ipairs(programs) do
        local desc = program.description or "No description available"

        table.insert(entries, program.title .. " v" .. program.version)
        table.insert(descriptions, desc)
    end

    ui.borderBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.borderBox, 8)

    local descriptionBox = ui.textBox(term.current(), self.boxSizing.mainPadding, 15, self.boxSizing.contentBox, 5,
        descriptions[1])

    ui.selectionBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.contentBox, 8, entries, "done",
        function(opt)
            descriptionBox(descriptions[opt])
        end)

    local _, action, selection = ui.run()

    if action == "back" then
        return nil
    end

    -- Extract program name from selection and return program
    if selection then
        for _, program in ipairs(programs) do
            if selection:find(program.title, 1, true) then
                self.log.debug("Selected " .. program.name .. "\n" .. dump(program))
                return program
            end
        end
    end
end

function Installer:showConfirmInstallProgramView(program)
    ui.clear()

    local message = string.format("Program: %s v%s\nAuthor: %s\n\nProceed with installation?", program.title,
        program.version, program.author)

    ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox - 4, 8, message)

    ui.button(term.current(), self.boxSizing.mainPadding, 13, "Install", "install")
    ui.button(term.current(), self.boxSizing.mainPadding + 12, 13, "Cancel", "cancel")

    self:drawBackButton()

    local _, action = ui.run()

    return action
end

function Installer:showCoreVersionSelectorView(_requiredVersion)
    self.log.debug("Showing core version selector")
    ui.clear()

    -- Fetch latest releases
    local coreReleases = {}
    local response = self:httpGet("https://api.github.com/repos/bngarren/bng-cc-core/releases")
    if response then
        local apiResult = textutils.unserializeJSON(response.readAll())
        if apiResult then
            for index, value in ipairs(apiResult) do
                if index > 3 then
                    break
                end
                table.insert(coreReleases, {
                    tag = value.tag_name,
                    url = value.html_url
                })
            end
            self.log.info("Retrieved latest releases:\n%s", dump(coreReleases))
        end
    end

    local currentVersion = self:loadConfig().core.version or "none"
    local requiredVersion = self:getMinimumCoreVersion(_requiredVersion)
    local options = {}
    local descriptions = {}

    -- Add latest 3 releases
    for i, release in ipairs(coreReleases) do
        local isRequired = requiredVersion and release.tag:sub(2) == requiredVersion
        local option = release.tag .. (isRequired and " (required)" or "")
        table.insert(options, option)
        table.insert(descriptions,
            string.format(
                "Install core %s%s.\nThis version will be downloaded from the corresponding GitHub release.",
                release.tag, isRequired and " - *required by local program(s)" or ""))
    end

    -- Add required version if not in latest 3 and exists
    if requiredVersion then
        local requiredFound = false
        for _, opt in ipairs(options) do
            if opt:match("^v" .. requiredVersion) then
                requiredFound = true
                break
            end
        end

        if not requiredFound then
            table.insert(options, "v" .. requiredVersion .. " (required)")
            table.insert(descriptions, string.format(
                "Install core v%s - this is the version required by local program(s).\nThis version will be downloaded from the corresponding GitHub release.",
                requiredVersion))
        end
    end

    -- Add dev branch option
    table.insert(options, "Development Branch (latest)")
    table.insert(descriptions,
        "Install the latest code from the dev branch.\nWarning: This version may be unstable but will have the latest features and fixes.")

    ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3,
        string.format("Select bng-cc-core Version\nCurrent: %s\nRequired: %s", currentVersion, requiredVersion))

    ui.borderBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.borderBox, 8)
    local descriptionBox = ui.textBox(term.current(), self.boxSizing.mainPadding, 15, self.boxSizing.contentBox, 5,
        descriptions[1])

    self:drawBackButton()

    ui.selectionBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.contentBox, 8, options, "done",
        function(opt)
            descriptionBox(descriptions[opt])
        end)

    local _, action, selection = ui.run()

    if action == "back" then
        return nil
    end

    local selectedVersion
    if selection:match("Development Branch") then
        selectedVersion = "dev"
    else
        selectedVersion = selection:match("^v(.+)%s?"):gsub("%s.*$", "")
    end

    -- Handle version installation confirmation
    if selectedVersion == currentVersion then
        local action = self:showYesNoDialogView({
            title = "Alert",
            message = string.format("bng-cc-core (%s) is already installed.\nReinstall?", selectedVersion)
        })
        if action == "no" then
            return nil
        end
    else
        local action = self:showYesNoDialogView({
            title = "Confirm",
            message = string.format("This will install bng-cc-core (%s).\nContinue?", selectedVersion),
            color = colors.green
        })
        if action == "no" then
            return nil
        end
    end

    self.log.info("Selected core version: %s", selectedVersion)
    return selectedVersion
end

function Installer:showCompleteView(name)
    ui.clear()

    ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3,
        name .. " has been installed successfully!")

    ui.button(term.current(), self.boxSizing.mainPadding, 6, "Continue", "done")

    ui.run()
end

function Installer:showManageProgramSelectorView()
    ui.clear()

    local config = self:loadConfig()

    if not next(config.installedPrograms) then
        ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3,
            "No programs are currently installed.")

        ui.button(term.current(), self.boxSizing.mainPadding, 6, "Back", "back")

        ui.run()
        return "back"
    end

    ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3, "Installed Programs:")

    -- Create entries for selection box
    local entries = {}
    local descriptions = {}

    for name, info in pairs(config.installedPrograms) do
        table.insert(entries, name)
        table.insert(descriptions, string.format("Version: %s\nInstalled: %s", info.version,
            os.date("%Y-%m-%d %H:%M", info.installedAt / 1000)))
    end

    ui.borderBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.borderBox, 8)

    local descriptionBox = ui.textBox(term.current(), self.boxSizing.mainPadding, 15, self.boxSizing.contentBox, 3,
        descriptions[1])

    ui.selectionBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.contentBox, 8, entries, "done",
        function(opt)
            descriptionBox(descriptions[opt])
        end)

    self:drawBackButton()

    local _, action, selection = ui.run()

    self.log.debug("Selected %s to manage program", selection)

    return action, selection
end

function Installer:showManageProgramView(installedProgramName)
    ui.clear()

    -- Get installed program info from config
    local config = self:loadConfig()
    local installedProgram = config.installedPrograms[installedProgramName]
    if not installedProgram then
        self.log.error("Could not find installed program: %s", installedProgramName)
        self:showErrorDialogView("Could not find installed program: " .. installedProgramName)
    end

    -- Get program info from registry
    local registry = self:fetchRegistry()
    if not registry then
        self.log.error("Could not get registry.json")
        self:showErrorDialogView("Could not get registry.json")
        return nil
    end

    local registryProgram
    for _, rp in ipairs(registry.programs) do
        if rp.name == installedProgramName then
            registryProgram = rp
            break
        end
    end

    local term_width, _ = term.getSize()

    -- Display program information
    local title = string.format("%s (%s)", registryProgram and registryProgram.title or installedProgramName,
        installedProgramName)
    ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3, title, colors.cyan)

    ui.horizontalLine(term.current(), self.boxSizing.mainPadding, 4, term_width - 1, colors.gray)

    -- Back button at top right
    -- ui.button(term.current(), self.boxSizing.borderBox - 4, 2, "Back", "back", colors.white, colors.gray)
    self:drawBackButton()

    -- Create scrollable area
    local scrollArea, _ = ui.scrollBox(term.current(), self.boxSizing.mainPadding, 6, self.boxSizing.contentBox, 11,
        20 + (registryProgram and #registryProgram.dependencies or 0), true, true,
        colors.white, colors.black)
    -- Draw content in scroll area
    scrollArea.setBackgroundColor(colors.black)
    scrollArea.clear()

    local function resetFg()
        scrollArea.setTextColor(colors.white)
    end

    local cy = 1
    if registryProgram then
        local updateAvailable = self.compareVersions(registryProgram.version, installedProgram.version) > 0

        scrollArea.setCursorPos(1, cy)
        scrollArea.write("Installed Version: ")
        scrollArea.setTextColor(updateAvailable and colors.lightGray or colors.green)
        scrollArea.write(installedProgram.version)
        resetFg()
        cy = cy + 1

        scrollArea.setCursorPos(1, cy)
        scrollArea.write("Latest Version: ")
        scrollArea.setTextColor(updateAvailable and colors.green or colors.white)
        scrollArea.write(registryProgram.version)
        if updateAvailable then
            scrollArea.write(" (Update Available!)")
        end
        resetFg()
        cy = cy + 2

        -- Description
        scrollArea.setTextColor(colors.yellow)
        scrollArea.setCursorPos(1, cy)
        scrollArea.write("Description:")
        cy = cy + 1
        scrollArea.setTextColor(colors.white)
        scrollArea.setCursorPos(1, cy)
        local description = registryProgram.description or "No description available"

        -- Split into words and truncate
        local words = {}
        for word in description:gmatch("%S+") do
            table.insert(words, word)
            if #words >= 20 then
                break
            end
        end

        -- Add ellipsis if we truncated
        local truncatedDesc = table.concat(words, " ")
        if #words == 20 and description:match("%S+", truncatedDesc:len() + 1) then
            truncatedDesc = truncatedDesc .. "..."
        end
        cy = writeWrappedText(scrollArea, truncatedDesc, 1, cy, self.boxSizing.contentBox - 4)
        cy = cy + 1

        -- Dependencies
        scrollArea.setTextColor(colors.orange)
        scrollArea.setCursorPos(1, cy)
        scrollArea.write("Dependencies")
        cy = cy + 1

        if #registryProgram.dependencies > 0 then
            scrollArea.setTextColor(colors.lightBlue)
            for _, dep in ipairs(registryProgram.dependencies) do
                scrollArea.setCursorPos(1, cy)
                scrollArea.write(string.format("  - %s v%s", dep.name, dep.version))
                cy = cy + 1
            end
        else
            scrollArea.setTextColor(colors.lightGray)
            scrollArea.setCursorPos(1, cy)
            scrollArea.write("None")
            cy = cy + 1
        end
        cy = cy + 1

        -- Install Date
        scrollArea.setTextColor(colors.lightGray)
        scrollArea.setCursorPos(1, cy)
        local text = string.format("Installed on %s",
            os.date("%A, %b %d, %Y at %R", installedProgram.installedAt / 1000))
        cy = writeWrappedText(scrollArea, text, 1, cy, self.boxSizing.contentBox - 4)
        cy = cy + 1
    else
        -- Not found in registry
        scrollArea.setTextColor(colors.red)
        scrollArea.setCursorPos(1, cy)
        scrollArea.write("Warning: Program not found in registry")
        cy = cy + 2

        scrollArea.setTextColor(colors.white)
        scrollArea.setCursorPos(1, cy)
        scrollArea.write("Installed Version: ")
        scrollArea.setTextColor(colors.yellow)
        scrollArea.write(installedProgram.version)
        cy = cy + 1

        scrollArea.setTextColor(colors.white)
        scrollArea.setCursorPos(1, cy)
        scrollArea.write("Installed At: ")
        scrollArea.setTextColor(colors.lightBlue)
        scrollArea.write(os.date("%Y-%m-%d %H:%M", installedProgram.installedAt / 1000))
        cy = cy + 2

        scrollArea.setTextColor(colors.orange)
        scrollArea.setCursorPos(1, cy)
        scrollArea.write("Limited information is available for this program.")
    end

    -- Action buttons below scroll area
    local buttonY = 18                              -- Position below scroll area
    local buttonX = self.boxSizing.mainPadding or 2 -- Initialize with fallback

    ui.horizontalLine(term.current(), buttonX, buttonY - 1, term_width - 1, colors.gray)

    if registryProgram then
        if self.compareVersions(registryProgram.version, installedProgram.version) > 0 then
            ui.button(term.current(), buttonX, buttonY, "Update", "update", colors.white, colors.green)
            buttonX = buttonX + 10
        end
    end

    ui.button(term.current(), buttonX, buttonY, "Uninstall", "remove", colors.white, colors.red)

    local _, action = ui.run()

    -- Handle actions
    if action == "update" then
        return self:handleProgramUpdate(installedProgramName, registryProgram)
    elseif action == "remove" then
        local result = self:showYesNoDialogView({
            title = "Confirm Uninstall",
            message = string.format("Are you sure you want to remove %s?", title),
            color = colors.red
        })
        if result == "yes" then
            --  Remove program files
            fs.delete(self.BASE_PATH .. "/programs/" .. installedProgramName)

            local config = self:loadConfig()

            -- Update config
            config.installedPrograms[installedProgramName] = nil
            self:saveConfig(config)

            self:showContinueDialogView({
                title = "Success",
                message = string.format("'%s' has been uninstalled.", installedProgramName),
                color = colors.green
            })
            return "remove"
        end
    end

    return action
end

function Installer:showUpdateCommonSelectorView()
    ui.clear()

    local config = self:loadConfig()

    if not next(config.installedDependencies) then
        ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3,
            "No common libaries are currently installed.")

        ui.button(term.current(), self.boxSizing.mainPadding, 6, "Back", "back")

        ui.run()
        return "back"
    end

    ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3,
        "Installed Common Libraries:")

    -- Create entries for selection box
    local entries = {}
    local descriptions = {}

    for name, info in pairs(config.installedDependencies) do
        table.insert(entries, name)
        table.insert(descriptions, string.format("Version: %s\nInstalled: %s", info.version,
            os.date("%Y-%m-%d %H:%M", info.installedAt / 1000)))
    end

    ui.borderBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.borderBox, 8)

    local descriptionBox = ui.textBox(term.current(), self.boxSizing.mainPadding, 15, self.boxSizing.contentBox, 3,
        descriptions[1])

    ui.selectionBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.contentBox, 8, entries, "done",
        function(opt)
            descriptionBox(descriptions[opt])
        end)

    self:drawBackButton()

    local _, action, selection = ui.run()

    self.log.debug("Selected %s to manage program", selection)

    return action, selection
end

function Installer:showUpdateCommonView(libName)
    ui.clear()

    local config = self:loadConfig()

    local dep

    for configDepName, configDepInfo in pairs(config.installedDependencies) do
        if configDepName == libName then
            dep = {
                name = configDepName,
                version = configDepInfo.version
            }
        end
    end

    if not dep then
        self.log.error("Can't load %s info for showUpdateCommonView", libName)
        self:showErrorDialogView("Unable to load info for %s", libName)
        return nil
    end

    -- Display common lib information
    local title = string.format("%s (%s)", dep.name, dep.version)
    ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3, title, colors.cyan)

    ui.horizontalLine(term.current(), self.boxSizing.mainPadding, 4, self.boxSizing.contentBox, colors.gray)

    -- Back button at top right
    -- ui.button(term.current(), self.boxSizing.borderBox - 4, 2, "Back", "back", colors.white, colors.gray)
    self:drawBackButton()

    ui.label(term.current(), 3, 5, "Desired version:")
    ui.borderBox(term.current(), 4, 7, 12, 1)
    ui.inputBox(term.current(), 4, 7, 12, "result")

    local _, action, text = ui.run()

    if action == "result" and text and text ~= "" then

        local trimmedInput = text:gsub("^v", "") -- remove "v" prefix if exists

        -- Validate the text input to be a Semver version string
        if not util.isValidSemver(trimmedInput) then
            self:showErrorDialogView("'%s' is not a valid version input.", trimmedInput)
            return nil
        end

        -- handle version update
        local registry = self:fetchRegistry()

        if not registry then
            self:showErrorDialogView("Could not get registry.json")
            return "back"
        end

        local regDep
        for _, p in ipairs(registry.programs) do
            if regDep then break end
            for _, progDep in ipairs(p.dependencies) do
                if progDep.name == dep.name then
                    regDep = progDep
                    break
                end
            end
        end

        local newDepVersion = trimmedInput
        regDep.version = newDepVersion

        local success = self:installDependency(regDep)

        if not success then
            if not registry then
                self:showErrorDialogView(string.format("Failed to install %s (%s)", dep.name, newDepVersion))
                return "back"
            end
        end
    end

    return action
end

function Installer:run(config)
    -- Process config
    if config and type(config) == "table" then
        self.debug = config.debug or false
    end

    self:init()

    if self.debug then
        self.log.info("Running in DEBUG mode")
    else
        self.log.info("Running in PROD mode")
    end

    local success, err = pcall(function()
        local run = true
        while run do
            local _, _, selection = self:showMainMenuView()

            -- MAIN MENU > INSTALL PROGRAM
            if selection == self.MAIN_MENU.options.INSTALL_PROGRAM then
                local registry = self:fetchRegistry()
                if registry then
                    local selectedProgram = self:showInstallProgramSelectorView(registry.programs)
                    if selectedProgram then
                        local success = false
                        repeat
                            local action = self:showConfirmInstallProgramView(selectedProgram)
                            if action == "install" then
                                local installSuccess = self:installProgram(selectedProgram)
                                if not installSuccess then
                                    self:showContinueDialogView({
                                        title = "Error",
                                        message = string.format("'%s' v%s failed installation.", selectedProgram.title,
                                            selectedProgram.version),
                                        color = colors.red
                                    })
                                    break
                                end
                                self:showContinueDialogView({
                                    title = "Success",
                                    message = string.format("'%s' v%s has been installed successfully.",
                                        selectedProgram.title, selectedProgram.version),
                                    color = colors.green
                                })
                                success = true
                            elseif action == "back" or action == "cancel" then
                                break
                            end
                        until success == true
                    end
                else
                    if not registry then
                        self:showContinueDialogView({
                            title = "Error",
                            message = "Could not get registry.json"
                        })
                    end
                end
                -- MAIN MENU > MANAGE PROGRAMS
            elseif selection == self.MAIN_MENU.options.MANAGE_PROGRAMS then
                local done = false
                repeat
                    local selectAction, selectedProgram = self:showManageProgramSelectorView()
                    if selectAction == "back" then
                        -- User clicked back from program selection screen - return to main menu
                        done = true
                    elseif selectedProgram then
                        -- User selected a program - show program management view
                        local programAction = self:showManageProgramView(selectedProgram)

                        if programAction == "back" then
                            -- Just continue the loop to show program selector again
                            self.log.debug("Returning to program selection from program view")
                        else
                            -- Handle other program management actions here
                            -- For example: if programAction == "remove" then ...
                        end
                    end
                until done == true
                -- MAIN MENU > UPDATE COMMON
            elseif selection == self.MAIN_MENU.options.UPDATE_COMMON then
                local done = false
                repeat
                    local action, selection = self:showUpdateCommonSelectorView()
                    if action == "back" then
                        done = true
                    elseif action == "done" then
                        if selection then
                            self:showUpdateCommonView(selection)
                        end
                    end
                until done == true
                -- MAIN MENU > REMOVE ALL
            elseif selection == self.MAIN_MENU.options.REMOVE_ALL then
                local result = self:showYesNoDialogView({
                    title = "Warning",
                    message = "Are you sure you want to delete all files?"
                })
                if result == "yes" then
                    fs.delete(self.CONFIG_PATH)
                    fs.delete(self.BASE_PATH)

                    self:showContinueDialogView({
                        title = "Success",
                        message = "All files have been deleted. Log restarted.",
                        color = colors.green
                    })

                    self:closeLogger()
                    self:initLogger()
                end
            elseif selection == self.MAIN_MENU.options.EXIT then
                run = false
                break
            end
        end
    end)

    ui.clear()

    if not success then
        self.log.error("Installer crashed: %s", err)
    end

    -- Cleanup
    self:closeLogger()
end

function util.isValidSemver(version)
    if not version or type(version) ~= "string" then return false end
  
  -- First try basic x.y.z format
  local major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)$")
  
  -- Check for partial versions
  if not major then
    major = version:match("^(%d+)$")
    if major then return true end
    
    major, minor = version:match("^(%d+)%.(%d+)$")
    if major and minor then return true end
    return false
  end
  
  -- For any version part that exists, check for leading zeros
  if major:match("^0%d+") or 
     minor:match("^0%d+") or 
     patch:match("^0%d+") then
    return false
  end
  
  return true
end

-- **************************************
-- Command line run

local args = { ... }

local installConfig = {}

if #args > 0 then
    for _, arg in ipairs(args) do
        if arg == "--debug" then
            installConfig.debug = true
        end
    end
end

-- Start the installer
local installer = Installer
installer:run(installConfig)
