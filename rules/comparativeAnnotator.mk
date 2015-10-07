####
# Run comparativeAnnotator
####
include defs.mk

ifneq (${gencodeSubset},)
ifneq (${mapTargetOrg},)
#######
# These will run for every combination of GencodeSubset-mapTargetOrg
#######
# jobTree (for transMap comparativeAnnotator)
jobTreeCompAnnTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/comparativeAnnotator/${mapTargetOrg}/${gencodeSubset}
jobTreeCompAnnJobOutput = ${jobTreeCompAnnTmpDir}/comparativeAnnotator.out
jobTreeCompAnnJobDir = ${jobTreeCompAnnTmpDir}/jobTree
comparativeAnnotationDone = ${jobTreeCompAnnTmpDir}/comparativeAnnotation.done
# jobTree (for clustering classifiers)
jobTreeClusteringTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/clustering/${mapTargetOrg}/${gencodeSubset}
jobTreeClusteringJobOutput = ${jobTreeClusteringTmpDir}/clustering.out
jobTreeClusteringJobDir = ${jobTreeClusteringTmpDir}/jobTree
clusteringDone = ${jobTreeClusteringTmpDir}/classifierClustering.done

# output location
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}
metricsDir = ${ANNOTATION_DIR}/${gencodeSubset}/metrics

# input files
transMapDataDir = ${TRANS_MAP_DIR}/transMap/${mapTargetOrg}
refGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
refFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa
psl = ${transMapDataDir}/transMap${gencodeSubset}.psl
targetGp = ${transMapDataDir}/transMap${gencodeSubset}.gp
targetFasta = ${ASM_GENOMES_DIR}/${mapTargetOrg}.fa
targetSizes = ${ASM_GENOMES_DIR}/${mapTargetOrg}.chrom.sizes

#######
# below is the Augustus parameters for when we run Augustus
# we only run Augustus on GencodeComp to avoid duplicate computation
#######
ifeq (${gencodeSubset},${augustusGencodeSet})

# Directories
AUGUSTUS_DIR = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/augustus
AUGUSTUS_TMR_DIR = ${AUGUSTUS_DIR}/tmr
AUGUSTUS_WORK_DIR = ${AUGUSTUS_DIR}/work

# jobTree (for running Augustus)
jobTreeAugustusTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/augustus/${mapTargetOrg}/${gencodeSubset}
jobTreeAugustusJobOutput = ${jobTreeAugustusTmpDir}/augustus.out
jobTreeAugustusJobDir = ${jobTreeAugustusTmpDir}/jobTree
# Augustus does not need a completion flag because there is a single file output at the end (a genePred)

# jobTree (for comparative Annotator)
jobTreeAugustusCompAnnTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/augustusComparativeAnnotator/${mapTargetOrg}/${gencodeSubset}
jobTreeAugustusCompAnnJobOutput = ${jobTreeAugustusCompAnnTmpDir}/comparativeAnnotator.out
jobTreeAugustusCompAnnJobDir = ${jobTreeAugustusCompAnnTmpDir}/jobTree
augustusComparativeAnnotationDone = ${jobTreeAugustusCompAnnTmpDir}/augustusComparativeAnnotation.done

# jobTree (for aligning transcripts)
jobTreeAlignAugustusTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/augustusAlignToReference/${mapTargetOrg}/${gencodeSubset}
jobTreeAlignAugustusJobOutput = ${jobTreeAlignAugustusTmpDir}/alignAugustus.out
jobTreeAlignAugustusJobDir = ${jobTreeAlignAugustusTmpDir}/jobTree
augustusAlignmentDone =  ${jobTreeAlignAugustusTmpDir}/augustusAlignment.done

# Files
refTranscriptFasta = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.fa

codingTranscriptList = ${AUGUSTUS_WORK_DIR}/coding.lst
intronVectorDir = ${AUGUSTUS_WORK_DIR}/intron_vectors
inputDir = ${AUGUSTUS_WORK_DIR}/input

intronVector = ${intronVectorDir}/${mapTargetOrg}_original_introns.txt
sortedGp = ${inputDir}/${mapTargetOrg}.sorted.gp
inputGp = ${inputDir}/${mapTargetOrg}.final.gp

