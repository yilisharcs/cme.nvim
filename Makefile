doc:
	nvim --clean --headless -l scripts/docgen.lua

repro:
	nvim --clean -u scripts/repro.lua

check: lint format

lint:
	VIMRUNTIME=$$(nvim --clean --headless --cmd 'lua io.stdout:write(vim.env.VIMRUNTIME)' -c 'q') \
	lua-language-server --check . --checklevel=Hint

format:
	stylua .

test:
	nvim --clean --headless -l tests/run.lua

.PHONY: doc repro check lint format test
