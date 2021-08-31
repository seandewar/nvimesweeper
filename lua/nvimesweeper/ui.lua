local api, uv = vim.api, vim.loop

local board_mod = require "nvimesweeper.board"
local game_state = require "nvimesweeper.game_state"

local util = require "nvimesweeper.util"
local error = util.error

local ns = api.nvim_create_namespace "nvimesweeper"
local M = {}

local Ui = {}

function Ui:enable_drawing(enable)
  api.nvim_buf_set_option(self.buf, "modifiable", enable)
end

function Ui:redraw_status()
  self:enable_drawing(true)
  local game = self.game

  local function time_string(show_ms)
    local nanoseconds = uv.hrtime() - game.start_time
    local seconds = math.floor(nanoseconds / 1000000000)
    local minutes = math.floor(seconds / 60)

    local time = string.format("Time: %02d:%02d", minutes, seconds % 60)
    if show_ms then
      local milliseconds = math.floor(nanoseconds / 1000000)
      time = string.format("%s.%03d", time, milliseconds % 1000)
    end

    return time
  end

  local status
  if game.state == game_state.GAME_NOT_STARTED then
    status = "Game will begin once you reveal a square..."
  elseif game.state == game_state.GAME_STARTED then
    status = time_string()
      .. "\tFlagged: "
      .. game.board.flag_count
      .. "/"
      .. game.board.mine_count
  elseif game.state == game_state.GAME_WON then
    status = "Congratulations, you win! " .. time_string(true)
  elseif game.state == game_state.GAME_LOST then
    status = "KA-BOOM! You explode... " .. time_string(true)
  end

  api.nvim_buf_set_lines(self.buf, 0, 2, false, { status, "" })
  self:enable_drawing(false)
end

function Ui:redraw_board()
  self:enable_drawing(true)
  local game = self.game
  local game_over = game_state.is_game_over(game.state)

  -- Create the lines to draw from the rows of the game board
  local lines = {}
  local i = 1
  for y = 0, game.board.height - 1 do
    local row = {}
    for x = 0, game.board.width - 1 do
      local state = game.board.state[i]
      local mine = game.board.mines[i]
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
        local danger = game.board.danger[i]
        if danger > 0 then
          char = tostring(danger)
        end
      end

      row[x + 1] = char
      i = i + 1
    end

    lines[y + 1] = table.concat(row)
  end

  -- Draw the board
  api.nvim_buf_set_lines(self.buf, 2, 2 + #lines, false, lines)

  -- Place extended marks for each board square
  i = 1
  for y = 0, game.board.height - 1 do
    for x = 0, game.board.width - 1 do
      local state = game.board.state[i]
      local hl_group = "NvimesweeperUnrevealed"

      if game_over and game.board.mines[i] then
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
        local danger = game.board.danger[i]
        hl_group = danger > 0 and ("NvimesweeperDanger" .. danger)
          or "NvimesweeperRevealed"
      end

      self.board_extmarks[i] =
        api.nvim_buf_set_extmark(self.buf, ns, 2 + y, x, {
          id = self.board_extmarks[i],
          end_col = x + 1,
          hl_group = hl_group,
        })
      i = i + 1
    end
  end

  self:enable_drawing(false)
end

function Ui:redraw_all()
  self:redraw_status()
  self:redraw_board()
end

function Ui:start_status_redraw()
  self.redraw_status_timer:start(
    500,
    500,
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

function Ui:focus_board()
  local board_pos = api.nvim_buf_get_extmark_by_id(
    self.buf,
    ns,
    self.board_extmarks[1],
    {}
  )
  board_pos[1] = board_pos[1] + 1 -- row is 0-indexed
  api.nvim_win_set_cursor(0, board_pos)
end

function M.new_ui(game)
  local buf = api.nvim_create_buf(true, true)
  if buf == 0 then
    error "failed to create game buffer!"
    return nil
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
  api.nvim_buf_set_option(buf, "modifiable", false)

  local ok, _ = pcall(vim.cmd, "tab sbuffer " .. buf)
  if not ok then
    error "failed to open game window!"
    api.nvim_buf_delete(buf, { force = true })
    return nil
  end

  api.nvim_win_set_option(0, "wrap", false)
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
  util.nnoremap(
    buf,
    "x",
    "<Cmd>lua require('nvimesweeper.game').reveal()<CR>"
  )
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

  local function define_cleanup_autocmd(event)
    vim.cmd(
      string.format(
        "autocmd %s <buffer=%d> ++once "
          .. "lua require('nvimesweeper.game').cleanup_game(%d)",
        event,
        buf,
        buf
      )
    )
  end

  define_cleanup_autocmd "BufDelete"
  define_cleanup_autocmd "VimLeavePre"

  local ui = vim.deepcopy(Ui)
  ui.buf = buf
  ui.game = game
  ui.board_extmarks = {}
  ui.redraw_status_timer = uv.new_timer()

  ui:redraw_all()
  ui:focus_board()
  return ui
end

return M
