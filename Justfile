# vim@code{ envs = 'PLENARY_DIR=C:/apps/dotvim/bundle/plenary.nvim' }:
set shell := ['bash', '-uc']
set windows-shell := ["powershell", "-NoLogo", "-Command"]

TESTS_INIT := 'tests/minimal_init.lua'
TESTS_DIR := 'tests/'

test:
	nvim --headless --noplugin -i NONE -u {{TESTS_INIT}} -c "PlenaryBustedDirectory {{TESTS_DIR}} { minimal_init = '{{TESTS_INIT}}' }"
