
all: transMap comparativeAnnotator

transMap:
	${MAKE} -f rules/transMap.mk

comparativeAnnotator: transMap
	${MAKE} -f rules/comparativeAnnotator.mk

