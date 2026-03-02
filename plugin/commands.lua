print("hello from proto")

local review = require("review")

vim.api.nvim_create_user_command("Gh", function(opts)
	local ret = require("cmd.gh").run(opts.fargs)
	print(ret.ok and ret.stdout or ret.stderr)
end, { nargs = "*" })

vim.api.nvim_create_user_command("GhReview", function(opts)
	review.review(opts.fargs[1])
end, { nargs = "*" })

vim.api.nvim_create_user_command("GhClose", function()
	local snap = review.snapshot
	if not snap then
		vim.notify("No snapshot to restore", vim.log.levels.WARN)
		return
	end

	require("snapshot").restore_tab_state(snap)
end, {})


