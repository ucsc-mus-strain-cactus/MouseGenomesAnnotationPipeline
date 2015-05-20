
all: transMap comparativeAnnotator

transMap:
	${MAKE} -f rules/transMap.mk

comparativeAnnotator:
	${MAKE} -f rules/comparativeAnnotator.mk