#####
# Final Augustus metric plots.
#####
include defs.mk

# Paths
comparativeAnnotationDir = ${ANNOTATION_DIR}/${augustusGencodeSet}
consensusDir = ${comparativeAnnotationDir}/consensus
metricsDir = ${consensusDir}/metrics
consensusWorkDir = ${AUGUSTUS_WORK_DIR}/consensus

# done flag dir
metricsFlag = ${DONE_FLAG_DIR}/${augustusGencodeSet}_augustus_metrics.done

all: ${metricsFlag}

${metricsFlag}:
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} plotting/gene_set_plots.py --compAnnPath ${comparativeAnnotationDir} \
	--genomes ${augustusOrgs} --refGenome ${srcOrg} --gencode ${augustusGencodeSet} --workDir ${consensusWorkDir} \
    --outDir ${metricsDir}
	touch $@

clean:
	rm -rf ${metricsFlag}