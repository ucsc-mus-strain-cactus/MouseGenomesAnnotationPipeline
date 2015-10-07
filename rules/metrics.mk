#####
# final metrics. these are defined only when mapTargetOrg is not set and are used once all annotations are done
#####
include defs.mk

ifneq (${gencodeSubset},)

transMapDataDir = ${TRANS_MAP_DIR}/transMap/${mapTargetOrg}
refGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
compGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeComp}.gp
basicGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeBasic}.gp
refFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa

metricsDir = ${comparativeAnnotationDir}/metrics
metricsFlag = ${ANNOTATION_DIR}/${gencodeSubset}/metrics.done

compAnnFlags = ${augustusOrgs:%=${ANNOTATION_DIR}/${gencodeSubset}/compAnnFlags/%.done}
endif

all: gencode

gencode: ${gencodeSubsets:%=%.gencode}

%.gencode:
	${MAKE} -f rules/comparativeAnnotator.mk annotationGencodeSubset gencodeSubset=$* 


ifneq (${transMapChainingMethod},)
ifneq (${gencodeSubset},)

${annotationGencodeSubset}: ${metricsFlag}


${metricsFlag}: ${compAnnFlags}
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} plotting/coverage_identity_ok_plots.py --outDir ${metricsDir} \
	--genomes ${mappedOrgs} --comparativeAnnotationDir ${comparativeAnnotationDir} \
	--attributePath ${srcGencodeAttrsTsv} --annotationGp ${refGp} --gencode ${gencodeSubset}
	touch $@

endif
endif