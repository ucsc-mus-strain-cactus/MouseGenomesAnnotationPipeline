include defs.mk

ifneq (${gencodeSubset},)
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}
assemblyHubDir = ${comparativeAnnotationDir}/assemblyHub

# jobTree
jobTreeTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/assembly_hub/${mapTargetOrg}/${gencodeSubset}
jobTreeJobOutput = ${jobTreeTmpDir}/assembly_hub.out
jobTreeJobDir = ${jobTreeTmpDir}/jobTree
jobTreeDone = ${doneFlagDir}/assemblyHub.done


endif


all: assemblyHub

assemblyHub: ${gencodeSubsets:%=%.assemblyHub}

%.assemblyHub:
	${MAKE} -f rules/assemblyHub.mk assemblyHubGencodeSubset gencodeSubset=$*

ifneq (${gencodeSubset},)
assemblyHubGencodeSubset: ${jobTreeDone}

${jobTreeDone}:
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeTmpDir}
	bigBedDirs="$(shell /bin/ls -1d ${comparativeAnnotationDir}/bigBedfiles/* | paste -s -d ",")" ;\
	cd ../comparativeAnnotator && export PYTHONPATH=./ && \
	python hal/assemblyHub/hal2assemblyHub.py --batchSystem singleMachine --maxThreads 10 \
	--jobTree ${jobTreeJobDir} ${halFile} ${assemblyHubDir} \
	--finalBigBedDirs $$bigBedDirs --shortLabel ${GORILLA_VERSION} --longLabel ${GORILLA_VERSION} \
	--hub ${GORILLA_VERSION} &> ${jobTreeJobOutput}
	touch $@

endif