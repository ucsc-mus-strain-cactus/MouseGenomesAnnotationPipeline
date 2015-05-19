

all: doTransMap 

doTransMap:
	${MAKE} -f rules/transMap.mk
