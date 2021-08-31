local api, uv = vim.api, vim.loop

local board_mod = require "nvimesweeper.board"
local game_state = require "nvimesweeper.game_state"
local ui_mod = require "nvimesweeper.ui"

local M = {
  games = {},
}

local Game = {}

function M.new_game(width, height, mine_count)
  local game = vim.deepcopy(Game)
  game.state = game_state.GAME_NOT_STARTED
  game.board = board_mod.new_board(width, height)
  game.board.mine_count = mine_count

  local ui = ui_mod.new_ui(game)
  if not ui then
    return nil
  end
  game.ui = ui

  M.games[ui.buf] = game
  return game
end

function M.cleanup_game(buf)
  local game = M.games[buf]
  if game then
    game.ui:stop_status_redraw()
    M.games[buf] = nil
  end
end

local function get_action_args(buf, x, y)
  if not buf then
    buf = api.nvim_get_current_buf()
    local pos = api.nvim_win_get_cursor(0)
    x = pos[2]
    y = pos[1] - 1 -- return row is 1-indexed
    y = y - 2 -- HACK: get position from extmark instead
  end

  return M.games[buf], x, y
end

function M.cycle_marker(buf, x, y)
  local game, x, y = get_action_args(buf, x, y)
  if game.state ~= game_state.GAME_STARTED then
    return false
  end

  local i = game.board:index(x, y)
  if not i then
    return false
  end

  local state = game.board.state[i]
  local new_state
  if state == board_mod.SQUARE_NONE then
    new_state = board_mod.SQUARE_FLAGGED
  elseif state == board_mod.SQUARE_FLAGGED then
    new_state = board_mod.SQUARE_MAYBE
  else
    new_state = board_mod.SQUARE_NONE
  end

  local ok = game.board:flag_unrevealed(i, new_state)
  if ok then
    game.ui:redraw_all() -- TODO: redraw only the status bar and changed square
  end

  return ok
end

function M.reveal(buf, x, y)
  local game, x, y = get_action_args(buf, x, y)
  local i = game.board:index(x, y)
  if not i then
    return false
  end

  if game.state == game_state.GAME_NOT_STARTED then
    game.board:place_mines(i)
    game.state = game_state.GAME_STARTED
    game.start_time = uv.hrtime()
    game.ui:start_status_redraw()
  elseif game.state ~= game_state.GAME_STARTED then
    return false
  end

  if not game.board:fill_reveal(x, y) then
    return false
  end

  if game.board.mines[i] then
    game.state = game_state.GAME_LOST
  elseif game.board.unrevealed_count == game.board.mine_count then
    game.state = game_state.GAME_WON
  end
  if game_state.is_game_over(game.state) then
    game.ui:stop_status_redraw()
  end

  -- TODO: redraw just the status bar and the changed square(s)
  game.ui:redraw_all()
  return true
end

return M
