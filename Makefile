.PHONY: test

all: chaining transMap comparativeAnnotator

transMap: chaining
	${MAKE} -f rules/transMap.mk

chaining:
	${MAKE} -f rules/chaining.mk


comparativeAnnotator: transMap
	${MAKE} -f rules/comparativeAnnotator.mk

test:
	python scripts/parseSDP_test.py
	python -m doctest -v scripts/*.py

augustus:
	${MAKE} -f rules/augustusComparativeAnnotator.mk
