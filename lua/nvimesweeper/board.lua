local api, fn = vim.api, vim.fn

local M = {
  SQUARE_NONE = 0,
  SQUARE_FLAGGED = 1,
  SQUARE_MAYBE = 2,
  SQUARE_REVEALED = 3,
}

function M.is_revealable(state)
  return state == M.SQUARE_NONE or state == M.SQUARE_MAYBE
end

local Board = {}

function Board:is_valid(x, y)
  return x >= 0 and y >= 0 and x < self.width and y < self.height
end

function Board:index(x, y)
  return self:is_valid(x, y) and self.width * y + x + 1 or nil
end

-- Uses self.mine_count if mine_count argument is nil
function Board:place_mines(safe_x, safe_y, seed, mine_count)
  mine_count = mine_count or self.mine_count
  self.mines = {}
  self.mine_count = 0

  local function is_adjacent(x, y, x2, y2)
    return math.abs(x - x2) <= 1 and math.abs(y - y2) <= 1
  end

  api.nvim_set_var("_nvimesweeper_seed", fn.srand(seed))
  local function rand(max_excl)
    return api.nvim_eval "rand(g:_nvimesweeper_seed)" % max_excl
  end

  for _ = 1, mine_count do
    local x, y, i
    repeat
      x = rand(self.width)
      y = rand(self.height)
      i = self:index(x, y)
    until (
        self.unrevealed_count - self.mine_count <= 8
        or not is_adjacent(safe_x, safe_y, x, y)
      ) and not self.mines[i]

    self.mines[i] = true
    self.mine_count = self.mine_count + 1
    for ay = y - 1, y + 1 do
      for ax = x - 1, x + 1 do
        local ai = self:index(ax, ay)
        if ai then
          self.danger[ai] = self.danger[ai] + 1
        end
      end
    end
  end
end

function Board:reset()
  self.flag_count = 0
  self.unrevealed_count = self.width * self.height
  self.mine_count = 0
  self.mines = {}

  for i = 1, self.width * self.height do
    self.state[i] = M.SQUARE_NONE
    self.danger[i] = 0
  end
end

function Board:flag_unrevealed(i, new_state)
  if new_state == M.SQUARE_REVEALED then
    return false
  end

  local state = self.state[i]
  if state == M.SQUARE_REVEALED then
    return false
  elseif state == new_state then
    return true
  end

  if new_state == M.SQUARE_FLAGGED then
    self.flag_count = self.flag_count + 1
  elseif state == M.SQUARE_FLAGGED then
    self.flag_count = self.flag_count - 1
  end

  self.state[i] = new_state
  return true
end

function Board:reveal_square(i)
  local state = self.state[i]
  if not M.is_revealable(state) then
    return false
  end

  self.state[i] = M.SQUARE_REVEALED
  self.unrevealed_count = self.unrevealed_count - 1
  return true
end

function Board:fill_reveal(x, y, reveal_cb)
  local i = self:index(x, y)
  if not i then
    return 0
  end

  -- fill-reveal surrounding squares with 0 danger score
  local prev_unrevealed_count = self.unrevealed_count
  local needs_reveal = { { x, y, i } }
  while #needs_reveal > 0 do
    local top = needs_reveal[#needs_reveal]
    local tx, ty, ti = top[1], top[2], top[3]
    needs_reveal[#needs_reveal] = nil

    local ok = self:reveal_square(ti)
    if ok and reveal_cb then
      reveal_cb(tx, ty, ti)
    end
    if ok and self.danger[ti] == 0 then
      for ay = ty - 1, ty + 1 do
        for ax = tx - 1, tx + 1 do
          local ai = self:index(ax, ay)
          if ai and M.is_revealable(self.state[ai]) then
            needs_reveal[#needs_reveal + 1] = { ax, ay, ai }
          end
        end
      end
    end
  end

  return prev_unrevealed_count - self.unrevealed_count
end

function M.new_board(width, height)
  local board = vim.deepcopy(Board)
  board.width = width
  board.height = height
  board.state = {}
  board.danger = {}

  board:reset()
  return board
end

return M
