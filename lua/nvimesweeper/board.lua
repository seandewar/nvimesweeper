local M = {
  SQUARE_NONE = 0,
  SQUARE_FLAGGED = 1,
  SQUARE_REVEALED = 2,
}

local Board = {}

function Board:index(x, y)
  return self.width * y + x + 1
end

function Board:is_valid(x, y)
  return x >= 0 and y >= 0 and x < self.width and y < self.height
end

function Board:place_mines(safe_x, safe_y, mine_count)
  for _ = 1, mine_count do
    local x, y, i
    repeat -- potentially O(infinity) ;)
      x = math.random(0, self.width - 1)
      y = math.random(0, self.height - 1)
      i = self:index(x, y)
    until (x ~= safe_x or y ~= safe_y) and not self.mines[i]

    self.mines[i] = true
    for y2 = y - 1, y + 1 do
      for x2 = x - 1, x + 1 do
        if self:is_valid(x2, y2) then
          local i2 = self:index(x2, y2)
          self.danger[i2] = self.danger[i2] + 1
        end
      end
    end
  end
end

function Board:reset()
  self.mines = {}
  -- fill these tables as arrays for performance benefits
  for i = 1, self.width * self.height do
    self.state[i] = M.SQUARE_NONE
    self.danger[i] = 0
  end
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
