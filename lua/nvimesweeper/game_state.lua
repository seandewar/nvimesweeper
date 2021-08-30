local M = {
  GAME_NOT_STARTED = 0,
  GAME_STARTED = 1,
  GAME_WON = 2,
  GAME_LOST = 3,
}

function M.is_game_over(state)
  return state == M.GAME_WON or state == M.GAME_LOST
end

return M
