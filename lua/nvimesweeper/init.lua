local fn, api, uv = vim.fn, vim.api, vim.loop

local M = {
  games = {},
}

function M.reload()
  package.loaded.nvimesweeper = nil
  return require "nvimesweeper"
end

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
  local buf = api.nvim_create_buf(true, true)
  if buf == 0 then
    error "[nvimesweeper] failed to create game buffer!"
    return nil
  end

  api.nvim_buf_set_name(buf, "[nvimesweeper " .. buf .. "]")
  api.nvim_buf_set_option(buf, "modifiable", false)

  local ok, _ = pcall(vim.cmd, "tab sbuffer " .. buf)
  if not ok then
    error "[nvimesweeper] failed to open game window!"
    api.nvim_buf_delete(buf, { force = true })
    return nil
  end

  local game = {
    mine_count = mine_count,
    rng_seed = rng_seed,
    start_time = uv.hrtime(),
    board = M.new_board(width, height),
    buf = buf,
  }

  -- TODO: temp test
  game.board:place_mines(game.mine_count)
  api.nvim_buf_set_option(buf, "modifiable", true)
  for k, v in pairs(game.board.mines) do
    api.nvim_buf_set_lines(game.buf, -2, -2, false, {tostring(k)})
  end
  api.nvim_buf_set_option(buf, "modifiable", false)

  return game
end

function M.play_cmd(args)
  -- TODO: parse command args if provided; otherwise prompt instead

  local width = fn.input("How many squares in width? ", "20")
  local height = fn.input("How many squares in height? ", "20")
  local mine_count = fn.input("How many mines? ", "9")

  width = tonumber(width)
  height = tonumber(height)
  mine_count = tonumber(mine_count)

  if
    not width
    or not height
    or not mine_count
    or width <= 0
    or height <= 0
    or mine_count <= 0
  then
    error "[nvimesweeper] inputs must be positive integers!"
    return
  end

  M.new_game(width, height, mine_count)
end

return M
