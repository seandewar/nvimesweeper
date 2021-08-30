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
  ui:redraw_all()
  ui:focus_board()

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

  local function should_reveal(state)
    return state == board_mod.SQUARE_NONE or state == board_mod.SQUARE_MAYBE
  end

  local state = game.board.state[i]
  if not should_reveal(state) then
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

  -- fill-reveal surrounding squares with 0 danger score
  local needs_reveal = { { x, y } }
  while #needs_reveal > 0 do
    local top = needs_reveal[#needs_reveal]
    local tx, ty = top[1], top[2]
    local ti = game.board:index(tx, ty)
    needs_reveal[#needs_reveal] = nil

    if ti and should_reveal(game.board.state[ti]) then
      game.board:reveal_square(ti)
      if game.board.danger[ti] == 0 then
        for ay = ty - 1, ty + 1 do
          for ax = tx - 1, tx + 1 do
            local ai = game.board:index(ax, ay)
            if ai and should_reveal(game.board.state[ai]) then
              needs_reveal[#needs_reveal + 1] = { ax, ay }
            end
          end
        end
      end
    end
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
