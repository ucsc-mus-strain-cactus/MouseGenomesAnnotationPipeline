#####
# Final Augustus metric plots.
#####
include defs.mk

# done flag dir
doneFlagDir = ${DONE_FLAG_DIR}/${srcOrg}/${gencodeSubset}

# Files
refGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${augustusGencodeSet}.gp
compGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeComp}.gp
basicGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeBasic}.gp
refFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa

# Paths
comparativeAnnotationDir = ${ANNOTATION_DIR}/${augustusGencodeSet}
consensusDir = ${comparativeAnnotationDir}/consensus
metricsDir = ${consensusDir}/metrics
metricsFlag = ${doneFlagDir}/metrics.done
binnedTranscriptDir = ${AUGUSTUS_WORK_DIR}/consensus

all: ${metricsFlag}

${metricsFlag}:
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} plotting/consensus_plots.py --compAnnPath ${comparativeAnnotationDir} \
	--outDir ${metricsDir} --binnedTranscriptDir ${binnedTranscriptDir} --attributePath ${srcGencodeAttrsTsv} \
	--compGp ${compGp} --basicGp ${basicGp}
	touch $@
