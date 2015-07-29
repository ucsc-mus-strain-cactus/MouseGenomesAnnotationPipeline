include defs.mk

# jobTree configuration
batchSystem = parasol
maxThreads = 30
maxCpus = 1024
defaultMemory = 8589934592
maxJobDuration = 36000

gencodeSubset = ${gencodeComp}
comparativeAnnotationDir = ${ANNOTATION_DIR}_Augustus
transMapChainedAllPsls = ${augustusOrgs:%=${TRANS_MAP_DIR}/transMap/%/transMap${gencodeSubset}.psl}
transMapEvalAllGp = ${augustusOrgs:%=${TRANS_MAP_DIR}/transMap/%/transMap${gencodeSubset}.gp}
augGps = ${augustusOrgs:%=${TMR_DIR}/%.gp}
srcGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
srcFa = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.fa
TMR_DIR = /cluster/home/ifiddes/mus_strain_data/pipeline_data/comparative/1504/augustus/tmr
augustusGps = ${augustusOrgs:%=${TMR_DIR}/%.gp}
comparativeJobTreeDir = $(shell pwd)/.Augustus_${gencodeSubset}_${MSCA_VERSION}_comparativeAnnotatorJobTree
alignJobTreeDir = $(shell pwd)/.consensusAlignJobTree
alignLog = $(shell pwd)/augustusAlign.log
log = $(shell pwd)/Augustus_${gencodeSubset}_${MSCA_VERSION}_jobTree.log
consensusDir = ${comparativeAnnotationDir}/consensus
augustusStatsDir = ${comparativeAnnotationDir}/augustus_stats
augustusBeds = ${augustusOrgs:%=${augustusStatsDir}/%.bed}
augustusFastas = ${augustusOrgs:%=${augustusStatsDir}/%.fa}


all: checkout ${comparativeAnnotationDir}/DONE consensus

checkout:
	cd ../comparativeAnnotator && git checkout augustus && git pull

${comparativeAnnotationDir}/DONE: ${srcGp} ${transMapChainedAllPsls} ${transMapEvalAllGp} ${augustusGps}
	@mkdir -p $(dir $@)
	rm -rf ${comparativeJobTreeDir}
	if [ "${batchSystem}" = "parasol" ]; then \
		cwd="$(shell pwd)" ;\
		ssh ku -Tnx "cd $$cwd && cd ../comparativeAnnotator && export PYTHONPATH=./ && \
		export PATH=./bin/:./sonLib/bin:./jobTree/bin:${PATH} && \
		${python} src/annotationPipeline.py --refGenome ${srcOrg} --genomes ${augustusOrgs} --sizes ${targetChromSizes} \
		--psls ${transMapChainedAllPsls} --gps ${transMapEvalAllGp} --fastas ${targetFastaFiles} --refFasta ${queryFasta} \
		--annotationGp ${srcGp} --batchSystem ${batchSystem} --gencodeAttributeMap ${srcAttrsTsv} \
		--defaultMemory ${defaultMemory} --jobTree ${comparativeJobTreeDir} --maxJobDuration ${maxJobDuration} \
		--maxThreads ${maxThreads} --stats --outDir ${comparativeAnnotationDir} --augustusGps ${augustusGps} &> ${log}" ;\
	else \
		${python} ../comparativeAnnotator/src/annotationPipeline.py --refGenome ${srcOrg} --genomes ${augustusOrgs} --sizes ${targetChromSizes} \
		--psls ${transMapChainedAllPsls} --gps ${transMapEvalAllGp} --fastas ${targetFastaFiles} --refFasta ${queryFasta} \
		--annotationGp ${srcGp} --batchSystem ${batchSystem} --gencodeAttributeMap ${srcAttrsTsv} \
		--defaultMemory ${defaultMemory} --jobTree ${comparativeJobTreeDir} --maxJobDuration ${maxJobDuration} \
		--maxThreads ${maxThreads} --stats --outDir ${comparativeAnnotationDir} --augustusGps ${augustusGps} &> ${log} ;\
	fi
	touch $@

consensus: prepareTranscripts alignTranscripts makeConsensus

prepareTranscripts: ${augustusBeds} ${augustusFastas}

${augustusStatsDir}/%.bed: ${TMR_DIR}/%.gp
	@mkdir -p $(dir $@)
	genePredToBed $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${augustusStatsDir}/%.fa: ${augustusStatsDir}/%.bed
	@mkdir -p $(dir $@)
	fastaFromBed -bed $< -fi ${ASM_GENOMES_DIR}/$*.fa -fo $@.${tmpExt} -s -split -name
	mv -f $@.${tmpExt} $@

alignTranscripts: ${comparativeAnnotationDir}/AUG_ALIGNED

${comparativeAnnotationDir}/AUG_ALIGNED:
	@mkdir -p $(dir $@)
	rm -rf ${alignJobTreeDir}
	if [ "${batchSystem}" = "parasol" ]; then \
		cwd="$(shell pwd)" ;\
		ssh ku -Tnx "cd $$cwd && cd ../comparativeAnnotator && export PYTHONPATH=./ && \
		export PATH=./bin/:./sonLib/bin:./jobTree/bin:${PATH} && \
		${python} scripts/alignAugustus.py --jobTree ${alignJobTreeDir} --batchSystem ${batchSystem} \
		--maxCpus ${maxCpus} --defaultMemory ${defaultMemory} --genomes ${augustusOrgs} --refFasta ${srcFa} \
		--outDir ${augustusStatsDir} &> ${alignLog}" ;\
	else \
		${python} scripts/alignAugustus.py --jobTree ${alignJobTreeDir} --batchSystem ${batchSystem} \
		--maxThreads ${maxThreads} --defaultMemory ${defaultMemory} --genomes ${augustusOrgs} --refFasta ${srcFa} \
		--outDir ${augustusStatsDir} &> ${alignLog}" ;\
	fi
	touch $@

makeConsensus: consensus plots

consensus: ${comparativeAnnotationDir}/CONSENSUS_DONE

${comparativeAnnotationDir}/CONSENSUS_DONE:
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} scripts/consensus.py --genomes ${augustusOrgs} \
	--compAnnPath ${comparativeAnnotationDir} --statsDir ${augustusStatsDir} --outDir ${consensusDir} \
	--attributePath ${srcAttrsTsv} --augGps ${augGps} --tmGps ${transMapEvalAllGp}