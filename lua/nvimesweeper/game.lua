local api, uv = vim.api, vim.loop

local board_mod = require "nvimesweeper.board"
local error = require("nvimesweeper.util").error

local M = {
  GAME_NOT_STARTED = 0,
  GAME_STARTED = 1,
  GAME_WON = 2,
  GAME_LOST = 3,

  games = {},
}

local namespace = api.nvim_create_namespace "nvimesweeper"

local Game = {}

function Game:enable_drawing(enable)
  api.nvim_buf_set_option(self.buf, "modifiable", enable)
end

function Game:redraw_status()
  local function time_string()
    local nanoseconds = uv.hrtime() - self.start_time
    local seconds = math.floor(nanoseconds / 1000000000)
    local minutes = math.floor(seconds / 60)
    return string.format("Time: %02d:%02d", minutes, seconds % 60)
  end

  local status
  if self.state == M.GAME_NOT_STARTED then
    status = "The game will start after you reveal a square..."
  elseif self.state == M.GAME_STARTED then
    status = time_string()
  elseif self.state == M.GAME_WON then
    status = "Congratulations, you win! " .. time_string()
  elseif self.state == M.GAME_LOST then
    status = "You lost; better luck next time! " .. time_string()
  end

  api.nvim_buf_set_lines(self.buf, 0, 3, false, {
    status,
    "Flagged: " .. self.flags_used .. "/" .. self.mine_count,
    "",
  })
end

function Game:full_redraw()
  self:enable_drawing(true)
  self:redraw_status()

  -- Create the lines to draw from the rows of the game board
  local lines = {}
  local i = 1
  for y = 0, self.board.height - 1 do
    local row = {}
    for x = 0, self.board.width - 1 do
      local state = self.board.state[i]
      local char
      if state == board_mod.SQUARE_NONE then
        char = "#"
      elseif state == board_mod.SQUARE_FLAGGED then
        char = "!"
      elseif state == board_mod.SQUARE_REVEALED then
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

  -- Draw the board
  api.nvim_buf_set_lines(self.buf, 3, 3 + #lines, false, lines)

  -- Place extended marks for each board square
  i = 1
  for y = 0, self.board.height - 1 do
    for x = 0, self.board.width - 1 do
      local hl_group
      local state = self.board.state[i]
      if state == board_mod.SQUARE_FLAGGED then
        hl_group = "NvimesweeperFlagged"
      elseif state == board_mod.SQUARE_REVEALED then
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
        3 + y,
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

  self:enable_drawing(false)
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
  api.nvim_buf_set_keymap(
    buf,
    "n",
    "<CR>",
    "<Cmd>lua require('nvimesweeper.game').reveal_square()<CR>",
    { noremap = true }
  )
  api.nvim_buf_set_keymap(
    buf,
    "n",
    "<Space>",
    "<Cmd>lua require('nvimesweeper.game').place_flag()<CR>",
    { noremap = true }
  )

  local game = vim.deepcopy(Game)
  game.mine_count = mine_count
  game.flags_used = 0
  game.buf = buf
  game.board = board_mod.new_board(width, height)
  game.board_extmarks = {}
  game.state = M.GAME_NOT_STARTED

  game:full_redraw()
  M.games[buf] = game
  return game
end

function M.cleanup_game(buf)
  local game = M.games[buf]
  if game.redraw_timer then
    game.redraw_timer:stop()
  end

  M.games[buf] = nil
end

local function get_action_args(buf, x, y)
  if not buf then
    buf = api.nvim_get_current_buf()
    local pos = api.nvim_win_get_cursor(0)
    x = pos[2]
    y = pos[1] - 1 -- return row is 1-indexed
    y = y - 3 -- HACK: get position from extmark
  end
  return M.games[buf], x, y
end

function M.place_flag(buf, x, y)
  local game, x, y = get_action_args(buf, x, y)

  if game.state ~= M.GAME_STARTED then
    return
  end

  local i = game.board:index(x, y)
  local state = game.board.state
  if state[i] == board_mod.SQUARE_NONE then
    state[i] = board_mod.SQUARE_FLAGGED
    game.flags_used = game.flags_used + 1
  elseif state[i] == board_mod.SQUARE_FLAGGED then
    state[i] = board_mod.SQUARE_NONE
    game.flags_used = game.flags_used - 1
  end

  -- TODO: redraw just the status bar and the changed square
  game:full_redraw()
end

function M.reveal_square(buf, x, y)
  local game, x, y = get_action_args(buf, x, y)

  local board = game.board
  local state = board.state
  local i = board:index(x, y)
  if state[i] ~= board_mod.SQUARE_NONE then
    return
  end

  if game.state == M.GAME_NOT_STARTED then
    board:place_mines(x, y, game.mine_count)
    game.state = M.GAME_STARTED
    game.start_time = uv.hrtime()

    game.redraw_timer = uv.new_timer()
    game.redraw_timer:start(
      0,
      500,
      vim.schedule_wrap(function()
        game:enable_drawing(true)
        game:redraw_status()
        game:enable_drawing(false)
      end)
    )
  elseif game.state ~= M.GAME_STARTED then
    return
  end

  -- fill-reveal surrounding (unflagged) squares with a danger score of 0
  local danger = board.danger
  local needs_reveal = { { x, y } }
  while #needs_reveal > 0 do
    local top = needs_reveal[#needs_reveal]
    local tx, ty = top[1], top[2]
    needs_reveal[#needs_reveal] = nil

    if board:is_valid(tx, ty) then
      local ti = board:index(tx, ty)

      if state[ti] == board_mod.SQUARE_NONE then
        state[ti] = board_mod.SQUARE_REVEALED

        if danger[ti] == 0 then
          for y2 = ty - 1, ty + 1 do
            for x2 = tx - 1, tx + 1 do
              if state[board:index(x2, y2)] == board_mod.SQUARE_NONE then
                needs_reveal[#needs_reveal + 1] = { x2, y2 }
              end
            end
          end
        end
      end
    end
  end

  -- TODO: redraw just the status bar and the changed square(s)
  game:full_redraw()
end

return M
