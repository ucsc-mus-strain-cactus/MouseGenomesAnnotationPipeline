include defs.mk
.PHONY: test

all: genomeFiles chaining transMap comparativeAnnotator metrics

genomeFiles:
	${MAKE} -f rules/genomeFiles.mk

chaining: genomeFiles
	${MAKE} -f rules/chaining.mk

gencode: genomeFiles
	${MAKE} -f rules/gencode.mk

transMap: chaining gencode
	${MAKE} -f rules/transMap.mk

comparativeAnnotator: transMap
	${MAKE} -f rules/comparativeAnnotator.mk

metrics: comparativeAnnotator
	${MAKE} -f rules/metrics.mk

test:
	python scripts/parseSDP_test.py
	python -m doctest -v scripts/*.py
