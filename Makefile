include defs.mk
.PHONY: test genomeFiles chaining gencode transMap referenceComparativeAnnotator comparativeAnnotator \
	hints augustusComparativeAnnotator metrics augustusMetrics 

all: genomeFiles chaining transMap referenceComparativeAnnotator comparativeAnnotator metrics

augustus: all hints augustusComparativeAnnotator metrics augustusMetrics

genomeFiles:
	${MAKE} -f rules/genomeFiles.mk

chaining: genomeFiles
	${MAKE} -f rules/chaining.mk

gencode: genomeFiles
	${MAKE} -f rules/gencode.mk

transMap: chaining gencode
	${MAKE} -f rules/transMap.mk

referenceComparativeAnnotator: transMap
	${MAKE} -f rules/referenceComparativeAnnotator.mk

comparativeAnnotator: referenceComparativeAnnotator
	${MAKE} -f rules/comparativeAnnotator.mk

hints:
	${MAKE} -f rules/augustusHints.mk
	${MAKE} -f rules/augustusHintsFinish.mk

augustusComparativeAnnotator: comparativeAnnotator
	${MAKE} -f rules/augustusComparativeAnnotator.mk

metrics: comparativeAnnotator
	${MAKE} -f rules/metrics.mk

augustusMetrics: augustusComparativeAnnotator
	${MAKE} -f rules/augustusMetrics.mk

test:
	python scripts/parseSDP_test.py
	python -m doctest -v scripts/*.py

clean:
	${MAKE} -f rules/genomeFiles.mk clean
	${MAKE} -f rules/chaining.mk clean
	${MAKE} -f rules/gencode.mk clean
	${MAKE} -f rules/transMap.mk clean
	${MAKE} -f rules/referenceComparativeAnnotator.mk clean
	${MAKE} -f rules/comparativeAnnotator.mk clean
	${MAKE} -f rules/metrics.mk clean

cleanAugustus:
	${MAKE} -f rules/augustusComparativeAnnotator.mk clean
	${MAKE} -f rules/augustusMetrics.mk clean
	${MAKE} -f rules/augustusHintsFinish clean
