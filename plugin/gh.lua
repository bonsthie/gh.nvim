print("hello from proto")

vim.api.nvim_create_user_command("Gh", function(opts)
	local ret = require("gh").run(opts.fargs)
	print(ret.ok and ret.stdout or ret.stderr)
end, { nargs = "*" })
