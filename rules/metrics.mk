#####
# final metrics. these are defined only when mapTargetOrg is not set and are used once all annotations are done
#####
include defs.mk


ifneq (${transMapChainingMethod},)
ifneq (${gencodeSubset},)

comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}
transMapDataDir = ${TRANS_MAP_DIR}/transMap/${mapTargetOrg}/${transMapChainingMethod}
refGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
compGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeComp}.gp
basicGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeBasic}.gp
refFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa

metricsDir = ${comparativeAnnotationDir}/metrics
metricsDone = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}/metrics.done
consensusDone = ${augustusOrgs:%=${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}/consensus/%.done}
consensusMetricsDone = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}/consensus/metrics.done

compAnnDoneFiles = ${mappedOrgs:%=$(shell pwd -P)/${jobTreeRootTmpDir}/comparativeAnnotator/%/${gencodeSubset}_${transMapChainingMethod}/comparativeAnnotation.done}

binnedTranscriptDir = ${AUGUSTUS_WORK_DIR}/consensus

endif
endif

all: transMapChainingMethod

transMapChainingMethod: ${transMapChainingMethods:%=%.transMapChainingMethod}
%.transMapChainingMethod:
	${MAKE} -f rules/metrics.mk gencode transMapChainingMethod=$*


gencode: ${gencodeSubsets:%=%.gencode}

%.gencode:
	${MAKE} -f rules/metrics.mk annotationGencodeSubset gencodeSubset=$* \
	transMapChainingMethod=${transMapChainingMethod}


ifneq (${transMapChainingMethod},)
ifneq (${gencodeSubset},)

annotationGencodeSubset: ${metricsDone} ${consensusMetricsDone}

${metricsDone}: ${compAnnDoneFiles}
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} plotting/coverage_identity_ok_plots.py --outDir ${metricsDir} \
	--genomes ${mappedOrgs} --comparativeAnnotationDir ${comparativeAnnotationDir} \
	--attributePath ${srcGencodeAttrsTsv} --annotationGp ${refGp} --gencode ${gencodeSubset}
	touch $@

${consensusMetricsDone}: 
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} plotting/consensus_plots.py \
	--compAnnPath ${comparativeAnnotationDir} --outDir ${consensusDir} --attributePath ${srcGencodeAttrsTsv} \
	--augGp ${outputGp} --tmGp ${targetGp} --compGp ${compGp} --basicGp ${basicGp} \
	--binnedTranscriptDir ${binnedTranscriptDir}
	touch $@

endif
endif