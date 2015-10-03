####
# Run comparativeAnnotator
####
include defs.mk

metricsDir = ${comparativeAnnotationDir}/metrics

ifneq (${transMapChainingMethod},)
ifneq (${gencodeSubset},)

transMapDataDir = ${TRANS_MAP_DIR}/transMap/${mapTargetOrg}/${transMapChainingMethod}
refGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
compGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeComp}.gp
basicGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeBasic}.gp
refFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa

ifneq (${mapTargetOrg},)
#######
# these variables only exist on the third level of recursion, I.E. when we have a target organism,
# a gencode subset and a transMap chaining method
# These will run for every combination of transMapChainingMethod-GencodeSubset-mapTargetOrg
#######
# jobTree (for transMap comparativeAnnotator)
jobTreeCompAnnTmpDir = $(shell pwd)/${jobTreeRootTmpDir}/comparativeAnnotator/${mapTargetOrg}/${augustusGencodeSet}_${transMapChainingMethod}
jobTreeCompAnnJobOutput = ${jobTreeCompAnnTmpDir}/comparativeAnnotator.out
jobTreeCompAnnJobDir = ${jobTreeCompAnnTmpDir}/jobTree
# jobTree (for clustering classifiers)
jobTreeClusteringTmpDir = $(shell pwd)/${jobTreeRootTmpDir}/clustering/${mapTargetOrg}/${gencodeSubset}_${transMapChainingMethod}
jobTreeClusteringJobOutput = ${jobTreeClusteringTmpDir}/clustering.out
jobTreeClusteringJobDir = ${jobTreeClusteringTmpDir}/jobTree

# output location
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}

# completion flags
comparativeAnnotationDone = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}/compAnnFlags/${mapTargetOrg}.done
clusteringDone = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}/clustering/${mapTargetOrg}.done

# input files
psl = ${transMapDataDir}/transMap${gencodeSubset}.psl
targetGp = ${transMapDataDir}/transMap${gencodeSubset}.gp
targetFasta = ${ASM_GENOMES_DIR}/${mapTargetOrg}.fa
targetSizes = ${ASM_GENOMES_DIR}/${mapTargetOrg}.chrom.sizes

#######
# below is the Augustus parameters for when we run Augustus
# we only run Augustus on one combination of transMapChainingMethod-GencodeSubset to avoid massive computation
#######
ifeq (${gencodeSubset},${augustusGencodeSet})
ifeq (${transMapChainingMethod},${augustusChainingMethod})

# Directories
AUGUSTUS_DIR = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/augustus
AUGUSTUS_TMR_DIR = ${AUGUSTUS_DIR}/tmr/${transMapChainingMethod}
AUGUSTUS_WORK_DIR = ${AUGUSTUS_DIR}/work/${transMapChainingMethod}

# jobTree (for running Augustus)
jobTreeAugustusTmpDir = $(shell pwd)/${jobTreeRootTmpDir}/augustus/${gencodeSubset}_${transMapChainingMethod}
jobTreeAugustusJobOutput = ${jobTreeAugustusTmpDir}/augustus.out
jobTreeAugustusJobDir = ${jobTreeAugustusTmpDir}/jobTree
# jobTree (for comparative Annotator)
jobTreeAugustusCompAnnTmpDir = $(shell pwd)/${jobTreeRootTmpDir}/augustusComparativeAnnotator/${mapTargetOrg}/${augustusGencodeSet}_${transMapChainingMethod}
jobTreeAugustusCompAnnJobOutput = ${jobTreeAugustusCompAnnTmpDir}/comparativeAnnotator.out
jobTreeAugustusCompAnnJobDir = ${jobTreeAugustusCompAnnTmpDir}/jobTree
# jobTree (for aligning transcripts)
jobTreeAlignAugustusTmpDir = $(shell pwd)/${jobTreeRootTmpDir}/augustusAlignToReference/${mapTargetOrg}/${augustusGencodeSet}_${transMapChainingMethod}
jobTreeAlignAugustusJobOutput = ${jobTreeAlignAugustusTmpDir}/comparativeAnnotator.out
jobTreeAlignAugustusJobDir = ${jobTreeAlignAugustusTmpDir}/jobTree

# Files
refTranscriptFasta = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.fa

codingTranscriptList = ${AUGUSTUS_WORK_DIR}/coding.lst
intronVectorDir = ${AUGUSTUS_WORK_DIR}/intron_vectors
inputGpDir = ${AUGUSTUS_WORK_DIR}/input_gps

intronVector = ${intronVectorDir}/${mapTargetOrg}_original_introns.txt
sortedGp = ${inputGpDir}/sorted/${mapTargetOrg}.sorted.gp
inputGp = ${inputGpDir}/input/${mapTargetOrg}.final.gp

