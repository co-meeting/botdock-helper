.PHONY: test

MOCHA = ./node_modules/.bin/mocha

test:
	$(MOCHA) test

test-coverage:
	$(MOCHA) -R html-cov test > coverage.html