install:
	cp -r lua	$(INST_LUADIR)
	cp -r bin	$(INST_PREFIX)
	cp -r plugin	$(INST_PREFIX)
	cp -r doc	$(INST_PREFIX)
	cp LICENSE	$(INST_PREFIX)/doc/LICENSE
	cp README.md	$(INST_PREFIX)/doc/README.md

.PHONY: doc doc_watch
ARGS := --headless -u NONE
REPO ?= $(HOME)/Projects/github.com/yilisharcs/cme.nvim

doc:
	@nvim $(ARGS) -l scripts/doc.lua

doc_watch:
	@find $(REPO) -name "*.lua" | entr -cs "make doc > /dev/null"

sync:
	nu scripts/sync.nu
