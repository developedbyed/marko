local M = {}

local popup_buf = nil
local popup_win = nil
local shadow_win = nil

-- Check if popup is currently open
function M.is_open()
  return popup_win and vim.api.nvim_win_is_valid(popup_win)
end

-- Create shadow window for depth effect
local function create_shadow(width, height, row, col)
  if not require("marko.config").get().shadow then
    return nil
  end
  
  local shadow_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[shadow_buf].bufhidden = "wipe"
  
  local shadow_win = vim.api.nvim_open_win(shadow_buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = row + 1,
    col = col + 2,
    style = "minimal",
    focusable = false,
    zindex = 1  -- Behind main window
  })
  
  -- Set shadow appearance
  vim.wo[shadow_win].winhl = "Normal:Normal"
  vim.wo[shadow_win].winblend = 80
  
  return shadow_win
end

-- Create the popup window
function M.create_popup()
  local config = require("marko.config").get()
  local marks = require("marko.marks").get_all_marks()
  
  -- Close existing popup if open
  if popup_win and vim.api.nvim_win_is_valid(popup_win) then
    vim.api.nvim_win_close(popup_win, true)
  end
  if shadow_win and vim.api.nvim_win_is_valid(shadow_win) then
    vim.api.nvim_win_close(shadow_win, true)
  end
  
  -- Create buffer
  popup_buf = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer options
  vim.bo[popup_buf].bufhidden = "wipe"
  vim.bo[popup_buf].filetype = "marko-popup"
  
  -- Calculate window size and position with new layout
  local width = math.max(config.width, 80)  -- Minimum width for new layout
  
  -- Account for header, column headers, status bar, and marks
  local header_lines = 3  -- Empty, stats, separator (removed title line)
  local column_header_lines = 2  -- Headers + separator
  local status_lines = 3  -- Separator, status, empty
  local marks_lines = math.max(#marks, 1)  -- At least 1 for "no marks"
  local total_height = header_lines + column_header_lines + marks_lines + status_lines
  
  local height = math.min(config.height, total_height)
  local row = math.ceil((vim.o.lines - height) / 2)
  local col = math.ceil((vim.o.columns - width) / 2)
  
  -- Create shadow window first (if enabled)
  shadow_win = create_shadow(width, height, row, col)
  
  -- Create main window
  popup_win = vim.api.nvim_open_win(popup_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = config.border,
    title = config.title,
    title_pos = "center",
    style = "minimal",
    zindex = 2  -- Above shadow
  })
  
  -- Set window options with custom highlights
  local winhl = "Normal:MarkoNormal,FloatBorder:MarkoBorder,CursorLine:MarkoCursorLine"
  vim.wo[popup_win].winhl = winhl
  
  -- Set transparency if configured
  if config.transparency > 0 then
    vim.wo[popup_win].winblend = config.transparency
  end
  
  -- Enable cursor line highlighting
  vim.wo[popup_win].cursorline = true
  
  -- Populate buffer with marks
  M.populate_buffer(marks)
  
  -- Set up keymaps
  M.setup_keymaps()
end

-- Generate header with stats
local function generate_header(marks)
  local icons = require("marko.icons")
  local buffer_count = 0
  local global_count = 0
  
  for _, mark in ipairs(marks) do
    if mark.type == "buffer" then
      buffer_count = buffer_count + 1
    else
      global_count = global_count + 1
    end
  end
  
  local stats = string.format("  %d Global %s %d Buffer", 
    global_count, icons.icons.separator, buffer_count)
  
  return {
    "",  -- Empty line for spacing
    stats,
    string.rep("─", 80),  -- Separator line (wider for better coverage)
  }
end

-- Generate column headers that align with mark content
local function generate_column_headers()
  local icons = require("marko.icons")
  
  -- Match the exact format from icons.format_mark_line:
  -- mark_icon + mark + separator + line + separator + file_icon + filename + content
  local header_line = string.format("  %s %s %4s %s %s",
    "M",                 -- Simplified mark column
    icons.icons.separator, -- Same separator
    "Line",              -- Line number (4 chars wide to match mark lines)
    icons.icons.separator, -- Same separator
    "File"               -- Combined file and content
  )
  
  return {
    header_line,
    string.rep("─", 80),  -- Separator line
  }
end

-- Generate status bar with keybinding hints
local function generate_status_bar()
  local config = require("marko.config").get()
  local icons = require("marko.icons")
  
  return {
    string.rep("─", 60),  -- Separator line
    string.format("  J/K ↕  D %s  Esc/' %s", 
      icons.icons.delete,
      icons.icons.escape),
    ""  -- Empty line for spacing
  }
end

