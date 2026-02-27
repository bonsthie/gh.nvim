print("hello from proto")

vim.api.nvim_create_user_command("Gh", function(opts)
	local ret = require("cmd.gh").run(opts.fargs)
	print(ret.ok and ret.stdout or ret.stderr)
end, { nargs = "*" })

vim.api.nvim_create_user_command("GhReview", function(opts)
	require("review").review(opts.fargs[1])
end, { nargs = "*" })
