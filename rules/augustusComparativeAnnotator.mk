####
# Run augustusComparativeAnnotator
####
include defs.mk

codingTranscriptList = ${AUGUSTUS_WORK_DIR}/coding.lst

all: ${codingTranscriptList} ${augustusOrgs:%=%.runOrg}

clean: ${augustusOrgs:%=%.cleanOrg}

${codingTranscriptList}:
	@mkdir -p $(dir $@)
	hgsql -e "SELECT transcriptId,transcriptClass FROM ${srcGencodeAttrs}" ${srcOrgHgDb} | \
	grep -P "\tcoding" | cut -f 1,1 > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

%.runOrg:
	${MAKE} -f rules/augustusComparativeAnnotator.mk runOrg mapTargetOrg=$*

%.cleanOrg:
	${MAKE} -f rules/augustusComparativeAnnotator.mk cleanOrg mapTargetOrg=$*


ifneq (${mapTargetOrg},)

# comparativeAnnotator mode
mode = augustus

# done flag dir
doneFlagDir = ${DONE_FLAG_DIR}/${mapTargetOrg}/${augustusGencodeSet}

# output location
comparativeAnnotationDir = ${ANNOTATION_DIR}/${augustusGencodeSet}
metricsDir = ${comparativeAnnotationDir}/metrics

# input files
transMapDataDir = ${TRANS_MAP_DIR}/transMap/${mapTargetOrg}
refGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${augustusGencodeSet}.gp
refPsl = ${SRC_GENCODE_DATA_DIR}/wgEncode${augustusGencodeSet}.psl
refFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa
psl = ${transMapDataDir}/transMap${augustusGencodeSet}.psl
targetGp = ${transMapDataDir}/transMap${augustusGencodeSet}.gp
targetFasta = ${ASM_GENOMES_DIR}/${mapTargetOrg}.fa
targetSizes = ${ASM_GENOMES_DIR}/${mapTargetOrg}.chrom.sizes

# jobTree (for running Augustus)
jobTreeAugustusTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/augustus/${mapTargetOrg}/${augustusGencodeSet}
jobTreeAugustusJobOutput = ${jobTreeAugustusTmpDir}/augustus.out
jobTreeAugustusJobDir = ${jobTreeAugustusTmpDir}/jobTree
# Augustus does not need a completion flag because there is a single file output at the end (a genePred)

# jobTree (for Augustus Comparative Annotator)
jobTreeAugustusCompAnnTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/augustusComparativeAnnotator/${mapTargetOrg}/${augustusGencodeSet}
jobTreeAugustusCompAnnJobOutput = ${jobTreeAugustusCompAnnTmpDir}/augustusComparativeAnnotator.out
jobTreeAugustusCompAnnJobDir = ${jobTreeAugustusCompAnnTmpDir}/jobTree
augustusComparativeAnnotationDone = ${doneFlagDir}/augustusComparativeAnnotation.done

# jobTree (for aligning transcripts)
jobTreeAlignAugustusTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/augustusAlignToReference/${mapTargetOrg}/${augustusGencodeSet}
jobTreeAlignAugustusJobOutput = ${jobTreeAlignAugustusTmpDir}/alignAugustus.out
jobTreeAlignAugustusJobDir = ${jobTreeAlignAugustusTmpDir}/jobTree
augustusAlignmentDone =  ${doneFlagDir}/augustusAlignment.done

# jobTree (for clustering classifiers)
jobTreeClusterAugustusTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/augustusClustering/${mapTargetOrg}/${augustusGencodeSet}
jobTreeClusterAugustusJobOutput = ${jobTreeClusterAugustusTmpDir}/clusterAugustus.out
jobTreeClusterAugustusJobDir = ${jobTreeClusterAugustusTmpDir}/jobTree
augustusClusterDone =  ${doneFlagDir}/augustusCluster.done

# Files
refTranscriptFasta = ${SRC_GENCODE_DATA_DIR}/wgEncode${augustusGencodeSet}.fa

intronVectorDir = ${AUGUSTUS_WORK_DIR}/intron_vectors
inputDir = ${AUGUSTUS_WORK_DIR}/input

intronVector = ${intronVectorDir}/${mapTargetOrg}_original_introns.txt
sortedGp = ${inputDir}/${mapTargetOrg}.sorted.gp
inputGp = ${inputDir}/${mapTargetOrg}.final.gp

outputDir = ${AUGUSTUS_TMR_DIR}
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
consensusWorkDir = ${AUGUSTUS_WORK_DIR}/consensus
consensusDone = ${doneFlagDir}/consensus.done


