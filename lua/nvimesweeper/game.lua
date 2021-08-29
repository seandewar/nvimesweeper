local api, uv = vim.api, vim.loop

local error = require("nvimesweeper.util").error

local M = {}

local STATE_NONE = 0
local STATE_FLAGGED = 1
local STATE_REVEALED = 2

local namespace = api.nvim_create_namespace "nvimesweeper"

function M.new_board(width, height)
  local board = {
    width = width,
    height = height,
    state = {},
    danger = {},
  }

  function board:index(x, y)
    return self.width * y + x + 1
  end

  function board:is_valid(x, y)
    return x >= 0 and y >= 0 and x < self.width and y < self.height
  end

  function board:place_mines(mine_count)
    for _ = 1, mine_count do
      local x, y, i
      repeat
        x = math.random(0, self.width - 1)
        y = math.random(0, self.height - 1)
        i = self:index(x, y)
      until not self.mines[i] -- this loop is potentially O(infinity) ;)

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

  function board:reset()
    self.mines = {}
    -- fill these tables as arrays for performance benefits
    for i = 1, self.width * self.height do
      -- self.state[i] = STATE_NONE
      self.state[i] = STATE_REVEALED
      self.danger[i] = 0
    end
  end

  board:reset()
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

  api.nvim_win_set_option(0, "wrap", false)
  vim.cmd(
    "autocmd BufUnload <buffer="
      .. buf
      .. "> ++once "
      .. "lua require('nvimesweeper.game').cleanup_game("
      .. buf
      .. ")"
  )

  local game = {
    board = M.new_board(width, height),
    mine_count = mine_count,
    start_time = uv.hrtime(),
    buf = buf,
    board_extmarks = {},
  }

  function game:full_redraw()
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
        elseif state == STATE_REVEALED then
          if self.board.mines[i] then
            char = "*"
          else
            local danger = self.board.danger[i]
            char = danger > 0 and tostring(danger) or "."
          end
        end

        row[x + 1] = char
        i = i + 1
      end

      lines[y + 1] = table.concat(row)
    end

    api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)

    i = 1
    for y = 0, self.board.height - 1 do
      for x = 0, self.board.width - 1 do
        local hl_group
        local state = self.board.state[i]
        if state == STATE_FLAGGED then
          hl_group = "NvimesweeperFlagged"
        elseif state == STATE_REVEALED then
          if self.board.mines[i] then
            hl_group = "NvimesweeperMine"
          else
            local danger = self.board.danger[i]
            if danger > 0 then
              hl_group = "NvimesweeperDanger" .. danger
            end
          end
        end

        self.board_extmarks[i] = api.nvim_buf_set_extmark(
          self.buf,
          namespace,
          y,
          x,
          {
            id = self.board_extmarks[i],
            end_col = x + 1,
            hl_group = hl_group,
          }
        )
        i = i + 1
      end
    end

    api.nvim_buf_set_option(self.buf, "modifiable", false)
  end

  game.board:place_mines(game.mine_count) -- TODO: only after 1st uncover
  game:full_redraw()
  return game
end

function M.cleanup_game(buf)
  -- TODO: this isn't needed right now
end

return M
