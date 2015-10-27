#####
# Assembly hub construction. Uses singleMachine because of weird bug on ku with liftovers.
#####

include defs.mk

ifneq (${gencodeSubset},)
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}
assemblyHubDir = ${comparativeAnnotationDir}/assemblyHub

# jobTree
jobTreeTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/assembly_hub/${gencodeSubset}
jobTreeJobOutput = ${jobTreeTmpDir}/assembly_hub.out
jobTreeJobDir = ${jobTreeTmpDir}/jobTree
jobTreeDone = ${DONE_FLAG_DIR}/assemblyHub.done


endif


all: assemblyHub

clean: ${gencodeSubsets:%=%.assemblyHubClean}

assemblyHub: ${gencodeSubsets:%=%.assemblyHub}

%.assemblyHub:
	${MAKE} -f rules/assemblyHub.mk assemblyHubGencodeSubset gencodeSubset=$*

%.assemblyHubClean:
	${MAKE} -f rules/assemblyHub.mk assemblyHubGencodeSubsetClean gencodeSubset=$*

ifneq (${gencodeSubset},)
assemblyHubGencodeSubset: ${jobTreeDone}

${jobTreeDone}:
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeTmpDir}
	bigBedDirs="$(shell /bin/ls -1d ${comparativeAnnotationDir}/bigBedfiles/* | paste -s -d ",")" ;\
	cd ../comparativeAnnotator && python hal/assemblyHub/hal2assemblyHub.py ${jobTreeOpts} \
	--batchSystem singleMachine --jobTree ${jobTreeJobDir} ${halFile} ${assemblyHubDir} \
	--finalBigBedDirs $$bigBedDirs --shortLabel ${GORILLA_VERSION} --longLabel ${GORILLA_VERSION} \
	--hub ${GORILLA_VERSION} &> ${jobTreeJobOutput}
	touch $@


assemblyHubGencodeSubsetClean:
	rm -rf ${jobTreeDone} ${jobTreeJobDir} ${assemblyHubDir}

endif