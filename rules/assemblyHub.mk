include defs.mk

# jobTree configuration
batchSystem = singleMachine
maxThreads = 20
maxCpus = 1024
defaultMemory = 8589934592
maxJobDuration = 36000

ifneq (${gencodeSubset},)
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}/all
assemblyHubDir = ${comparativeAnnotationDir}/assemblyHub
jobTreeDir = $(shell pwd)/.${gencodeSubset}_assemblyHub
log = $(shell pwd)/${gencodeSubset}_assemblyHubJobTree.log
endif


all: assemblyHub

assemblyHub: ${gencodeSubsets:%=%.assemblyHub}

%.assemblyHub:
	${MAKE} -f rules/assemblyHub.mk assemblyHubGencodeSubset gencodeSubset=$*

ifneq (${gencodeSubset},)
assemblyHubGencodeSubset: ${assemblyHubDir}/DONE
endif


${assemblyHubDir}/DONE: ${comparativeAnnotationDir}/DONE
	if [ -d ${halJobTreeDir} ]; then rm -rf ${halJobTreeDir}; fi
	if [ -d ${assemblyHubDir} ]; then rm -rf ${assemblyHubDir}; mkdir ${assemblyHubDir}; fi
	bigBedDirs="$(shell /bin/ls -1d ${comparativeAnnotationDir}/bigBedfiles/* | paste -s -d ",")" ;\
	cd ../comparativeAnnotator && export PYTHONPATH=./ && export \
	PATH=./hal/bin/:./bin/:./sonLib/bin:./jobTree/bin:${PATH} && \
	python hal/assemblyHub/hal2assemblyHub.py ${halFile} ${assemblyHubDir} \
	--finalBigBedDirs $$bigBedDirs --maxThreads=${maxThreads} --batchSystem=singleMachine \
	--defaultMemory=${defaultMemory} --jobTree ${jobTreeDir} \
	--maxJobDuration ${maxJobDuration} --stats --shortLabel ${MSCA_VERSION} \
	--longLabel ${MSCA_VERSION} --hub ${MSCA_VERSION} &> ${log}
	touch $@
