---@meta _
-- Definition of Busted/luassert types for the LSP.

error("Cannot require a meta file")

---@class luassert
--- Shorthand identifiers only; modifier chains like `assert.are.nil`
--- use Lua keywords, which cannot be used as field names after a dot.
---
---@field truthy fun(v: any)
---@field falsy fun(v: any)
---@field is_true fun(v: any)
---@field is_false fun(v: any)
---@field is_nil fun(v: any)
---@field is_not_nil fun(v: any)
---@field are_equal fun(expected: any, actual: any)
---@field are_same fun(expected: any, actual: any)

---@type luassert
assert = assert --[[@as any]]
