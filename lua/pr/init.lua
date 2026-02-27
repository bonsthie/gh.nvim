local Pr = require('pr.pr')

local extensions = {
	'pr.diff',
}

for _, mod_path in ipairs(extensions) do
	local ok, extender = pcall(require, mod_path)
	if ok then
		if type(extender) == 'function' then
			extender(Pr)
		elseif type(extender) == 'table' and type(extender.extend) == 'function' then
			extender.extend(Pr)
		end
	else
		vim.notify(string.format('Failed to load PR extension: %s', mod_path), vim.log.levels.ERROR)
	end
end

return Pr
