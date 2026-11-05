local default_rules = {
	{ folder = "[Dd]ownloads", by = "mtime", reverse = true, dir_first = true },
}

local rules = default_rules

local function matches(rule, cwd_str)
	if rule.folder then
		return cwd_str:lower():match("/" .. rule.folder:lower() .. "/?$") ~= nil
	elseif rule.pattern then
		return cwd_str:match(rule.pattern) ~= nil
	elseif rule.path then
		return cwd_str == rule.path
	end
	return false
end

local function setup(self, opts)
	local custom = (type(self) == "table" and self.setup) and opts or self
	if type(custom) == "table" then
		rules = custom
	end

	ps.sub("ind-sort", function(opt)
		local cwd = tostring(cx.active.current.cwd)
		for _, r in ipairs(rules) do
			if matches(r, cwd) then
				opt.by = r.by or "mtime"
				if r.reverse ~= nil then
					opt.reverse = r.reverse
				else
					opt.reverse = (opt.by == "mtime")
				end
				if r.dir_first ~= nil then
					opt.dir_first = r.dir_first
				else
					opt.dir_first = true
				end
				return opt
			end
		end

		opt.by, opt.reverse, opt.dir_first = "natural", false, true
		return opt
	end)
end

return { setup = setup }
