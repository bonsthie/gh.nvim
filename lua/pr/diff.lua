local git = require('cmd.git').cmd

---@class PrDiffFile
---@field base string
---@field head string
---@field type string

local function sanitize_suffix(file_name)
	return (file_name or ''):gsub('[^%w%.%-_]', '_')
end

local function write_temp_file(contents, label)
	local path = vim.fn.tempname()
	if label and label ~= '' then
		path = string.format('%s_%s', path, sanitize_suffix(label))
	end

	local fd, err = io.open(path, 'w')
	if not fd then
		return nil, err or string.format('Unable to open %s for writing', path)
	end

	fd:write(contents or '')
	fd:close()

	return path, nil
end

local function materialize_file_at_ref(file_name, ref)
	local spec = string.format('%s:%s', ref, file_name)
	local ret = git.show({ spec })
	if ret.ok then
		return write_temp_file(ret.stdout, spec)
	end

	local stderr = ret.stderr or ''
	if stderr:match('not in') then
		return write_temp_file('', spec)
	end

	return nil, stderr ~= '' and stderr or string.format('git show failed for %s', spec)
end


local function detect_type(file_name, contents)
	return vim.filetype.match({
		filename = file_name,
		contents = vim.split(contents, '\n')
	}) or 'text'
end



return function(Pr)
	---@param file_name string
	---@return PrDiffFile|nil, string|nil
	function Pr:get_file_diff(file_name)
		if not file_name or file_name == '' then
			return nil, 'file_name is required'
		end

		local base_file, base_err = materialize_file_at_ref(file_name, self.baseRefOid)
		if not base_file then
			return nil, base_err
		end

		local head_file, head_err = materialize_file_at_ref(file_name, self.headRefOid)
		if not head_file then
			return nil, head_err
		end

		return {
			base = base_file,
			head = head_file,
			type = detect_type(file_name, base_file)
		}, nil
	end
end
