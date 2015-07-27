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
srcGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
augustusGps = ${augustusOrgs:%=/cluster/home/ifiddes/mus_strain_data/pipeline_data/comparative/1504/augustus/tmr/%.gp}
jobTreeDir = $(shell pwd)/.Augustus_${gencodeSubset}_${MSCA_VERSION}_comparativeAnnotatorJobTree
log = $(shell pwd)/Augustus_${gencodeSubset}_${MSCA_VERSION}_jobTree.log
METRICS_DIR = ${comparativeAnnotationDir}/metrics


all: ${comparativeAnnotationDir}/DONE

${comparativeAnnotationDir}/DONE: ${srcGp} ${transMapChainedAllPsls} ${transMapEvalAllGp} ${augustusGps}
	@mkdir -p $(dir $@)
	rm -rf ${jobTreeDir}
	if [ "${batchSystem}" = "parasol" ]; then \
		cwd="$(shell pwd)" ;\
		ssh ku -Tnx "cd $$cwd && cd ../comparativeAnnotator && export PYTHONPATH=./ && \
		export PATH=./bin/:./sonLib/bin:./jobTree/bin:${PATH} && \
		${python} src/annotationPipeline.py --refGenome ${srcOrg} --genomes ${augustusOrgs} --sizes ${targetChromSizes} \
		--psls ${transMapChainedAllPsls} --gps ${transMapEvalAllGp} --fastas ${targetFastaFiles} --refFasta ${queryFasta} \
		--annotationGp ${srcGp} --batchSystem ${batchSystem} --gencodeAttributeMap ${srcAttrsTsv} \
		--defaultMemory ${defaultMemory} --jobTree ${jobTreeDir} --maxJobDuration ${maxJobDuration} \
		--maxThreads ${maxThreads} --stats --outDir ${comparativeAnnotationDir} --augustusGps ${augustusGps} &> ${log}" ;\
	else \
		${python} ../comparativeAnnotator/src/annotationPipeline.py --refGenome ${srcOrg} --genomes ${augustusOrgs} --sizes ${targetChromSizes} \
		--psls ${transMapChainedAllPsls} --gps ${transMapEvalAllGp} --fastas ${targetFastaFiles} --refFasta ${queryFasta} \
		--annotationGp ${srcGp} --batchSystem ${batchSystem} --gencodeAttributeMap ${srcAttrsTsv} \
		--defaultMemory ${defaultMemory} --jobTree ${jobTreeDir} --maxJobDuration ${maxJobDuration} \
		--maxThreads ${maxThreads} --stats --outDir ${comparativeAnnotationDir} --augustusGps ${augustusGps} &> ${log} ;\
	fi
	touch $@