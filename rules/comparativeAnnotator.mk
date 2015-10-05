####
# Run comparativeAnnotator
####
include defs.mk

ifneq (${transMapChainingMethod},)
ifneq (${gencodeSubset},)
ifneq (${mapTargetOrg},)
#######
# these variables only exist on the third level of recursion, I.E. when we have a target organism,
# a gencode subset and a transMap chaining method
# These will run for every combination of transMapChainingMethod-GencodeSubset-mapTargetOrg
#######
# jobTree (for transMap comparativeAnnotator)
jobTreeCompAnnTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/comparativeAnnotator/${mapTargetOrg}/${gencodeSubset}_${transMapChainingMethod}
jobTreeCompAnnJobOutput = ${jobTreeCompAnnTmpDir}/comparativeAnnotator.out
jobTreeCompAnnJobDir = ${jobTreeCompAnnTmpDir}/jobTree
comparativeAnnotationDone = ${jobTreeCompAnnTmpDir}/comparativeAnnotation.done
# jobTree (for clustering classifiers)
jobTreeClusteringTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/clustering/${mapTargetOrg}/${gencodeSubset}_${transMapChainingMethod}
jobTreeClusteringJobOutput = ${jobTreeClusteringTmpDir}/clustering.out
jobTreeClusteringJobDir = ${jobTreeClusteringTmpDir}/jobTree
clusteringDone = ${jobTreeClusteringTmpDir}/classifierClustering.done

# output location
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}
metricsDir = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}/metrics

# input files
transMapDataDir = ${TRANS_MAP_DIR}/transMap/${mapTargetOrg}/${transMapChainingMethod}
refGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
refFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa
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
jobTreeAugustusTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/augustus/${gencodeSubset}_${transMapChainingMethod}
jobTreeAugustusJobOutput = ${jobTreeAugustusTmpDir}/augustus.out
jobTreeAugustusJobDir = ${jobTreeAugustusTmpDir}/jobTree
# Augustus does not need a completion flag because there is a single file output at the end (a genePred)

# jobTree (for comparative Annotator)
jobTreeAugustusCompAnnTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/augustusComparativeAnnotator/${mapTargetOrg}/${gencodeSubset}_${transMapChainingMethod}
jobTreeAugustusCompAnnJobOutput = ${jobTreeAugustusCompAnnTmpDir}/comparativeAnnotator.out
jobTreeAugustusCompAnnJobDir = ${jobTreeAugustusCompAnnTmpDir}/jobTree
augustusComparativeAnnotationDone = ${jobTreeAugustusCompAnnTmpDir}/augustusComparativeAnnotation.done

# jobTree (for aligning transcripts)
jobTreeAlignAugustusTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/augustusAlignToReference/${mapTargetOrg}/${gencodeSubset}_${transMapChainingMethod}
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
consensusDone = ${ANNOTATION_DIR}/${gencodeSubset}/${transMapChainingMethod}/consensus/${mapTargetOrg}.done

endif
endif
endif
endif
endif


all: transMapChainingMethod

transMapChainingMethod: ${transMapChainingMethods:%=%.transMapChainingMethod}
%.transMapChainingMethod:
	${MAKE} -f rules/comparativeAnnotator.mk gencode transMapChainingMethod=$*

gencode: ${gencodeSubsets:%=%.gencode}

%.gencode:
	${MAKE} -f rules/comparativeAnnotator.mk annotationGencodeSubset gencodeSubset=$* \
	transMapChainingMethod=${transMapChainingMethod}

annotationGencodeSubset: ${augustusOrgs:%=%.annotationGencodeSubset}

%.annotationGencodeSubset:
	${MAKE} -f rules/comparativeAnnotator.mk runOrg mapTargetOrg=$* gencodeSubset=${gencodeSubset} \
	transMapChainingMethod=${transMapChainingMethod}

ifneq (${transMapChainingMethod},)
ifneq (${gencodeSubset},)
ifneq (${mapTargetOrg},)


ifeq (${gencodeSubset},${augustusGencodeSet})
ifeq (${transMapChainingMethod},${augustusChainingMethod})
runOrg: ${comparativeAnnotationDone} ${codingTranscriptList} ${intronVector} ${sortedGp} ${inputGp} ${outputGtf} \
		${outputGp} ${outputBed12_8} ${outputBb} ${outputBbSym} ${outputBed} ${clusteringDone} ${augustusFa} \
		${augustusFaidx} ${augustusComparativeAnnotationDone} ${augustusAlignmentDone} ${consensusFlag}
endif
endif

ifneq (${gencodeSubset},${augustusGencodeSet})
ifneq (${transMapChainingMethod},${augustusChainingMethod})
runOrg: ${comparativeAnnotationDone} ${consensusFlag}
endif
endif

${comparativeAnnotationDone}: ${psl} ${targetGp} ${refGp} ${refFasta} ${targetFasta} ${targetSizes}
	mkdir -p $(dir $@)
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

${consensusFlag}: ${compAnnFlags} ${augAlnFlags} ${augCompAnnFlags} ${augGps}
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} augustus/consensus.py --genome ${mapTargetOrg} \
	--compAnnPath ${comparativeAnnotationDir} --outDir ${consensusDir} --attributePath ${srcGencodeAttrsTsv} \
	--augGp ${outputGp} --tmGp ${targetGp} --compGp ${compGp} --basicGp ${basicGp}
	touch $@

endif
endif
endif