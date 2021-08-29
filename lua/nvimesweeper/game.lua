local api, uv = vim.api, vim.loop

local error = require("nvimesweeper.util").error

local M = {}

local STATE_NONE = 0
local STATE_FLAGGED = 1
local STATE_UNCOVERED = 2

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

  function board:danger(x, y)
    local danger = 0
    for ny = y - 1, y + 1 do
      for nx = x - 1, x + 1 do
        if self:valid(nx, ny) and self.mines[self:index(nx, ny)] then
          danger = danger + 1
        end
      end
    end

    return danger
  end

  function board:place_mines(mine_count)
    for _ = 1, mine_count do
      -- this loop is potentially O(infinity) ;)
      local i
      repeat
        local x = math.random(0, self.width - 1)
        local y = math.random(0, self.height - 1)
        i = self:index(x, y)
      until not self.mines[i]

      self.mines[i] = true
    end
  end

  function board:reset_state()
    -- fill the table as an array for performance
    for i = 1, self.width * self.height do
      self.state[i] = STATE_UNCOVERED
    end
  end

  board:reset_state()
  return board
end

function M.new_game(width, height, mine_count)
  local buf = api.nvim_create_buf(true, true)
  if buf == 0 then
    error "failed to create game buffer!"
    return nil
  end

  api.nvim_buf_set_name(buf, "[nvimesweeper " .. buf .. "]")
  api.nvim_buf_set_option(buf, "modifiable", false)

  local ok, _ = pcall(vim.cmd, "tab sbuffer " .. buf)
  if not ok then
    error "failed to open game window!"
    api.nvim_buf_delete(buf, { force = true })
    return nil
  end

  local game = {
    board = M.new_board(width, height),
    mine_count = mine_count,
    start_time = uv.hrtime(),
    buf = buf,
  }

  function game:redraw()
    api.nvim_buf_set_option(self.buf, "modifiable", true)

    local lines = {}
    local i = 1
    for y = 0, self.board.height - 1 do
      local row = {}
      for x = 0, self.board.width - 1 do
        local state = self.board.state[i]
        local char
        if state == STATE_NONE then
          char = "#"
        elseif state == STATE_FLAGGED then
          char = "!"
        elseif state == STATE_UNCOVERED then
          char = self.board.mines[i] and "*"
            or tostring(self.board:danger(x, y))
        end

        row[x + 1] = char
        i = i + 1
      end

      lines[y + 1] = table.concat(row)
    end

    api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
    api.nvim_buf_set_option(self.buf, "modifiable", false)
  end

  game.board:place_mines(game.mine_count) -- TODO: only after 1st uncover
  game:redraw()
  return game
end

return M
