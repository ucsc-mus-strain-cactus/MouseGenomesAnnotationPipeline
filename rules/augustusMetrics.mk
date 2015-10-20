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
doneFlagDir = ${DONE_FLAG_DIR}/${gencodeSubset}
metricsFlag = ${doneFlagDir}/augustus_metrics.done

all: ${metricsFlag}

${metricsFlag}:
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} plotting/consensus_plots.py --compAnnPath ${comparativeAnnotationDir} --genomes ${augustusOrgs} \
	--gencode ${augustusGencodeSet} --workDir ${consensusWorkDir} --outDir ${metricsDir}
	touch $@

clean:
	rm -rf ${metricsFlag}