-- Populate buffer with marks data
function M.populate_buffer(marks)
  local config = require("marko.config").get()
  local icons = require("marko.icons")
  local ns_id = require("marko.config").get_namespace()
  local lines = {}
  
  -- Add header
  local header_lines = generate_header(marks)
  for _, line in ipairs(header_lines) do
    table.insert(lines, line)
  end
  
  -- Add column headers
  local column_header_lines = generate_column_headers()
  for _, line in ipairs(column_header_lines) do
    table.insert(lines, line)
  end
  
  -- Add marks content
  if #marks == 0 then
    table.insert(lines, "    No marks found")
  else
    for i, mark in ipairs(marks) do
      local formatted_line = icons.format_mark_line(mark, config)
      table.insert(lines, "  " .. formatted_line)  -- Add padding
    end
  end
  
  -- Add status bar
  local status_lines = generate_status_bar()
  for _, line in ipairs(status_lines) do
    table.insert(lines, line)
  end
  
  vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, lines)
  vim.bo[popup_buf].modifiable = false
  
  -- Store marks data in buffer variable for keymap access
  -- Need to adjust indexing since we added header lines
  local marks_start_line = #header_lines + #column_header_lines 
  vim.b[popup_buf].marks_data = marks
  vim.b[popup_buf].marks_start_line = marks_start_line
  
  -- Apply syntax highlighting
  M.apply_highlighting(marks, marks_start_line)
  
  -- Position cursor on first mark line (if any marks exist)
  if #marks > 0 then
    vim.api.nvim_win_set_cursor(popup_win, {marks_start_line + 1, 0})
  end
end

-- Apply highlighting to the buffer content
function M.apply_highlighting(marks, marks_start_line)
  local config = require("marko.config").get()
  local ns_id = require("marko.config").get_namespace()
  
  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(popup_buf, ns_id, 0, -1)
  
  -- Highlight header sections
  local all_lines = vim.api.nvim_buf_get_lines(popup_buf, 0, -1, false)
  
  -- Highlight title and stats in header
  for i, line in ipairs(all_lines) do
    local line_idx = i - 1
    
    
    -- Highlight stats line
    if line:match("󰝰") then  -- Stats icon
      vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, 0, {
        end_col = #line,
        hl_group = "MarkoStats"
      })
    end
    
    -- Highlight separator lines
    if line:match("^─+$") then
      vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, 0, {
        end_col = #line,
        hl_group = "MarkoSeparator"
      })
    end
    
    -- Highlight column headers
    if line:match("Mark") then
      vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, 0, {
        end_col = #line,
        hl_group = "MarkoColumnHeader"
      })
    end
    
    -- Highlight status bar
    if line:match("󰌑.*Select") then  -- Status bar line
      vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, 0, {
        end_col = #line,
        hl_group = "MarkoStatusBar"
      })
    end
  end
  
  if #marks == 0 then
    return
  end
  
  -- Highlight mark content lines
  for i, mark in ipairs(marks) do
    local line_idx = marks_start_line + i - 1
    local line_content = vim.api.nvim_buf_get_lines(popup_buf, line_idx, line_idx + 1, false)[1]
    
    if not line_content or #line_content == 0 then
      goto continue
    end
    
    -- Safe pattern-based highlighting - use actual mark.type from data structure
    local patterns = {
      -- Line numbers (digits)
      {
        pattern = "(%d+)",
        hl_group = "MarkoLineNumber"
      }
    }
    
    -- Handle mark character highlighting separately to ensure correct type-based coloring
    local mark_pattern = "^  ([a-zA-Z]) " .. vim.pesc(config.separator)
    local mark_start, mark_end, captured_mark = line_content:find(mark_pattern)
    if mark_start and captured_mark then
      local mark_hl_group = mark.type == "global" and "MarkoGlobalMark" or "MarkoBufferMark"
      vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, 2, {
        end_col = 3,  -- Single character
        hl_group = mark_hl_group
      })
    end
    
    -- Apply each pattern
    for _, p in ipairs(patterns) do
      local start_pos = 1
      while start_pos <= #line_content do
        local match_start, match_end, capture = line_content:find(p.pattern, start_pos)
        if not match_start then break end
        
        -- If we have a capture group, highlight just that
        if p.capture and capture then
          local capture_start = line_content:find(capture, match_start, true)
          if capture_start then
            vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, capture_start - 1, {
              end_col = capture_start - 1 + #capture,
              hl_group = p.hl_group
            })
          end
        else
          -- Highlight the entire match
          vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, match_start - 1, {
            end_col = match_end,
            hl_group = p.hl_group
          })
        end
        
        start_pos = match_end + 1
      end
    end
    
    -- Highlight filename section (between first and second separator now)
    local separators = {}
    local start_pos = 1
    while true do
      local sep_pos = line_content:find(config.separator, start_pos)
      if not sep_pos then break end
      table.insert(separators, sep_pos)
      start_pos = sep_pos + 1
    end
    
    -- Filename is between 1st and 2nd separator (format: mark | line | file content)
    if #separators >= 2 then
      local filename_start = separators[1] + 1
      local filename_end = separators[2] - 1
      if filename_start <= filename_end then
        -- Skip the file icon and space, find where actual filename starts
        local filename_section = line_content:sub(filename_start, filename_end)
        local icon_end = filename_section:find(" ") or 0
        if icon_end > 0 then
          filename_start = filename_start + icon_end
          vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_idx, filename_start - 1, {
            end_col = filename_end,
            hl_group = "MarkoFilename"
          })
        end
      end
    end
    
    ::continue::
  end