outputDir = ${AUGUSTUS_WORK_DIR}/output
outputGtf = ${outputDir}/${mapTargetOrg}.output.gtf
outputGp = ${outputDir}/${mapTargetOrg}.output.gp
outputBed12_8 = ${outputDir}/bed_12_8/${mapTargetOrg}.bed12-8
outputBb = ${outputDir}/bigBed/${mapTargetOrg}.bb
# outputBb is put in the comparative annotator bigBedfiles dir so it can be found by assemblyHub.mk
outputBbSym = ${comparativeAnnotationDir}/bigBedfiles/AugustusTMR/${mapTargetOrg}/${mapTargetOrg}.bb
outputBed = ${comparativeAnnotationDir}/bedfiles/AugustusTMR/${mapTargetOrg}/${mapTargetOrg}.bed

augustusFaDir = ${AUGUSTUS_WORK_DIR}/fastas
augustusFa = ${augustusFaDir}/${mapTargetOrg}.fa
augustusFaidx = ${augustusFaDir}/${mapTargetOrg}.fa.fai

consensusDir = ${comparativeAnnotationDir}/consensus
binnedTranscriptPath = ${AUGUSTUS_WORK_DIR}/consensus/${mapTargetOrg}
consensusDone = ${ANNOTATION_DIR}/${gencodeSubset}/consensus/${mapTargetOrg}.done

compGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeComp}.gp
basicGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeBasic}.gp

endif
endif
endif


all: gencode

gencode: ${gencodeSubsets:%=%.gencode}

%.gencode:
	${MAKE} -f rules/comparativeAnnotator.mk annotationGencodeSubset gencodeSubset=$*

annotationGencodeSubset: ${augustusOrgs:%=%.annotationGencodeSubset}

%.annotationGencodeSubset:
	${MAKE} -f rules/comparativeAnnotator.mk runOrg mapTargetOrg=$* gencodeSubset=${gencodeSubset}

ifneq (${gencodeSubset},)
ifneq (${mapTargetOrg},)

runOrg: ${comparativeAnnotationDone}

ifeq (${gencodeSubset},${augustusGencodeSet})
runOrg: ${comparativeAnnotationDone} ${codingTranscriptList} ${intronVector} ${sortedGp} ${inputGp} ${outputGtf} \
		${outputGp} ${outputBed12_8} ${outputBb} ${outputBbSym} ${outputBed} ${clusteringDone} ${augustusFa} \
		${augustusFaidx} ${augustusComparativeAnnotationDone} ${augustusAlignmentDone} ${consensusDone}
endif


${comparativeAnnotationDone}: ${psl} ${targetGp} ${refGp} ${refFasta} ${targetFasta} ${targetSizes}
	@mkdir -p $(dir $@)
	@mkdir -p ${comparativeAnnotationDir}
	if [ -d ${jobTreeCompAnnJobDir} ]; then rm -rf ${jobTreeCompAnnJobDir}; fi
	cd ../comparativeAnnotator && ${python} src/annotation_pipeline.py ${jobTreeOpts} \
	--refGenome ${srcOrg} --genome ${mapTargetOrg} --annotationGp ${refGp} --psl ${psl} --gp ${targetGp} \
	--fasta ${targetFasta} --refFasta ${refFasta} --sizes ${targetSizes} --outDir ${comparativeAnnotationDir} \
	--gencodeAttributes ${srcGencodeAttrsTsv} --jobTree ${jobTreeCompAnnJobDir} &> ${jobTreeCompAnnJobOutput}
	touch $@

${clusteringDone}: ${comparativeAnnotationDone}
	@mkdir -p $(dir $@)
	if [ -d ${jobTreeClusteringJobDir} ]; then rm -rf ${jobTreeClusteringJobDir}; fi
	cd ../comparativeAnnotator && ${python} plotting/clustering.py ${jobTreeOpts} \
	--genome ${mapTargetOrg} --outDir ${metricsDir} --comparativeAnnotationDir ${comparativeAnnotationDir} \
	--annotationGp ${refGp} --gencode ${gencodeSubset} --attributePath ${srcGencodeAttrsTsv} \
	--jobTree ${jobTreeClusteringJobDir} &> ${jobTreeClusteringJobOutput}
	touch $@

