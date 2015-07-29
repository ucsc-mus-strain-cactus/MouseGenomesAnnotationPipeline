.PHONY: test

all: transMap comparativeAnnotator

transMap:
	${MAKE} -f rules/transMap.mk

comparativeAnnotator: transMap
	${MAKE} -f rules/comparativeAnnotator.mk

test:
	python scripts/parseSDP_test.py
	python -m doctest -v scripts/*.py

augustus:
	${MAKE} -f rules/augustusComparativeAnnotator.mk