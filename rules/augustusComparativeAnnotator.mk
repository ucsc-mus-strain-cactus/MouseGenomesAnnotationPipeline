include defs.mk

# jobTree configuration
batchSystem = parasol
maxThreads = 30
maxCpus = 1024
defaultMemory = 8589934592
maxJobDuration = 36000

# call function to obtain a assembly file given an organism and extension
asmFileFunc = ${ASM_GENOMES_DIR}/$(1).$(2)

# call functions to get particular assembly files given an organism
asmFastaFunc = $(call asmFileFunc,${1},fa)
asmTwoBitFunc = $(call asmFileFunc,${1},2bit)
asmChromSizesFunc = $(call asmFileFunc,${1},chrom.sizes)

targetFastaFiles = ${augustusOrgs:%=$(call asmFastaFunc,%)}
targetChromSizes = ${augustusOrgs:%=$(call asmChromSizesFunc,%)}
queryFasta = $(call asmFastaFunc,${srcOrg})

comparativeAnnotationDir = ${ANNOTATION_DIR}_Augustus
transMapChainedAllPsls = ${augustusOrgs:%=${TRANS_MAP_DIR}/transMap/%/${augChaining}/transMap${gencodeComp}.psl}
transMapEvalAllGp = ${augustusOrgs:%=${TRANS_MAP_DIR}/transMap/%/${augChaining}/transMap${gencodeComp}.gp}
compGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeComp}.gp
basicGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeBasic}.gp
srcFa = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeComp}.fa
augustusGps = ${augustusOrgs:%=${TMR_DIR}/%.gp}
comparativeJobTreeDir = $(shell pwd)/.Augustus_${gencodeComp}_${MSCA_VERSION}_comparativeAnnotatorJobTree
alignJobTreeDir = $(shell pwd)/.consensusAlignJobTree
alignLog = $(shell pwd)/augustusAlign.log
log = $(shell pwd)/Augustus_${gencodeComp}_${MSCA_VERSION}_jobTree.log
consensusDir = ${comparativeAnnotationDir}/consensus
augustusStatsDir = ${comparativeAnnotationDir}/augustus_stats
augustusBeds = ${augustusOrgs:%=${augustusStatsDir}/%.bed}
augustusFastas = ${augustusOrgs:%=${augustusStatsDir}/%.fa}
augustusFaidx = ${augustusOrgs:%=${augustusStatsDir}/%.fa.fai}
METRICS_DIR = ${comparativeAnnotationDir}/metrics
clustLog = $(shell pwd)/${gencodeComp}_${MSCA_VERSION}_clustering.log
clusteringJobTree = $(shell pwd)/.Augustus_${gencodeComp}_${MSCA_VERSION}_clusteringJobTree
jobTreeOpts = --defaultMemory=${defaultMemory} --stats --batchSystem=parasol --parasolCommand=$(shell pwd)/bin/remparasol --maxJobDuration ${maxJobDuration}


all: ${comparativeAnnotationDir}/DONE ${METRICS_DIR}/DONE ${METRICS_DIR}/CLUSTERING_DONE consensus

${comparativeAnnotationDir}/DONE: ${compGp} ${transMapChainedAllPsls} ${transMapEvalAllGp} ${augustusGps}
	@mkdir -p $(dir $@)
	rm -rf ${comparativeJobTreeDir}
	cd ../comparativeAnnotator && ${python} src/annotationPipelineWithAugustus.py ${jobTreeOpts}  \
	--refGenome ${srcOrg} --genomes ${augustusOrgs} --sizes ${targetChromSizes} --augustusGps ${augustusGps} \
	--psls ${transMapChainedAllPsls} --gps ${transMapEvalAllGp} --fastas ${targetFastaFiles} --refFasta ${queryFasta} \
	--annotationGp ${compGp} --batchSystem ${batchSystem} --gencodeAttributeMap ${srcGencodeAttrsTsv} \
	--jobTree ${comparativeJobTreeDir}  --outDir ${comparativeAnnotationDir} &> ${log}
	touch $@

${METRICS_DIR}/DONE: ${comparativeAnnotationDir}/DONE
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} scripts/coverage_identity_ok_plots.py \
	--outDir ${METRICS_DIR} --genomes ${augustusOrgs} --annotationGp ${compGp} --gencode ${gencodeComp} \
	--comparativeAnnotationDir ${comparativeAnnotationDir} --attributePath ${srcGencodeAttrsTsv}
	touch $@

${METRICS_DIR}/CLUSTERING_DONE: ${comparativeAnnotationDir}/DONE
	@mkdir -p $(dir $@)
	rm -rf ${clusteringJobTree}
	cd ../comparativeAnnotator && ${python} scripts/clustering.py ${jobTreeOpts} \
	--outDir ${METRICS_DIR} --comparativeAnnotationDir ${comparativeAnnotationDir} --attributePath ${srcGencodeAttrsTsv} \
	--annotationGp ${compGp} --gencode ${gencodeComp} --genomes ${augustusOrgs} --jobTree ${clusteringJobTree} &> ${clustLog}
	touch $@
	

consensus: prepareTranscripts alignTranscripts makeConsensus

prepareTranscripts: ${augustusBeds} ${augustusFastas} ${augustusFaidx}

${augustusStatsDir}/%.bed: ${TMR_DIR}/%.gp
	@mkdir -p $(dir $@)
	genePredToBed $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${augustusStatsDir}/%.fa: ${augustusStatsDir}/%.bed
	@mkdir -p $(dir $@)
	fastaFromBed -bed $< -fi ${ASM_GENOMES_DIR}/$*.fa -fo $@.${tmpExt} -s -split -name
	mv -f $@.${tmpExt} $@

${augustusStatsDir}/%.fa.fai: ${augustusStatsDir}/%.fa
	samtools faidx $<

alignTranscripts: ${augustusStatsDir}/DONE

${augustusStatsDir}/DONE: ${augustusBeds} ${augustusFastas} ${augustusFaidx}
	@mkdir -p $(dir $@)
	rm -rf ${alignJobTreeDir}
	cd ../comparativeAnnotator && ${python} scripts/alignAugustus.py ${jobTreeOpts}  \
	--jobTree ${alignJobTreeDir} --genomes ${augustusOrgs} --refFasta ${srcFa} \
	--outDir ${augustusStatsDir} --augustusStatsDir ${augustusStatsDir} &> ${alignLog}

makeConsensus: ${consensusDir}/DONE

${consensusDir}/DONE: ${augustusStatsDir}/DONE
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} scripts/consensus.py --genomes ${augustusOrgs} \
	--compAnnPath ${comparativeAnnotationDir} --statsDir ${augustusStatsDir} --outDir ${consensusDir} \
	--attributePath ${srcGencodeAttrsTsv} --augGps ${augGps} --tmGps ${transMapEvalAllGp} --compGp ${compGp} \
	--basicGp ${basicGp}
	touch $@