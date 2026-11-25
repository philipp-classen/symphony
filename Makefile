# Unit tests: fast, in the test process
test:
	crystal spec spec/unit --verbose --order random

# E2E tests: slower, they start a test app as a process
test-e2e:
	crystal spec spec/e2e --verbose --order random

test-all:
	crystal spec --verbose --order random

linter:
	crystal run lib/ameba/bin/ameba.cr

linter-fix:
	crystal run lib/ameba/bin/ameba.cr -- --fix

format-check:
	crystal tool format --check

format-apply:
	crystal tool format
