local uv = vim.loop

local M = {
  games = {},
}

local STATE_UNTOUCHED = 0
local STATE_TOUCHED = 1
local STATE_FLAGGED = 2

function M.new_board(width, height)
  local board = {
    width = width,
    height = height,
    mines = {},
    state = {},
  }

  function board:index(x, y)
    return self.width * y + x + 1
  end

  function board:valid(x, y)
    return x >= 0 and y >= 0 and x < self.width and y < self.height
  end

  function board:has_mine(x, y)
    return self.mines[self:index(x, y)] == true
  end

  function board:danger(x, y)
    local danger = 0

    for ny = y - 1, y + 1 do
      for nx = x - 1, x + 1 do
        if self:valid(nx, ny) and self:has_mine(nx, ny) then
          danger = danger + 1
        end
      end
    end

    return danger
  end

  function board:place_mines(mine_count, rng_seed)
    if rng_seed then
      math.randomseed(rng_seed)
    end

    local random = math.random
    for _ = 1, mine_count do
      local x, y = random(0, self.width), random(0, self.height)
      self.mines[self:index(x, y)] = true
    end
  end

  function board:reset_state()
    -- fill the table as an array for performance
    for i = 1, self.width * self.height do
      self.state[i] = STATE_UNTOUCHED
    end
  end

  board:reset_state()
  return board
end

function M.new_game(width, height, mine_count, rng_seed)
  local game = {
    board = M.new_board(width, height),
    mine_count = mine_count,
    start_time = uv.hrtime(),
    rng_seed = rng_seed,
    buffer = 0,
  }

  return game
end

return M
