-- Coroutine cutscene runner. Inside a script function call S.wait(seconds)
-- or S.waitUntil(fn); the coroutine resumes once the condition holds.
local S = { tasks = {} }

local function step(task, ...)
  local ok, req = coroutine.resume(task.co, ...)
  if not ok then error(tostring(req) .. "\n" .. debug.traceback(task.co), 0) end
  task.waitT, task.cond = 0, nil
  if type(req) == "table" then
    task.waitT = req.wait or 0
    task.cond = req.cond
  end
end

function S.run(fn, ...)
  local task = { co = coroutine.create(fn), waitT = 0 }
  step(task, ...)
  if coroutine.status(task.co) ~= "dead" then
    table.insert(S.tasks, task)
  end
  return task
end

function S.wait(t)
  coroutine.yield({ wait = t })
end

function S.waitUntil(fn)
  coroutine.yield({ cond = fn })
end

function S.update(dt)
  local i = 1
  while i <= #S.tasks do
    local task = S.tasks[i]
    local ready
    if task.cond then
      ready = task.cond()
    else
      task.waitT = task.waitT - dt
      ready = task.waitT <= 0
    end
    if ready and coroutine.status(task.co) == "suspended" then step(task) end
    if coroutine.status(task.co) == "dead" then
      table.remove(S.tasks, i)
    else
      i = i + 1
    end
  end
end

function S.clear()
  S.tasks = {}
end

function S.busy()
  return #S.tasks > 0
end

return S
