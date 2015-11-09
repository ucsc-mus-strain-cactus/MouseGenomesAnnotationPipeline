#####
# Final metric plots.
#####
include defs.mk

ifneq (${gencodeSubset},)

# output location
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}
metricsDir = ${comparativeAnnotationDir}/metrics
# done flag dir
metricsFlag = ${DONE_FLAG_DIR}/${gencodeSubset}_metrics.done

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
	--genomes ${mappedOrgs} --refGenome ${srcOrg} --gencode ${gencodeSubset} \
	--comparativeAnnotationDir ${comparativeAnnotationDir}
	touch $@

annotationGencodeSubsetClean:
	rm -rf ${metricsFlag}

endif