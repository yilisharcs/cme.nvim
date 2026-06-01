---@meta _
-- Definition of Busted/luassert types for the LSP.

---@class luassert.modifier
---@field equal fun(expected: any, actual: any)
---@field same fun(expected: any, actual: any)
---@field ["true"] fun(v: any)
---@field ["false"] fun(v: any)
---@field ["nil"] fun(v: any)

---@class luassert
---@field are luassert.modifier
---@field is luassert.modifier
---@field is_not luassert.modifier
---@field is_true fun(v: any)
---@field is_false fun(v: any)
---@field is_nil fun(v: any)
---@field are_equal fun(expected: any, actual: any)
---@field are_same fun(expected: any, actual: any)

---@type luassert
assert = assert --[[@as any]]
