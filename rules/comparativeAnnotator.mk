include config.mk

# jobTree configuration
batchSystem = parasol
maxThreads = 30
maxCpus = 1024
defaultMemory = 8589934592
maxJobDuration = 36000

ifneq (${gencodeSubset},)
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}
transMapChainedAllPsls = ${mappedOrgs:%=${TRANS_MAP_DIR}/transMap/%/transMap${gencodeSubset}.psl}
transMapEvalAllGp = ${mappedOrgs:%=${TRANS_MAP_DIR}/transMap/%/transMap${gencodeSubset}.gp}
srcGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
jobTreeDir = $(shell pwd)/.${gencodeSubset}_comparativeAnnotatorJobTree
log = $(shell pwd)/${gencodeSubset}_jobTree.log
endif


all: annotation

annotation: ${GencodeSubsets:%=%.annotation}

%.annotation:
	@echo ${srcGencodeAllGp}
	${MAKE} -f rules/comparativeAnnotator.mk annotationGencodeSubset gencodeSubset=$*

ifneq (${gencodeSubset},)
annotationGencodeSubset: ${comparativeAnnotationDir}/DONE ${METRICS_DIR}/DONE

${comparativeAnnotationDir}/DONE: ${srcGp} ${transMapChainedAllPsls} ${transMapEvalAllGp}
	@mkdir -p $(dir $@)
	if [ -d ${jobTreeDir} ]; then rm -rf ${jobTreeDir}; fi
	if [ "${batchSystem}" = "parasol" ]; then \
		cwd="$(shell pwd)" ;\
		ssh ku -t "cd $$cwd && cd ../comparativeAnnotator && export PYTHONPATH=./ && \
		export PATH=./bin/:./sonLib/bin:./jobTree/bin:${PATH} && \
		python src/annotationPipeline.py --refGenome ${srcOrg} --genomes ${mappedOrgs} --sizes ${targetChromSizes} \
		--psls ${transMapChainedAllPsls} --gps ${transMapEvalAllGp} --fastas ${targetFastaFiles} --refTwoBit ${queryTwoBit} \
		--annotationGp ${srcGp} --batchSystem ${batchSystem} --gencodeAttributeMap ${srcAttrsTsv} \
		--defaultMemory ${defaultMemory} --jobTree ${jobTreeDir} --maxJobDuration ${maxJobDuration} \
		--maxThreads ${maxThreads} --stats --outDir ${comparativeAnnotationDir} &> ${log}" ;\
	else \
		python ../comparativeAnnotator/src/annotationPipeline.py --refGenome ${srcOrg} --genomes ${mappedOrgs} --sizes ${targetChromSizes} \
		--psls ${transMapChainedAllPsls} --gps ${transMapEvalAllGp} --fastas ${targetFastaFiles} --refTwoBit ${queryTwoBit} \
		--annotationGp ${srcGp} --batchSystem ${batchSystem} --gencodeAttributeMap ${srcAttrsTsv} \
		--defaultMemory ${defaultMemory} --jobTree ${jobTreeDir} --maxJobDuration ${maxJobDuration} \
		--maxThreads ${maxThreads} --stats --outDir ${comparativeAnnotationDir} &> ${log} ;\
	fi
	touch $@

${METRICS_DIR}/DONE: ${comparativeAnnotationDir}/DONE
	@mkdir -p $(dir $@)
	python scripts/coverage_identity_ok_plots.py --outDir ${METRICS_DIR} --genomes ${genomes} \
	--comparativeAnnotationDir ${comparativeAnnotationDir} --header ${MSCA_VERSION} --attrs ${srcAttrsTsv} \
	--annotationBed ${srcCombinedCheckBed}
	touch $@

endif