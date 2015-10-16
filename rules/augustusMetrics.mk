#####
# Final Augustus metric plots.
#####
include defs.mk

# done flag dir
doneFlagDir = ${DONE_FLAG_DIR}/${srcOrg}/${augustusGencodeSet}

# Paths
comparativeAnnotationDir = ${ANNOTATION_DIR}/${augustusGencodeSet}
consensusDir = ${comparativeAnnotationDir}/consensus
metricsDir = ${consensusDir}/metrics
metricsFlag = ${doneFlagDir}/metrics.done
consensusWorkDir = ${AUGUSTUS_WORK_DIR}/consensus

all: ${metricsFlag}

${metricsFlag}:
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} plotting/consensus_plots.py --compAnnPath ${comparativeAnnotationDir} \
	--gencode ${augustusGencodeSet} --workDir ${consensusWorkDir} --outDir ${metricsDir}
	touch $@
