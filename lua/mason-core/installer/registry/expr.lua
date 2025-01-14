local _ = require "mason-core.functional"
local Result = require "mason-core.result"

local M = {}

local parse_expr = _.compose(
    _.apply_spec {
        value_expr = _.head,
        filters = _.drop(1),
    },
    _.filter(_.complement(_.equals "")),
    _.map(_.trim),
    _.split "|"
)

local FILTERS = {
    format = _.format,
    gsub = _.gsub,
    to_lower = _.to_lower,
    to_upper = _.to_upper,
    trim = _.trim,
    trim_start = _.trim_start,
    tostring = tostring,
}

---@generic T : table
---@param tbl T
---@return T
local function shallow_clone(tbl)
    local res = {}
    for k, v in pairs(tbl) do
        res[k] = v
    end
    return res
end

---@param str string
---@param ctx table<string, any>
function M.eval(str, ctx)
    ctx = shallow_clone(ctx)
    return Result.pcall(function()
        setmetatable(ctx, { __index = FILTERS })
        return _.gsub("{{([^}]+)}}", function(expr)
            local components = parse_expr(expr)
            local value = assert(
                setfenv(
                    assert(
                        loadstring("return " .. components.value_expr),
                        ("Failed to parse value :%q."):format(components.value_expr)
                    ),
                    ctx
                )(),
                ("Value is nil: %q."):format(components.value_expr)
            )
            return _.reduce(
                _.apply_to,
                value,
                _.map(function(filter_expr)
                    local filter = setfenv(
                        assert(
                            loadstring("return " .. filter_expr),
                            ("Failed to parse filter: %q."):format(filter_expr)
                        ),
                        ctx
                    )()
                    assert(type(filter) == "function", ("Invalid filter expression: %q."):format(filter_expr))
                    return filter
                end, components.filters)
            )
        end, str)
    end)
end

return M
