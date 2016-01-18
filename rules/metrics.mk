#####
# Final metric plots.
#####
include defs.mk

ifneq (${gencodeSubset},)

# output location
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}
metricsDir = ${comparativeAnnotationDir}/metrics
txSetMetricsDir = ${comparativeAnnotationDir}/tm_transcript_set/metrics
workDir = ${comparativeAnnotationDir}/work_dir/tm_tx
# done flag dir
metricsFlag = ${DONE_FLAG_DIR}/${gencodeSubset}_metrics.done
geneSetFlag = ${DONE_FLAG_DIR}/${gencodeSubset}_gene_set_metrics.done

endif

all: ${gencodeSubsets:%=%.gencode}

clean: ${gencodeSubsets:%=%.gencodeClean}

%.gencode:
	${MAKE} -f rules/metrics.mk annotationGencodeSubset gencodeSubset=$* 

%.gencodeClean:
	${MAKE} -f rules/metrics.mk annotationGencodeSubsetClean gencodeSubset=$* 


ifneq (${gencodeSubset},)

annotationGencodeSubset: ${metricsFlag} ${geneSetFlag}

${metricsFlag}:
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} plotting/transmap_analysis.py --outDir ${metricsDir} \
	--genomes ${mappedOrgs} --refGenome ${srcOrg} --gencode ${gencodeSubset} \
	--comparativeAnnotationDir ${comparativeAnnotationDir}
	touch $@

${geneSetFlag}:
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} plotting/gene_set_plots.py --compAnnPath ${comparativeAnnotationDir} \
	--genomes ${mappedOrgs} --refGenome ${srcOrg} --gencode ${gencodeSubset} --workDir ${workDir} --outDir ${txSetMetricsDir}
	touch $@

annotationGencodeSubsetClean:
	rm -rf ${metricsFlag} ${geneSetFlag}

endif