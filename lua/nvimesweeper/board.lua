local M = {
  SQUARE_NONE = 0,
  SQUARE_FLAGGED = 1,
  SQUARE_MAYBE = 2,
  SQUARE_REVEALED = 3,
}

local Board = {}

function Board:is_valid(x, y)
  return x >= 0 and y >= 0 and x < self.width and y < self.height
end

function Board:index(x, y)
  return self:is_valid(x, y) and self.width * y + x + 1 or nil
end

function Board:place_mines(safe_i)
  for _ = 1, self.mine_count do
    local x, y, i
    repeat -- potentially O(infinity) ;)
      x = math.random(0, self.width - 1)
      y = math.random(0, self.height - 1)
      i = self:index(x, y)
    until i ~= safe_i and not self.mines[i]

    self.mines[i] = true
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
  self.flags_used = 0
  self.mines = {}

  -- performance: fill these tables sequentually so they're treated as arrays
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

  self.flags_used = self.flags_used + (state ~= M.SQUARE_FLAGGED and 1 or -1)
  self.state[i] = new_state
  return true
end

function M.new_board(width, height, mine_count)
  local board = vim.deepcopy(Board)
  board.width = width
  board.height = height
  board.mine_count = mine_count
  board.state = {}
  board.danger = {}

  board:reset()
  return board
end

return M