end

-- Set up keymaps for the popup
function M.setup_keymaps()
  local config = require("marko.config").get()
  local marks_module = require("marko.marks")

  -- Helper to set single or multiple keymaps
  local function set_keymaps(keys, func)
    if type(keys) == "table" then
      for _, key in ipairs(keys) do
        vim.keymap.set("n", key, func, { buffer = popup_buf, silent = true })
      end
    elseif type(keys) == "string" then
      vim.keymap.set("n", keys, func, { buffer = popup_buf, silent = true })
    end
  end

  -- Close popup
  set_keymaps(config.keymaps.close, function()
    M.close_popup()
  end)

  vim.keymap.set("n", "q", function()
    M.close_popup()
  end, { buffer = popup_buf, silent = true })

  -- Also close with the same key that opens it
  if config.default_keymap then
    vim.keymap.set("n", config.default_keymap, function()
      M.close_popup()
    end, { buffer = popup_buf, silent = true })
  end

  -- Go to mark
  local goto_func = function()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local marks_data = vim.b[popup_buf].marks_data
    local marks_start_line = vim.b[popup_buf].marks_start_line
    
    -- Calculate mark index based on cursor position
    local mark_index = cursor_line - marks_start_line
    
    if marks_data and mark_index >= 1 and mark_index <= #marks_data then
      M.close_popup()
      marks_module.goto_mark(marks_data[mark_index])
    end
  end
  set_keymaps(config.keymaps.goto, goto_func)

  -- Delete mark
  local delete_func = function()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local marks_data = vim.b[popup_buf].marks_data
    local marks_start_line = vim.b[popup_buf].marks_start_line
    
    -- Calculate mark index based on cursor position
    local mark_index = cursor_line - marks_start_line
    
    if marks_data and mark_index >= 1 and mark_index <= #marks_data then
      marks_module.delete_mark(marks_data[mark_index])
      -- Refresh the popup
      vim.defer_fn(function()
        M.create_popup()
      end, 50)
    end
  end
  set_keymaps(config.keymaps.delete, delete_func)

  -- Restrict cursor movement to marks section only
  local function constrain_cursor()
    local marks_data = vim.b[popup_buf].marks_data
    local marks_start_line = vim.b[popup_buf].marks_start_line
    
    if not marks_data or #marks_data == 0 then
      return
    end
    
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local marks_end_line = marks_start_line + #marks_data
    
    -- Constrain cursor to marks section (1-indexed lines)
    local first_mark_line = marks_start_line + 1
    if cursor_line < first_mark_line then
      vim.api.nvim_win_set_cursor(0, {first_mark_line, 0})
    elseif cursor_line > marks_end_line then
      vim.api.nvim_win_set_cursor(0, {marks_end_line, 0})
    end
  end
  
  -- Override j/k movement to constrain cursor
  vim.keymap.set("n", "j", function()
    vim.cmd("normal! j")
    constrain_cursor()
  end, { buffer = popup_buf, silent = true })
  
  vim.keymap.set("n", "k", function()
    vim.cmd("normal! k")
    constrain_cursor()
  end, { buffer = popup_buf, silent = true })
  
  -- Override down/up arrow keys as well
  vim.keymap.set("n", "<Down>", function()
    vim.cmd("normal! j")
    constrain_cursor()
  end, { buffer = popup_buf, silent = true })
  
  vim.keymap.set("n", "<Up>", function()
    vim.cmd("normal! k")
    constrain_cursor()
  end, { buffer = popup_buf, silent = true })
end

-- Close the popup
function M.close_popup()
  if popup_win and vim.api.nvim_win_is_valid(popup_win) then
    vim.api.nvim_win_close(popup_win, true)
  end
  if shadow_win and vim.api.nvim_win_is_valid(shadow_win) then
    vim.api.nvim_win_close(shadow_win, true)
  end
  popup_win = nil
  popup_buf = nil
  shadow_win = nil
end

return M