${codingTranscriptList}:
	@mkdir -p $(dir $@)
	hgsql -e "SELECT transcriptId,transcriptClass FROM wgEncodeGencodeAttrsVM4" ${srcOrgHgDb} | \
	grep -P "\tcoding" | cut -f 1,1 > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${intronVector}: ${comparativeAnnotationDone}
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} augustus/find_intron_vector.py --genome ${mapTargetOrg} \
	--gp ${targetGp} --refGp ${refGp} --psl ${psl} --outPath ${intronVector}.${tmpExt}
	mv -f $@.${tmpExt} $@

${sortedGp}: ${targetGp}
	@mkdir -p $(dir $@)
	sort -k1,1 ${targetGp} > ${sortedGp}.${tmpExt}
	mv -f $@.${tmpExt} $@

${inputGp}: ${sortedGp} ${intronVector}
	@mkdir -p $(dir $@)
	join --check-order -t $$'\t' ${sortedGp} ${intronVector} | bin/getLinesMatching.pl ${codingTranscriptList} \
	1 --patfrom="-\d+$$" | sort -n -k4,4 | sort -s -k2,2 > ${inputGp}.${tmpExt}
	mv -f $@.${tmpExt} $@

${outputGtf}: ${inputGp}
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeAugustusTmpDir}
	if [ -d ${jobTreeAugustusJobDir} ]; then rm -rf ${jobTreeAugustusJobDir}; fi
	cd ../comparativeAnnotator && ${python} augustus/run_augustus.py ${jobTreeOpts} \
	--inputGp $< --outputGtf $@ --genome ${mapTargetOrg} --chromSizes ${targetSizes} \
	--fasta ${targetFasta} --jobTree ${jobTreeAugustusJobDir} &> ${jobTreeAugustusJobOutput}

${outputGp}: ${outputGtf}
	@mkdir -p $(dir $@)
	gtfToGenePred -genePredExt $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${outputBed12_8}: ${outputGp}
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && cat $< | augustus/gp2othergp.pl | sort -k1,1 -k2,2n > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${outputBb}: ${outputBed12_8}
	@mkdir -p $(dir $@)
	bedToBigBed -type=bed12+8 -extraIndex=name $< ${targetSizes} $@.${tmpExt}
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
	--refGenome ${srcOrg} --genome ${mapTargetOrg} --annotationGp ${refGp} --psl ${psl} --gp ${targetGp} \
	--fasta ${targetFasta} --refFasta ${refFasta} --sizes ${targetSizes} --outDir ${comparativeAnnotationDir} \
	--gencodeAttributes ${srcGencodeAttrsTsv} --jobTree ${jobTreeAugustusCompAnnJobDir} \
	--augustus --augustusGp $< &> ${jobTreeAugustusCompAnnJobOutput}
	touch $@

${augustusAlignmentDone}: ${augustusFa} ${augustusFaidx}
	@mkdir -p $(dir $@)
	if [ -d ${jobTreeAlignAugustusJobDir} ]; then rm -rf ${jobTreeAlignAugustusJobDir}; fi
	cd ../comparativeAnnotator && ${python} augustus/align_augustus.py ${jobTreeOpts} \
	--genome ${mapTargetOrg} --refTranscriptFasta ${refTranscriptFasta} --targetTranscriptFasta ${augustusFa} \
	--targetTranscriptFastaIndex ${augustusFaidx} --outDir ${comparativeAnnotationDir} \
	--jobTree ${jobTreeAlignAugustusJobDir} &> ${jobTreeAlignAugustusJobOutput}
	touch $@

${consensusDone}: ${comparativeAnnotationDone} ${augustusComparativeAnnotationDone} ${augustusAlignmentDone} ${augGps}
	@mkdir -p $(dir $@)
	@mkdir -p $(dir ${binnedTranscriptPath})
	cd ../comparativeAnnotator && ${python} augustus/consensus.py --genome ${mapTargetOrg} \
	--compAnnPath ${comparativeAnnotationDir} --outDir ${consensusDir} --attributePath ${srcGencodeAttrsTsv} \
	--augGp ${outputGp} --tmGp ${targetGp} --compGp ${compGp} --basicGp ${basicGp} \
	--binnedTranscriptPath ${binnedTranscriptPath}
	touch $@

endif
endif