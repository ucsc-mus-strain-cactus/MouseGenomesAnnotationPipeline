#####
# Final metric plots.
#####
include defs.mk

ifneq (${gencodeSubset},)

# done flag dir
doneFlagDir = ${DONE_FLAG_DIR}/${srcOrg}/${gencodeSubset}

refGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
compGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeComp}.gp
basicGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeBasic}.gp
refFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa

# output location
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}
metricsDir = ${comparativeAnnotationDir}/metrics
metricsFlag = ${doneFlagDir}/metrics.done

endif

all: gencode

gencode: ${gencodeSubsets:%=%.gencode}

%.gencode:
	${MAKE} -f rules/metrics.mk annotationGencodeSubset gencodeSubset=$* 


ifneq (${gencodeSubset},)

annotationGencodeSubset: ${metricsFlag}


${metricsFlag}:
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} plotting/transmap_analysis.py --outDir ${metricsDir} \
	--genomes ${augustusOrgs} --refGenome ${srcOrg} --gencode ${gencodeSubset} \
	--comparativeAnnotationDir ${comparativeAnnotationDir}
	touch $@

endif