#####
# Final metric plots.
#####
include defs.mk

ifneq (${gencodeSubset},)

refGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
compGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeComp}.gp
basicGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeBasic}.gp
refFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa

# output location
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}
metricsDir = ${comparativeAnnotationDir}/metrics
metricsFlag = ${metricsDir}/metrics.done

endif

all: gencode

gencode: ${gencodeSubsets:%=%.gencode}

%.gencode:
	${MAKE} -f rules/metrics.mk annotationGencodeSubset gencodeSubset=$* 


ifneq (${gencodeSubset},)

annotationGencodeSubset: ${metricsFlag}


${metricsFlag}:
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} plotting/coverage_identity_ok_plots.py --outDir ${metricsDir} \
	--genomes ${augustusOrgs} --comparativeAnnotationDir ${comparativeAnnotationDir} \
	--attributePath ${srcGencodeAttrsTsv} --annotationGp ${refGp} --gencode ${gencodeSubset}
	touch $@

endif