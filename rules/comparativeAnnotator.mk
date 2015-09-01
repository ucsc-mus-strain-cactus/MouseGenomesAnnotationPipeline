include defs.mk

# jobTree configuration
batchSystem = parasol
maxThreads = 30
maxCpus = 1024
defaultMemory = 8589934592
maxJobDuration = 36000

ifneq (${gencodeSubset},)
ifneq (${transMapChainingMethod},)
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}
transMapChainedAllPsls = ${mappedOrgs:%=${TRANS_MAP_DIR}/transMap/%/${transMapChainingMethod}/transMap${gencodeSubset}.psl}
transMapEvalAllGp = ${mappedOrgs:%=${TRANS_MAP_DIR}/transMap/%/${transMapChainingMethod}/transMap${gencodeSubset}.gp}
srcGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
jobTreeDir = $(shell pwd)/.${gencodeSubset}_${MSCA_VERSION}_${transMapChainingMethod}_comparativeAnnotatorJobTree
log = $(shell pwd)/${gencodeSubset}_${MSCA_VERSION}_${transMapChainingMethod}_jobTree.log
METRICS_DIR = ${comparativeAnnotationDir}/metrics
endif
endif


# call function to obtain a assembly file given an organism and extension
asmFileFunc = ${ASM_GENOMES_DIR}/$(1).$(2)

# call functions to get particular assembly files given an organism
asmFastaFunc = $(call asmFileFunc,${1},fa)
asmTwoBitFunc = $(call asmFileFunc,${1},2bit)
asmChromSizesFunc = $(call asmFileFunc,${1},chrom.sizes)

targetFastaFiles = ${mappedOrgs:%=$(call asmFastaFunc,%)}
targetChromSizes = ${mappedOrgs:%=$(call asmChromSizesFunc,%)}
queryFasta = $(call asmFastaFunc,${srcOrg})

all: transMapChainingMethod

transMapChainingMethod: ${transMapChainingMethods:%=%.transMapChainingMethod}
%.transMapChainingMethod:
	${MAKE} -f rules/comparativeAnnotator.mk annotation transMapChainingMethod=$*

annotation: ${gencodeSubsets:%=%.annotation}

%.annotation:
	${MAKE} -f rules/comparativeAnnotator.mk annotationGencodeSubset gencodeSubset=$*

ifneq (${gencodeSubset},)
annotationGencodeSubset: ${comparativeAnnotationDir}/DONE ${METRICS_DIR}/DONE

${comparativeAnnotationDir}/DONE: ${srcGp} ${transMapChainedAllPsls} ${transMapEvalAllGp}
	@mkdir -p $(dir $@)
	rm -rf ${jobTreeDir}
	if [ "${batchSystem}" = "parasol" ]; then \
		cwd="$(shell pwd)" ;\
		ssh ku -Tnx "cd $$cwd && cd ../comparativeAnnotator && export PYTHONPATH=./ && \
		export PATH=./bin/:./sonLib/bin:./jobTree/bin:${PATH} && \
		${python} src/annotationPipeline.py --refGenome ${srcOrg} --genomes ${mappedOrgs} --sizes ${targetChromSizes} \
		--psls ${transMapChainedAllPsls} --gps ${transMapEvalAllGp} --fastas ${targetFastaFiles} --refFasta ${queryFasta} \
		--annotationGp ${srcGp} --batchSystem ${batchSystem} --gencodeAttributeMap ${srcGencodeAttrsTsv} \
		--defaultMemory ${defaultMemory} --jobTree ${jobTreeDir} --maxJobDuration ${maxJobDuration} \
		--maxThreads ${maxThreads} --stats --outDir ${comparativeAnnotationDir} &> ${log}" ;\
	else \
		${python} ../comparativeAnnotator/src/annotationPipeline.py --refGenome ${srcOrg} --genomes ${mappedOrgs} --sizes ${targetChromSizes} \
		--psls ${transMapChainedAllPsls} --gps ${transMapEvalAllGp} --fastas ${targetFastaFiles} --refFasta ${queryFasta} \
		--annotationGp ${srcGp} --batchSystem ${batchSystem} --gencodeAttributeMap ${srcGencodeAttrsTsv} \
		--defaultMemory ${defaultMemory} --jobTree ${jobTreeDir} --maxJobDuration ${maxJobDuration} \
		--maxThreads ${maxThreads} --stats --outDir ${comparativeAnnotationDir} &> ${log} ;\
	fi
	touch $@

${METRICS_DIR}/DONE: ${comparativeAnnotationDir}/DONE
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator ;\
	${python} scripts/coverage_identity_ok_plots.py --outDir ${METRICS_DIR} --genomes ${mappedOrgs} \
	--comparativeAnnotationDir ${comparativeAnnotationDir} --attributePath ${srcGencodeAttrsTsv} \
	--annotationGp ${srcGp} --gencode ${gencodeSubset}
	touch $@

endif
