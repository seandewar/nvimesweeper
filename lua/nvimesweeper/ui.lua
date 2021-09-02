local api, uv = vim.api, vim.loop

local board_mod = require "nvimesweeper.board"
local game_state = require "nvimesweeper.game_state"

local util = require "nvimesweeper.util"
local error = util.error

local ns = api.nvim_create_namespace "nvimesweeper"
local M = {}

local Ui = {}

function Ui:enable_modification(enable)
  api.nvim_buf_set_option(self.buf, "modifiable", enable)
end

local function centering_left_pad(ui, len)
  if not ui.centered then
    return 0
  end

  local pad = (api.nvim_win_get_width(0) - len) / 2
  return math.floor(math.max(0, pad))
end

function Ui:redraw_status()
  local function time_string(show_ms)
    local nanoseconds = uv.hrtime() - self.game.start_time
    local seconds = math.floor(nanoseconds / 1000000000)
    local minutes = math.floor(seconds / 60)

    local time = string.format("Time: %02d:%02d", minutes, seconds % 60)
    if show_ms then
      local milliseconds = math.floor(nanoseconds / 1000000)
      time = string.format("%s.%03d", time, milliseconds % 1000)
    end
    return time
  end

  local state = self.game.state
  local status
  if state == game_state.GAME_NOT_STARTED then
    status = "Game will begin once you reveal a square..."
  elseif state == game_state.GAME_STARTED then
    status = string.format(
      "%s\tFlagged: %d/%d",
      time_string(),
      self.game.board.flag_count,
      self.game.board.mine_count
    )
  elseif state == game_state.GAME_WON then
    status = "Congratulations, you win! " .. time_string(true)
  elseif state == game_state.GAME_LOST then
    status = "KA-BOOM! You explode... " .. time_string(true)
  end

  status = string.rep(" ", centering_left_pad(self, #status)) .. status

  self:enable_modification(true)
  api.nvim_buf_set_lines(self.buf, 0, 2, false, { status, "" })
  self:enable_modification(false)
end

function Ui:board_square_char(i)
  local game_over = game_state.is_game_over(self.game.state)
  local state = self.game.board.state[i]
  local mine = self.game.board.mines[i]
  local char = " "

  if
    mine
    and (
      state == board_mod.SQUARE_REVEALED
      or (game_over and state ~= board_mod.SQUARE_FLAGGED)
    )
  then
    char = "*"
  elseif state == board_mod.SQUARE_FLAGGED then
    char = (not game_over or (game_over and mine)) and "!" or "X"
  elseif state == board_mod.SQUARE_MAYBE then
    char = "?"
  elseif state == board_mod.SQUARE_REVEALED then
    local danger = self.game.board.danger[i]
    if danger > 0 then
      char = tostring(danger)
    end
  end

  return char
end

function Ui:board_square_hl_group(i)
  local game_over = game_state.is_game_over(self.game.state)
  local state = self.game.board.state[i]
  local hl_group = "NvimesweeperUnrevealed"

  if game_over and self.game.board.mines[i] then
    if state == board_mod.SQUARE_REVEALED then
      hl_group = "NvimesweeperTriggeredMine"
    elseif state == board_mod.SQUARE_FLAGGED then
      hl_group = "NvimesweeperFlag"
    else
      hl_group = "NvimesweeperMine"
    end
  elseif state == board_mod.SQUARE_FLAGGED then
    hl_group = game_over and "NvimesweeperFlagWrong" or "NvimesweeperFlag"
  elseif state == board_mod.SQUARE_MAYBE then
    hl_group = "NvimesweeperMaybe"
  elseif state == board_mod.SQUARE_REVEALED then
    local danger = self.game.board.danger[i]
    hl_group = danger > 0 and ("NvimesweeperDanger" .. danger)
      or "NvimesweeperRevealed"
  end

  return hl_group
end

function Ui:redraw_board(x1, y1, x2, y2)
  x1, y1 = x1 or 0, y1 or 0
  x2, y2 = x2 or self.game.board.width - 1, y2 or self.game.board.height - 1

  local top_left_i = self.game.board:index(x1, y1)
  local top_left_pos = self:board_square_pos(top_left_i)

  -- modify the changed part of each row
  self:enable_modification(true)
  local row = {}
  for y = y1, y2 do
    local i = self.game.board:index(x1, y)
    for x = x1, x2 do
      row[x - x1 + 1] = self:board_square_char(i)
      i = i + 1
    end

    local oy = y - y1
    api.nvim_buf_set_text(
      self.buf,
      top_left_pos[1] + oy,
      top_left_pos[2],
      top_left_pos[1] + oy,
      top_left_pos[2] + #row,
      { table.concat(row) }
    )
  end
  self:enable_modification(false)

  -- update extended marks
  for y = y1, y2 do
    local i = self.game.board:index(x1, y)
    local mark_y = top_left_pos[1] + y - y1
    for x = x1, x2 do
      local mark_x = top_left_pos[2] + x - x1
      self.board_extmarks[i] = api.nvim_buf_set_extmark(
        self.buf,
        ns,
        mark_y,
        mark_x,
        {
          id = self.board_extmarks[i],
          end_col = mark_x + 1,
          hl_group = self:board_square_hl_group(i),
        }
      )
      i = i + 1
    end
  end
end

function Ui:full_redraw()
  self:redraw_status()

  -- usually, only the changed area of the board is updated, which requires the
  -- lines to already exist, so create filler lines to fit the entire board
  local left_pad = centering_left_pad(self, self.game.board.width)
  local line = string.rep(" ", left_pad + self.game.board.width)
  local lines = util.tbl_rep(line, self.game.board.height)
  self:enable_modification(true)
  api.nvim_buf_set_lines(self.buf, -1, -1, false, lines)

  -- place an extmark for the board's top-left corner so it knows where to draw
  self.board_extmarks[1] = api.nvim_buf_set_extmark(self.buf, ns, 2, left_pad, {
    id = self.board_extmarks[1],
  })
  self:redraw_board()
end

function Ui:start_status_redraw()
  self.redraw_status_timer:start(
    0,
    1000,
    vim.schedule_wrap(function()
      if api.nvim_buf_is_loaded(self.buf) then
        self:redraw_status()
      end
    end)
  )
end

function Ui:stop_status_redraw()
  self.redraw_status_timer:stop()
end

function Ui:board_square_pos(i)
  local pos = api.nvim_buf_get_extmark_by_id(
    self.buf,
    ns,
    self.board_extmarks[i],
    {}
  )
  return pos
end

function Ui:cursor_board_pos()
  local cursor_pos = api.nvim_win_get_cursor(0)
  cursor_pos[1] = cursor_pos[1] - 1 -- nvim_win_get_cursor gives 1-indexed rows
  local board_pos = self:board_square_pos(1)
  return cursor_pos[2] - board_pos[2], cursor_pos[1] - board_pos[1]
end

local function define_buf_autocmd(buf, event, rhs)
  vim.cmd(string.format("autocmd %s <buffer=%d> ++once %s", event, buf, rhs))
end

function M.schedule_buf_delete(buf)
  vim.schedule(function()
    if api.nvim_buf_is_valid(buf) then
      api.nvim_buf_delete(buf, { force = true })
    end
  end)
end

local function create_window(ui, float_opts)
  local win
  if float_opts then
    win = api.nvim_open_win(ui.buf, true, {
      relative = "editor",
      width = float_opts.width,
      height = float_opts.height,
      row = math.max(0, math.floor((vim.go.lines - float_opts.height) / 2) - 1),
      col = math.floor((vim.go.columns - float_opts.width) / 2),
      style = "minimal",
      border = "single",
    })
    win = win ~= 0 and win or nil
  else
    local ok, _ = pcall(vim.cmd, "tab sbuffer " .. ui.buf)
    if ok then
      win = api.nvim_get_current_win()
    end
  end

  if not win then
    return false
  end

  if float_opts then
    api.nvim_buf_set_option(ui.buf, "bufhidden", "wipe")

    -- Schedule the deletion. NOTE: if we don't schedule, this can cause issues
    -- when starting a new game in a float if we are already playing a game in a
    -- different float: both floats will be closed.
    --
    -- Backstory: this is inherited from Vim's windowing behaviour; the new
    -- float briefly edits the current buffer before it edits its intended
    -- buffer (similiar to :split, then :buffer <buf>). The current buffer's
    -- WinLeave autocmd (intended for the previous float) will delete the
    -- buffer while the new float is still momentarily editing it, causing both
    -- floats to close! By delaying the deletion, we allow the new float to
    -- switch to its intended buffer first.
    --
    -- Funnily enough, this uncovered a crash in nvim_open_win() when I used
    -- BufLeave instead: https://github.com/neovim/neovim/pull/15549 -- So, you
    -- can say this silly Minesweeper clone helped improve Neovim... :P
    define_buf_autocmd(
      ui.buf,
      "WinLeave",
      "lua require('nvimesweeper.ui').schedule_buf_delete(" .. ui.buf .. ")"
    )
  else
    -- float "minimal" style already sets these
    api.nvim_win_set_option(win, "list", false)
    api.nvim_win_set_option(win, "spell", false)
  end
  ui.centered = float_opts ~= nil

  api.nvim_win_set_option(win, "wrap", false)
  return true
end

function M.new_ui(game, open_tab)
  local buf = api.nvim_create_buf(true, true)
  if buf == 0 then
    error "failed to create game buffer!"
  end

  local ui = vim.deepcopy(Ui)
  ui.buf = buf
  ui.game = game
  ui.board_extmarks = {}
  ui.redraw_status_timer = uv.new_timer()

  if
    not create_window(ui, not open_tab and {
      width = math.max(45, game.board.width),
      height = game.board.height + 2,
    } or nil)
  then
    api.nvim_buf_delete(buf, { force = true })
    error "failed to open game window!"
  end

  api.nvim_buf_set_name(
    buf,
    string.format(
      "[nvimesweeper %dx%d %d mines (%d)]",
      game.board.width,
      game.board.height,
      game.board.mine_count,
      buf
    )
  )

  util.nnoremap(
    buf,
    "<CR>",
    "<Cmd>lua require('nvimesweeper.game').reveal()<CR>"
  )
  util.nnoremap(
    buf,
    "<Space>",
    "<Cmd>lua require('nvimesweeper.game').place_marker()<CR>"
  )

  util.nnoremap(buf, "x", "<Cmd>lua require('nvimesweeper.game').reveal()<CR>")
  util.nnoremap(
    buf,
    "!",
    "<Cmd>lua require('nvimesweeper.game').place_marker("
      .. board_mod.SQUARE_FLAGGED
      .. ")<CR>"
  )
  util.nnoremap(
    buf,
    "?",
    "<Cmd>lua require('nvimesweeper.game').place_marker("
      .. board_mod.SQUARE_MAYBE
      .. ")<CR>"
  )

  local cleanup_cmd = "lua require('nvimesweeper.game').games["
    .. buf
    .. "]:cleanup()"
  define_buf_autocmd(buf, "BufDelete", cleanup_cmd)
  define_buf_autocmd(buf, "VimLeavePre", cleanup_cmd)

  ui:full_redraw()
  local board_pos = ui:board_square_pos(1)
  board_pos[1] = board_pos[1] + 1 -- nvim_win_set_cursor takes a 1-indexed row
  api.nvim_win_set_cursor(0, board_pos)

  return ui
end

return M
