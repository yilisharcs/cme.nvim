---@meta _
--- Definition file for LuaLS type information.

error("Cannot require a meta file")

---@class (partial) cme.Opts: cme.Config

---@class cme.Counts
---@field E number Number of errors.
---@field W number Number of warnings.
---@field I number Number of informational messages.

---@class cme.JobContext
---@field job vim.SystemObj? Internal libuv job handle.
---@field line_fragment string Trailing data from the last chunk.
---@field queue string[] Collection of complete lines waiting for the UI.
---@field first_flush boolean True if this is the first batch of the job.
---@field flushing boolean Semaphore to prevent concurrent UI updates.
---@field efm string The active errorformat string for this job.
---@field counts cme.Counts Real-time message counters.
---@field cmd string The expanded command string being executed.

---@class cme.State
---@field active_job vim.SystemObj?
---@field last_cmd string?
---@field watch_autocmd number?
---@field cwd string?

---@type cme.Opts?
vim.g.cme = vim.g.cme --[[@as any]]
