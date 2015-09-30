include defs.mk

# jobTree configuration
batchSystem = parasol
maxThreads = 20
maxCpus = 1024
defaultMemory = 8589934592
maxJobDuration = 28800
jobTreeOpts = --defaultMemory=${defaultMemory} --stats --batchSystem=parasol --parasolCommand=$(shell pwd)/bin/remparasol --maxJobDuration ${maxJobDuration}


ifneq (${gencodeSubset},)
ifneq (${transMapChainingMethod},)
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}
transMapChainedAllPsls = ${mappedOrgs:%=${TRANS_MAP_DIR}/transMap/%/${transMapChainingMethod}/transMap${gencodeSubset}.psl}
transMapEvalAllGp = ${mappedOrgs:%=${TRANS_MAP_DIR}/transMap/%/${transMapChainingMethod}/transMap${gencodeSubset}.gp}
srcGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
metricsDir = ${comparativeAnnotationDir}/metrics

jobTreeCompAnnTmpDir = $(shell pwd)/${jobTreeRootTmpDir}/comparativeAnnotator/${gencodeSubset}_${transMapChainingMethod}
jobTreeCompAnnJobOutput = ${jobTreeCompAnnTmpDir}/comparativeAnnotator.out
jobTreeCompAnnJobDir = ${jobTreeCompAnnTmpDir}/jobTree

jobTreeClusteringTmpDir = $(shell pwd)/${jobTreeRootTmpDir}/clustering/${gencodeSubset}_${transMapChainingMethod}
jobTreeClusteringJobOutput = ${jobTreeClusteringTmpDir}/clustering.out
jobTreeClusteringJobDir = ${jobTreeClusteringTmpDir}/jobTree
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
annotationGencodeSubset: ${comparativeAnnotationDir}/DONE ${metricsDir}/DONE ${metricsDir}/CLUSTERING_DONE

${comparativeAnnotationDir}/DONE: ${srcGp} ${transMapChainedAllPsls} ${transMapEvalAllGp}
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeCompAnnTmpDir}
	if [ -d ${jobTreeCompAnnJobDir} ]; then rm -rf ${jobTreeCompAnnJobDir}; fi
	cd ../comparativeAnnotator && ${python} src/annotationPipeline.py ${jobTreeOpts} \
	--refGenome ${srcOrg} --genomes ${mappedOrgs} --sizes ${targetChromSizes} \
	--psls ${transMapChainedAllPsls} --gps ${transMapEvalAllGp} --fastas ${targetFastaFiles} --refFasta ${queryFasta} \
	--annotationGp ${srcGp} --gencodeAttributeMap ${srcGencodeAttrsTsv} \
	--outDir ${comparativeAnnotationDir} --jobTree ${jobTreeCompAnnJobDir} &> ${jobTreeCompAnnJobOutput}
	touch $@

${metricsDir}/DONE: ${comparativeAnnotationDir}/DONE
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} scripts/coverage_identity_ok_plots.py \
	--outDir ${metricsDir} --genomes ${mappedOrgs} \
	--comparativeAnnotationDir ${comparativeAnnotationDir} --attributePath ${srcGencodeAttrsTsv} \
	--annotationGp ${srcGp} --gencode ${gencodeSubset}
	touch $@

${metricsDir}/CLUSTERING_DONE: ${comparativeAnnotationDir}/DONE
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeClusteringTmpDir}
	if [ -d ${jobTreeClusteringJobDir} ]; then rm -rf ${jobTreeClusteringJobDir}; fi
	cd ../comparativeAnnotator && ${python} scripts/clustering.py ${jobTreeOpts} \
	--outDir ${metricsDir} --genomes ${mappedOrgs} \
	--comparativeAnnotationDir ${comparativeAnnotationDir} --attributePath ${srcGencodeAttrsTsv} \
	--annotationGp ${srcGp} --gencode ${gencodeSubset} --jobTree ${jobTreeClusteringJobDir} &> ${jobTreeClusteringJobOutput}
	touch $@	

endif
