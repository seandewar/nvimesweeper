local api, uv = vim.api, vim.loop

local game_state = require "nvimesweeper.game_state"
local board_mod = require "nvimesweeper.board"
local ui_mod = require "nvimesweeper.ui"

local M = {}

local Game = {}

function M.new_game(width, height, mine_count, seed, open_tab)
  local board = board_mod.new_board(width, height)
  board.mine_count = mine_count

  local game = setmetatable({
    state = game_state.GAME_NOT_STARTED,
    seed = seed,
    board = board,
  }, {
    __index = Game,
  })
  game.ui = ui_mod.new_ui(game, open_tab)

  return game
end

local function action_args(buf, x, y)
  buf = buf or api.nvim_get_current_buf()
  local game = ui_mod.uis[buf].game
  if not game then
    return nil
  end

  if not x then
    x, y = game.ui:win_to_board_pos()
  end
  return game, x, y, game.board:index(x, y)
end

-- cycles NONE -> FLAGGED -> MAYBE if state == nil; otherwise toggle state
function M.place_marker(new_state, buf, x, y)
  local game, nx, ny, i = action_args(buf, x, y)
  x, y = nx, ny
  if game_state.is_game_over(game.state) or not i then
    return false
  end

  local state = game.board.state[i]
  if not new_state then
    if state == board_mod.SQUARE_NONE then
      new_state = board_mod.SQUARE_FLAGGED
    elseif state == board_mod.SQUARE_FLAGGED then
      new_state = board_mod.SQUARE_MAYBE
    else
      new_state = board_mod.SQUARE_NONE
    end
  elseif state == new_state then
    new_state = board_mod.SQUARE_NONE
  end

  local ok = game.board:flag_unrevealed(i, new_state)
  if ok then
    game.ui:redraw_status()
    game.ui:redraw_board(x, y, x, y)
  end

  return ok
end

function M.reveal(buf, x, y)
  local game, nx, ny, i = action_args(buf, x, y)
  x, y = nx, ny
  if game_state.is_game_over(game.state) or not i then
    return false
  end

  local state = game.board.state[i]
  if
    game.state == game_state.GAME_NOT_STARTED and board_mod.is_revealable(state)
  then
    game.board:place_mines(x, y, game.seed)
    game.state = game_state.GAME_STARTED
    game.start_time = uv.hrtime()
    game.ui:start_status_redraw()
  end

  local changed_x1, changed_y1 = game.board.width, game.board.height
  local changed_x2, changed_y2 = 0, 0
  if
    game.board:fill_reveal(x, y, function(sx, sy, _)
      changed_x1 = math.min(changed_x1, sx)
      changed_y1 = math.min(changed_y1, sy)
      changed_x2 = math.max(changed_x2, sx)
      changed_y2 = math.max(changed_y2, sy)
    end) == 0
  then
    return false
  end

  if game.board.mines[i] then
    game.state = game_state.GAME_LOST
  elseif game.board.unrevealed_count == game.board.mine_count then
    game.state = game_state.GAME_WON
  end

  game.ui:redraw_status()
  if game_state.is_game_over(game.state) then
    game.ui:stop_status_redraw()
    game.ui:redraw_board()
  else
    game.ui:redraw_board(changed_x1, changed_y1, changed_x2, changed_y2)
  end

  return true
end

return M