runOrg: ${intronVector} ${sortedGp} ${inputGp} ${outputGtf} ${outputGp} ${outputBed12_8} ${outputBb} ${outputBbSym} \
	${outputBed} ${augustusFa} ${augustusFaidx} ${augustusComparativeAnnotationDone} \
	${augustusAlignmentDone} ${consensusDone} ${augustusClusterDone}

${intronVector}:
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} augustus/find_intron_vector.py --genome ${mapTargetOrg} \
	--refPsl ${refPsl} --psl ${psl} --gp ${targetGp} --outPath ${intronVector}.${tmpExt}
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
	cd ../comparativeAnnotator && ${python} augustus/run_augustus.py ${jobTreeOpts} --hintsDb ${hintsDb} \
	--inputGp $< --outputGtf $@ --genome ${mapTargetOrg} --chromSizes ${targetSizes} \
	--fasta ${targetFasta} --jobTree ${jobTreeAugustusJobDir} &> ${jobTreeAugustusJobOutput}

${outputGp}: ${outputGtf}
	@mkdir -p $(dir $@)
	gtfToGenePred -genePredExt $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${outputBed12_8}: ${outputGp}
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && cat $< | augustus/gp2othergp.pl | bedSort /dev/stdin $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${outputBb}: ${outputBed12_8}
	@mkdir -p $(dir $@)
	bedToBigBed -type=bed12+8 -extraIndex=name $< ${targetSizes} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${outputBbSym}: ${outputBb}
	@mkdir -p $(dir $@)
	ln -sf $< $@

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

${augustusAlignmentDone}: ${augustusFa} ${augustusFaidx}
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeAlignAugustusTmpDir}
	cd ../comparativeAnnotator && ${python} augustus/align_augustus.py ${jobTreeOpts} \
	--genome ${mapTargetOrg} --refTranscriptFasta ${refTranscriptFasta} --targetTranscriptFasta ${augustusFa} \
	--targetTranscriptFastaIndex ${augustusFaidx} --outDir ${comparativeAnnotationDir} \
	--jobTree ${jobTreeAlignAugustusJobDir} &> ${jobTreeAlignAugustusJobOutput}
	touch $@

${augustusComparativeAnnotationDone}: ${outputGp} ${augustusAlignmentDone}
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeAugustusCompAnnTmpDir}
	cd ../comparativeAnnotator && ${python} src/annotation_pipeline.py ${mode} ${jobTreeOpts} \
	--refGenome ${srcOrg} --genome ${mapTargetOrg} --annotationGp ${refGp} --psl ${psl} --targetGp ${targetGp} \
	--fasta ${targetFasta} --refFasta ${refFasta} --sizes ${targetSizes} --outDir ${comparativeAnnotationDir} \
	--gencodeAttributes ${srcGencodeAttrsTsv} --jobTree ${jobTreeAugustusCompAnnJobDir} \
	--augustusGp $< --refPsl ${refPsl} &> ${jobTreeAugustusCompAnnJobOutput}
	touch $@

${consensusDone}: ${comparativeAnnotationDone} ${augustusComparativeAnnotationDone} ${augustusAlignmentDone}
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} augustus/consensus.py --genome ${mapTargetOrg} \
	--refGenome ${srcOrg} --compAnnPath ${comparativeAnnotationDir} --outDir ${consensusDir} \
	--workDir ${consensusWorkDir} --augGp ${outputGp} --tmGp ${targetGp}
	touch $@

${augustusClusterDone}: ${augustusComparativeAnnotationDone}
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeClusterAugustusTmpDir}
	cd ../comparativeAnnotator && ${python} plotting/clustering.py ${jobTreeOpts} --mode augustus \
	--genome ${mapTargetOrg} --refGenome ${srcOrg} --comparativeAnnotationDir ${comparativeAnnotationDir} \
	--outDir ${metricsDir} --gencode ${augustusGencodeSet} --jobTree ${jobTreeClusterAugustusJobDir} \
	&> ${jobTreeClusterAugustusJobOutput}
	touch $@

cleanOrg:
	rm -rf ${intronVector} ${sortedGp} ${inputGp} ${outputGtf} ${outputGp} ${outputBed12_8} ${outputBb} ${outputBbSym} \
	${outputBed} ${augustusFa} ${augustusFaidx} ${augustusComparativeAnnotationDone} ${augustusAlignmentDone} \
	${consensusDone} ${jobTreeAlignAugustusJobDir} ${jobTreeAugustusCompAnnJobDir} ${jobTreeAugustusJobDir} \
	${augustusClusterDone} ${jobTreeClusterAugustusJobDir}

endif