include config.mk

# jobTree configuration
batchSystem = parasol
maxThreads = 30
maxCpus = 1024
defaultMemory = 8589934592
maxJobDuration = 36000

ifneq (${gencodeSubset},)
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}
transMapChainedAllPsls = ${srcOrgs:%=${TRANS_MAP_DIR}/transMap/%/${gencodeSubset}.psl}
transMapEvalAllGp = ${srcOrgs:%=${TRANS_MAP_DIR}/transMap/%/${gencodeSubset}.gp}
srcGp = ${SRC_GENCODE_DATA_DIR}/${gencodeSubset}.gp
jobTreeDir = .${gencodeSubset}_comparativeAnnotatorJobTree
log = ${gencodeSubset}_jobTree.log
endif


all: extractFasta annotation

extractFasta: ${targetFastaFiles} ${targetTwoBitFiles} ${targetChromSizes} ${queryFasta} ${queryTwoBit} ${queryChromSizes}

${GENOMES_DIR}/%.fa:
	@mkdir -p $(dir $@)
	n="$(shell basename $@ | cut -d "." -f 1)" ;\
	hal2fasta ${HAL} $$n > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${GENOMES_DIR}/%.2bit: ${GENOMES_DIR}/%.fa
	@mkdir -p $(dir $@)
	faToTwoBit $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${GENOMES_DIR}/%.chrom.sizes:
	@mkdir -p $(dir $@)
	n="$(shell basename $@ | cut -d "." -f 1)" ;\
	halStats --chromSizes $$n ${HAL} > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${queryFasta}:
	@mkdir -p $(dir $@)
	n="$(shell basename $@ | cut -d "." -f 1)" ;\
	hal2fasta ${HAL} $$n > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${queryTwoBit}: ${queryFasta}
	@mkdir -p $(dir $@)
	faToTwoBit ${queryFasta} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${queryChromSizes}: ${queryTwoBit}
	@mkdir -p $(dir $@)
	twoBitInfo ${queryTwoBit} stdout | sort -k2rn > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

annotation: ${srcGencodeSubsets:%=%.annotation}

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
		--maxThreads ${maxThreads} --stats --outDir ${comparativeAnnotationDir} &> ${log}" ;\
	fi
	touch $@

${METRICS_DIR}/DONE: ${comparativeAnnotationDir}/DONE
	@mkdir -p $(dir $@)
	python scripts/coverage_identity_ok_plots.py --outDir ${METRICS_DIR} --genomes ${genomes} \
	--comparativeAnnotationDir ${comparativeAnnotationDir} --header ${MSCA_VERSION} --attrs ${srcAttrsTsv} \
	--annotationBed ${srcCombinedCheckBed}
	touch $@

endif