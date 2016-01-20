####
# Produce a consensus between comparative Augustus and transMap/augustusTMR
####
include defs.mk

# reference files
refGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${augustusGencodeSet}.gp
refFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa

# reference CDS fasta to be built
refTxCdsFasta = ${SRC_GENCODE_DATA_DIR}/wgEncode${augustusGencodeSet}.CDS.fa

# directories
comparativeAnnotationDir = ${ANNOTATION_DIR}/${augustusGencodeSet}
cgpConsensusDir = ${comparativeAnnotationDir}/cgp_consensus
consensusDir = ${comparativeAnnotationDir}/consensus
metricsDir = ${cgpConsensusDir}/metrics
consensusWorkDir = ${AUGUSTUS_WORK_DIR}/cgp_consensus
doneFlagDir = ${DONE_FLAG_DIR}/${mapTargetOrg}/${augustusGencodeSet}

# final metrics
metricsDone = ${doneFlagDir}/cgpMetrics.done


all: ${refTxCdsFasta} ${augustusOrgs:%=%.runOrg} metrics

clean: ${augustusOrgs:%=%.cleanOrg} cleanRest

${refTxCdsFasta}: ${refGp}
	cat $< | ../comparativeAnnotator/scripts/make_thickstart_thickstop.py | bedtools getfasta \
	-fi ${refFasta} -fo $@.${tmpExt} -name -split -s -bed /dev/stdin
	mv -f $@.${tmpExt} $@

%.runOrg:
	${MAKE} -f rules/augustusCGPconsensus.mk runOrg mapTargetOrg=$*

%.cleanOrg:
	${MAKE} -f rules/augustusCGPconsensus.mk cleanOrg mapTargetOrg=$*


ifneq (${mapTargetOrg},)

transMapDataDir = ${TRANS_MAP_DIR}/transMap/${mapTargetOrg}

# input files
targetGp = ${transMapDataDir}/transMap${augustusGencodeSet}.gp
targetFasta = ${ASM_GENOMES_DIR}/${mapTargetOrg}.fa
cgpGp = ${AUGUSTUS_CGP_DIR}/${mapTargetOrg}.gp
consensusGp = ${comparativeAnnotationDir}/consensus/${mapTargetOrg}/protein_coding.augustus_consensus_gene_set.gp
intronBits = ${AUGUSTUS_CGP_INTRON_BITS_DIR}/${mapTargetOrg}.txt

# output files
outputConsensusGp = ${cgpConsensusDir}/${mapTargetOrg}.CGP.consensus.protein_coding.gp

# jobTree (for aligning CDS)
jobTreeAlignCdsTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/alignCds/${mapTargetOrg}/${augustusGencodeSet}
jobTreeAlignCdsJobOutput = ${jobTreeAlignCdsTmpDir}/alignCds.out
jobTreeAlignCdsJobDir = ${jobTreeAlignCdsTmpDir}/jobTree
alignCdsDone = ${doneFlagDir}/alignCdsDone.done

# jobTree (for aligning CGP)
jobTreeAlignCgpTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/alignCgp/${mapTargetOrg}/${augustusGencodeSet}
jobTreeAlignCgpJobOutput = ${jobTreeAlignCgpTmpDir}/alignCgp.out
jobTreeAlignCgpJobDir = ${jobTreeAlignCgpTmpDir}/jobTree
alignCgpDone = ${doneFlagDir}/alignCgpDone.done


runOrg: ${alignCdsDone} ${alignCgpDone} ${outputConsensusGp}

${alignCdsDone}:
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeAlignCdsTmpDir}
	cd ../comparativeAnnotator && ${python} scripts/align_cgp_cds.py ${jobTreeOpts} --genome ${mapTargetOrg} \
	--refGenome ${srcOrg} --refTranscriptFasta ${refTxCdsFasta} --targetGenomeFasta ${targetFasta} \
	--compAnnPath ${comparativeAnnotationDir} --consensusGp ${consensusGp} \
	--jobTree ${jobTreeAlignCdsJobDir} &> ${jobTreeAlignCdsJobOutput}
	touch $@

${alignCgpDone}:
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeAlignCgpTmpDir}
	cd ../comparativeAnnotator && ${python} scripts/align_cgp_cds.py ${jobTreeOpts} --genome ${mapTargetOrg} \
	--refGenome ${srcOrg} --refTranscriptFasta ${refTxCdsFasta} --targetGenomeFasta ${targetFasta} \
	--compAnnPath ${comparativeAnnotationDir} --cgpGp ${cgpGp} \
	--jobTree ${jobTreeAlignCgpJobDir} &> ${jobTreeAlignCgpJobOutput}
	touch $@

${outputConsensusGp}: ${alignCdsDone} ${alignCgpDone}
	@mkdir -p $(dir $@)
	@mkdir -p ${consensusWorkDir}
	cd ../comparativeAnnotator && ${python} scripts/cgp_consensus.py --cgpGp ${cgpGp} --consensusGp ${consensusGp} \
	--compAnnPath ${comparativeAnnotationDir} --intronBitsPath ${intronBits} --genome ${mapTargetOrg} \
	--refGenome ${srcOrg} --outGp $@.${tmpExt} --metricsOutDir ${consensusWorkDir}
	mv -f $@.${tmpExt} $@

cleanOrg:
	rm -rf ${alignCdsDone} ${alignCgpDone} ${jobTreeAlignCdsJobDir} ${jobTreeAlignCgpJobDir} ${outputConsensusGp}

else

metrics: ${metricsDone}

${metricsDone}:
	cd ../comparativeAnnotator && ${python} scripts/cgp_consensus_plots.py --compAnnPath ${comparativeAnnotationDir} \
	--genomes ${augustusOrgs} --workDir ${consensusWorkDir} --outDir ${metricsDir} --gencode ${augustusGencodeSet}

cleanRest:
	rm -rf ${metricsDone} ${refTxCdsFasta}

endif