outputGtfDir = ${AUGUSTUS_WORK_DIR}/output_gffs
outputGtf = ${outputGffDir}/${mapTargetOrg}.output.gtf

outputGpDir = ${AUGUSTUS_WORK_DIR}/output_gps
outputGp = ${outputGpDir}/output_gps/${mapTargetOrg}.output.gp
outputBed12_8 = ${outputGpDir}/bed_12_8/${mapTargetOrg}.bed12-8
outputBb = ${outputGpDir}/bigBed/${mapTargetOrg}.bb
# outputBb is put in the comparative annotator bigBedfiles dir so it can be found by assemblyHub.mk
outputBbSym = ${comparativeAnnotationDir}/bigBedfiles/AugustusTMR/${mapTargetOrg}/${mapTargetOrg}.bb
outputBed = ${comparativeAnnotationDir}/bedfiles/AugustusTMR/${mapTargetOrg}/${mapTargetOrg}.bed

augustusFaDir = ${AUGUSTUS_WORK_DIR}/fastas
augustusFa = ${augustusFaDir}/${mapTargetOrg}.fa
augustusFaidx = ${augustusFaDir}/${mapTargetOrg}.fa.fai

consensusDir = ${comparativeAnnotationDir}/consensus

# completion flags
augustusComparativeAnnotationDone = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}/augustusCompAnnFlags/${mapTargetOrg}.done
augustusAlignmentDone = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}/augustusAlignmentFlags/${mapTargetOrg}.done
consensusDone = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}/consensus/${mapTargetOrg}.done

endif
endif
endif

else
#####
# final metrics. these are defined only when mapTargetOrg is not set and are used once all annotations are done
#####

# require these files to exist before starting
compAnnFlags = ${mappedOrgs:%=${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}/compAnnFlags/%.done}

metricsFlag = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}/metrics.done

endif
endif
endif


all: transMapChainingMethod metrics

transMapChainingMethod: ${transMapChainingMethods:%=%.transMapChainingMethod}
%.transMapChainingMethod:
	${MAKE} -f rules/comparativeAnnotator.mk gencode transMapChainingMethod=$*

ifneq (${transMapChainingMethod},)

gencode: ${gencodeSubsets:%=%.gencode}

%.gencode:
	${MAKE} -f rules/comparativeAnnotator.mk annotationGencodeSubset gencodeSubset=$*

ifneq (${gencodeSubset},)

runOrg: ${augustusOrgs:%=%.runOrg}

%.runOrg:
    ${MAKE} -f rules/augustus.mk runOrg mapTargetOrg=$*

ifneq (${mapTargetOrg},)
runOrg: ${comparativeAnnotationDone} ${intronVector} ${sortedGp} ${inputGp} ${outputGtf} ${outputGp}
	${outputBed12_8} ${outputBb} ${outputBbSym} ${outputBed} ${clusteringDone}
	${augustusFa} ${augustusFaidx} ${augustusComparativeAnnotationDone} ${augustusAlignmentDone}

${comparativeAnnotationDone}: ${psl} ${targetGp} ${refGp} ${refFasta} ${targetFasta} ${targetSizes}
	@mkdir -p $(dir $@)
	if [ -d ${jobTreeCompAnnJobDir} ]; then rm -rf ${jobTreeCompAnnJobDir}; fi
	cd ../comparativeAnnotator && ${python} src/annotation_pipeline.py ${jobTreeOpts} \
	--refGenome ${refGenome} --genome ${mapTargetOrg} --annotationGp ${refGp} --psl ${psl} --gp ${targetGp} \
	--fasta ${fasta} --refFasta ${refFasta} --sizes ${targetSizes} --outDir ${comparativeAnnotationDir} \
	----gencodeAttributes ${srcGencodeAttrsTsv} --jobTree ${jobTreeCompAnnJobDir} &> ${jobTreeCompAnnJobOutput}
	touch $@

${clusteringDone}: ${comparativeAnnotationDone}
	@mkdir -p $(dir $@)
	if [ -d ${jobTreeClusteringJobDir} ]; then rm -rf ${jobTreeClusteringJobDir}; fi
	cd ../comparativeAnnotator && ${python} plotting/clustering.py ${jobTreeOpts} \
	--genome ${mapTargetOrg} --outDir ${metricsDir} --comparativeAnnotationDir ${comparativeAnnotationDir} \
	--annotationGp ${refGp} --gencode ${gencodeSubset} --attributePath ${srcGencodeAttrsTsv} \
	--jobTree ${jobTreeClusteringJobDir} &> ${jobTreeClusteringJobOutput}

