include defs.mk

# jobTree configuration
batchSystem = parasol
maxThreads = 20
maxCpus = 1024
defaultMemory = 8589934592
maxJobDuration = 28800
retryCount = 3
jobTreeOpts = --defaultMemory ${defaultMemory} --batchSystem parasol --parasolCommand $(shell pwd)/bin/remparasol \
			  --maxJobDuration ${maxJobDuration} --maxThreads ${maxThreads} --maxCpus ${maxCpus} \
			  --retryCount ${retryCount} --maxJobDuration ${maxJobDuration} --stats

ifneq (${gencodeSubset},)
ifneq (${transMapChainingMethod},)
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}
transMapChainedAllPsls = ${mappedOrgs:%=${TRANS_MAP_DIR}/transMap/%/${transMapChainingMethod}/transMap${gencodeSubset}.psl}
transMapEvalAllGp = ${mappedOrgs:%=${TRANS_MAP_DIR}/transMap/%/${transMapChainingMethod}/transMap${gencodeSubset}.gp}
srcGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
jobTreeDir = $(shell pwd)/.${gencodeSubset}_${MSCA_VERSION}_${transMapChainingMethod}_comparativeAnnotatorJobTree
log = $(shell pwd)/${gencodeSubset}_${MSCA_VERSION}_${transMapChainingMethod}_jobTree.log
METRICS_DIR = ${comparativeAnnotationDir}/metrics
clustLog = $(shell pwd)/${gencodeSubset}_${MSCA_VERSION}_${transMapChainingMethod}_clustering.log
clusteringJobTree = $(shell pwd)/.${gencodeSubset}_${MSCA_VERSION}_${transMapChainingMethod}_clusteringJobTree
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
annotationGencodeSubset: ${comparativeAnnotationDir}/DONE ${METRICS_DIR}/DONE ${METRICS_DIR}/CLUSTERING_DONE

${comparativeAnnotationDir}/DONE: ${srcGp} ${transMapChainedAllPsls} ${transMapEvalAllGp}
	@mkdir -p $(dir $@)
	if [ -d ${jobTreeDir} ]; then rm -rf ${jobTreeDir}; fi
	cd ../comparativeAnnotator && ${python} src/annotationPipeline.py ${jobTreeOpts} --refGenome ${srcOrg} --genomes ${mappedOrgs} --sizes ${targetChromSizes} \
	--psls ${transMapChainedAllPsls} --gps ${transMapEvalAllGp} --fastas ${targetFastaFiles} --refFasta ${queryFasta} \
	--annotationGp ${srcGp} --gencodeAttributeMap ${srcGencodeAttrsTsv} \
	--outDir ${comparativeAnnotationDir} --jobTree ${jobTreeDir} &> ${log}
	touch $@

${METRICS_DIR}/DONE: ${comparativeAnnotationDir}/DONE
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} scripts/coverage_identity_ok_plots.py --outDir ${METRICS_DIR} --genomes ${mappedOrgs} \
	--comparativeAnnotationDir ${comparativeAnnotationDir} --attributePath ${srcGencodeAttrsTsv} \
	--annotationGp ${srcGp} --gencode ${gencodeSubset}
	touch $@

${METRICS_DIR}/CLUSTERING_DONE: ${comparativeAnnotationDir}/DONE
	@mkdir -p $(dir $@)
	if [ -d ${clusteringJobTree} ]; then rm -rf ${clusteringJobTree}; fi
	cd ../comparativeAnnotator && ${python} scripts/clustering.py ${jobTreeOpts} --outDir ${METRICS_DIR} --genomes ${mappedOrgs} \
	--comparativeAnnotationDir ${comparativeAnnotationDir} --attributePath ${srcGencodeAttrsTsv} \
	--annotationGp ${srcGp} --gencode ${gencodeSubset} --jobTree ${clusteringJobTree} &> ${clustLog}
	touch $@	

endif
