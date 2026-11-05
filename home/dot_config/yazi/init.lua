require("folder-rules"):setup({
	{ folder = "downloads", by = "mtime", reverse = true, dir_first = true },
	-- Add more folders here as needed, for example:
	-- { folder = "screenshots", by = "mtime", reverse = true, dir_first = true },
	-- { folder = "videos",      by = "size",  reverse = true, dir_first = true },
})
