####
# Run AugustusTMR
####
include defs.mk

ifneq (${transMapChainingMethod},)

##
# Directories
##
AUGUSTUS_DIR = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/augustus
AUGUSTUS_TMR_DIR = ${AUGUSTUS_DIR}/tmr/${transMapChainingMethod}
AUGUSTUS_WORK_DIR = ${AUGUSTUS_DIR}/work/${transMapChainingMethod}

##
# jobTree variables and rules
##

# jobTree configuration
batchSystem = parasol
maxThreads = 20
maxCpus = 1024
defaultMemory = 8589934592
maxJobDuration = 28800
retryCount = 3
jobTreeOpts = --defaultMemory ${defaultMemory} --batchSystem parasol --parasolCommand $(shell pwd)/bin/remparasol \
			  --maxJobDuration ${maxJobDuration} --maxThreads ${maxThreads} --maxCpus ${maxCpus} \
			  --retryCount ${retryCount} --maxJobDuration ${maxJobDuration} --stats

# jobTree folders
jobTreeAugustusTmpDir = $(shell pwd)/${jobTreeRootTmpDir}/comparativeAnnotator/${augustusGencodeSet}_${transMapChainingMethod}_Augustus
jobTreeCompAnnJobOutput = ${jobTreeAugustusTmpDir}/comparativeAnnotator.out
jobTreeCompAnnJobDir = ${jobTreeAugustusTmpDir}/jobTree

##
# Requirements
##
comparativeAnnotationDone = ${ANNOTATION_DIR}/${augustusGencodeSet}/${transMapChainingMethod}/DONE

##
# Files
##
codingTranscriptList = ${AUGUSTUS_WORK_DIR}/coding.lst
intronVectorDir = ${AUGUSTUS_WORK_DIR}/intron_vectors
intronVectorFiles = ${augustusOrgs:%=${intronVectorDir}/%_original_introns.txt}
inputGpDir = ${AUGUSTUS_WORK_DIR}/input_gps


ifneq (${mapTargetOrg},)
###
# These are only defined when mapTargetOrg is defined by recursive make: 
#    mapTargetOrg - specifies the target organism
#    transMapChainingMethod - one of simpleChain, all, syn
###
transMapDataDir = $(call transMapDataDirFunc,${mapTargetOrg},${transMapChainingMethod})
transMapGp = ${transMapDataDir}/transMap${augustusGencodeSet}.gp
genomeFasta = ${ASM_GENOMES_DIR}/${mapTargetOrg}.fa
genomeChromSizes = ${ASM_GENOMES_DIR}/${mapTargetOrg}.chrom.sizes

intronVector = ${intronVectorDir}/${mapTargetOrg}_original_introns.txt
sortedGp = ${inputGpDir}/sorted/${mapTargetOrg}.sorted.gp
inputGp = ${inputGpDir}/input/${mapTargetOrg}.final.gp

outputGtfDir = ${AUGUSTUS_WORK_DIR}/output_gffs
outputGtf = ${outputGffDir}/${mapTargetOrg}.output.gtf

outputGpDir = ${AUGUSTUS_WORK_DIR}/output_gps
outputGp = ${outputGpDir}/output_gps/${mapTargetOrg}.output.gp
outputBed12_8 = ${outputGpDir}/bed_12_8/${mapTargetOrg}.bed12-8
outputBb = ${outputGpDir}/bigBed/${mapTargetOrg}.bb
endif

endif


all: prepareFiles transMapChainingMethod

prepareFiles: ${codingTranscriptList}

${codingTranscriptList}:
	@mkdir -p $(dir $@)
	hgsql -e 'select transcriptid,transcriptClass from wgEncodeGencodeAttrsVM4' mm10 | \
	grep -P "\tcoding" | cut -f 1,1 > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

transMapChainingMethod: ${transMapChainingMethods:%=%.transMapChainingMethod}
%.transMapChainingMethod:
	${MAKE} -f rules/augustus.mk runAugustus transMapChainingMethod=$*

ifneq (${transMapChainingMethod},)
runAugustus: ${augustusOrgs:%=%.runOrg}

%.runOrg:
	${MAKE} -f rules/augustus.mk runOrg mapTargetOrg=$*

ifneq (${mapTargetOrg},)
runOrg: ${intronVector} ${sortedGp} ${inputGp} ${outputGtf} ${outputGp} ${outputBed12_8} ${outputBb}

${intronVector}: ${comparativeAnnotationDone}
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} scripts/find_intron_vector.py --genome ${mapTargetOrg} \
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
	--fasta ${genomeFasta} --jobTree ${jobTreeCompAnnJobDir} &> ${jobTreeCompAnnJobOutput}
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

endif

endif