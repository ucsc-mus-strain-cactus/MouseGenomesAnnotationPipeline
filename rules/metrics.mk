#####
# Final metric plots.
#####
include defs.mk

ifneq (${gencodeSubset},)

refGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp

# output location
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}
metricsDir = ${comparativeAnnotationDir}/metrics
# done flag dir
doneFlagDir = ${DONE_FLAG_DIR}/${gencodeSubset}
metricsFlag = ${doneFlagDir}/metrics.done

endif

all: ${gencodeSubsets:%=%.gencode}

clean: ${gencodeSubsets:%=%.gencodeClean}

%.gencode:
	${MAKE} -f rules/metrics.mk annotationGencodeSubset gencodeSubset=$* 

%.gencodeClean:
	${MAKE} -f rules/metrics.mk annotationGencodeSubsetClean gencodeSubset=$* 


ifneq (${gencodeSubset},)

annotationGencodeSubset: ${metricsFlag}


${metricsFlag}:
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} plotting/transmap_analysis.py --outDir ${metricsDir} \
	--genomes ${augustusOrgs} --refGenome ${srcOrg} --gencode ${gencodeSubset} \
	--comparativeAnnotationDir ${comparativeAnnotationDir} --refGp ${refGp}
	touch $@

annotationGencodeSubsetClean:
	rm -rf ${metricsFlag}

endif