${intronVector}: ${comparativeAnnotationDone}
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} augustus/find_intron_vector.py --genome ${mapTargetOrg} \
	--gp ${transMapGp} --comparativeAnnotationDir ${comparativeAnnotationDir} --outPath ${intronVector}.${tmpExt}
	mv -f $@.${tmpExt} $@

${sortedGp}: ${transMapGp}
	@mkdir -p $(dir $@)
	sort -k1,1 ${transMapGp} > ${sortedGp}.${tmpExt}
	mv -f $@.${tmpExt} $@

${inputGp}: ${sortedGp} ${intronVector}
	@mkdir -p $(dir $@)
	join --check-order -t $$'\t' ${sortedGp} ${intronVector} | bin/getLinesMatching.pl ${codingTranscriptList} \
	1 --patfrom="-\d+$$" | sort -n -k4,4 | sort -s -k2,2 > ${inputGp}.${tmpExt}
	mv -f $@.${tmpExt} $@

${outputGtf}: ${inputGp}
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} augustus/run_augustus.py ${jobTreeOpts} \
	--inputGp $< --outputGtf $@.$}{tmpExt} --genome ${mapTargetOrg} --chromSizes ${genomeChromSizes} \
	--fasta ${genomeFasta} --jobTree ${jobTreeAugustusJobDir} &> ${jobTreeAugustusJobOutput}
	mv -f $@.${tmpExt} $@

${outputGp}: ${outputGtf}
	@mkdir -p $(dir $@)
	gtfToGenePred -genePredExt $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${outputBed12_8}: ${outputGp}
	@mkdir -p $(dir $@)
	cat $< | augustus/gp2othergp.pl | sort -k1,1 -k2,2n > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${outputBb}: ${outputBed12_8}
	@mkdir -p $(dir $@)
	bedToBigBed -type=bed12+8 $< ${genomeChromSizes} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${outputBbSym}: ${outputBb}
	@mkdir -p $(dir $@)
	ln -s $< $@

${outputBed}: ${outputGp}
	@mkdir -p $(dir $@)
	genePredToBed $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${augustusFa}: ${outputBed}
	@mkdir -p $(dir $@)
	fastaFromBed -fi ${targetFasta} -fo $@.${tmpExt} -bed $< -name -s -split
	mv -f $@.${tmpExt} $@

${augustusFaidx}: ${augustusFa}
	@mkdir -p $(dir $@)
	samtools faidx $<

${augustusComparativeAnnotationDone}: ${outputGp}
	@mkdir -p $(dir $@)
	if [ -d ${jobTreeAugustusCompAnnJobDir} ]; then rm -rf ${jobTreeAugustusCompAnnJobDir}; fi
	cd ../comparativeAnnotator && ${python} src/annotation_pipeline.py ${jobTreeOpts} \
	--refGenome ${refGenome} --genome ${mapTargetOrg} --annotationGp ${refGp} --psl ${psl} --gp ${targetGp} \
	--fasta ${fasta} --refFasta ${refFasta} --sizes ${targetSizes} --outDir ${comparativeAnnotationDir} \
	----gencodeAttributes ${srcGencodeAttrsTsv} --jobTree ${jobTreeAugustusCompAnnJobDir} \
	--augustus --augustusGp $< &> ${jobTreeAugustusCompAnnJobOutput}
	touch $@

${augustusAlignmentDone}: ${augustusFa} ${augustusFaidx}
	@mkdir -p $(dir $@)
	if [ -d ${jobTreeAlignAugustusJobDir} ]; then rm -rf ${jobTreeAlignAugustusJobDir}; fi
	cd ../comparativeAnnotator && ${python} augustus/align_augustus.py ${jobTreeOpts} \
	--genome ${mapTargetOrg} --refFasta ${refTranscriptFasta} --targetFasta ${augustusFa} \
	--outDir ${comparativeAnnotationDir} &> ${jobTreeAlignAugustusJobOutput}

consensus: ${consensusFlag}

${consensusFlag}: ${compAnnFlags} ${augAlnFlags} ${augCompAnnFlags} ${augGps}
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} augustus/consensus.py --genome ${mapTargetOrg} \
	--compAnnPath ${comparativeAnnotationDir} --outDir ${consensusDir} --attributePath ${srcGencodeAttrsTsv} \
	--augGp ${outputGp} --tmGp ${transMapGp} --compGp ${compGp} --basicGp ${basicGp}
	touch $@


else

metrics: ${metricsFlag}

${metricsFlag}: ${compAnnFlags}
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} plotting/coverage_identity_ok_plots.py --outDir ${metricsDir} \
	--genomes ${mappedOrgs} --comparativeAnnotationDir ${comparativeAnnotationDir} \
	--attributePath ${srcGencodeAttrsTsv} --annotationGp ${refGp} --gencode ${gencodeSubset}
	touch $@


endif
endif
endif