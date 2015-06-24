include defs.mk
include rules/augustusReverseTransMap.mk

# jobTree configuration
batchSystem = parasol
maxThreads = 30
maxCpus = 1024
defaultMemory = 8589934592
maxJobDuration = 36000

comparativeAnnotationDir = ${ANNOTATION_DIR}/augustus
transMapDir = /cluster/home/ifiddes/mus_strain_data/pipeline_data/comparative/1504/augustus_transMap
transMapChainedAllPsls = ${mappedOrgs:%=${transMapDir}/%.augustusTranscripts.psl}
transMapEvalAllGp = ${mappedOrgs:%=${transMapDir}/%.augustusTranscripts.transMapped.gp}
srcGps = ${mappedOrgs:%=${transMapDir}/%.augustusTranscripts.gp}
jobTreeDir = $(shell pwd)/.augustus_${MSCA_VERSION}_comparativeAnnotatorJobTree
log = $(shell pwd)/augustus_${MSCA_VERSION}_jobTree.log
METRICS_DIR = ${comparativeAnnotationDir}/metrics


all: annotation

annotation: ${comparativeAnnotationDir}/DONE ${METRICS_DIR}/DONE

${comparativeAnnotationDir}/DONE: ${srcGp} ${transMapChainedAllPsls} ${transMapEvalAllGp}
	@mkdir -p $(dir $@)
	rm -rf ${jobTreeDir}
	if [ "${batchSystem}" = "parasol" ]; then \
		cwd="$(shell pwd)" ;\
		ssh ku -Tnx "cd $$cwd && cd ../comparativeAnnotator && export PYTHONPATH=./ && \
		export PATH=./bin/:./sonLib/bin:./jobTree/bin:${PATH} && \
		${python} src/annotationPipeline.py --tgtGenomes ${srcOrg} --srcGenomes ${mappedOrgs} --tgtSizes ${targetChromSizes} \
		--psls ${transMapChainedAllPsls} --tgtGps ${transMapEvalAllGp} --srcFastas ${targetFastaFiles} --tgtFastas ${queryFasta} \
		--srcGps ${srcGps} --batchSystem ${batchSystem} --gencodeAttributeMap ${srcAttrsTsv} \
		--defaultMemory ${defaultMemory} --jobTree ${jobTreeDir} --maxJobDuration ${maxJobDuration} \
		--maxThreads ${maxThreads} --stats --outDir ${comparativeAnnotationDir} &> ${log}" ;\
	else \
		${python} ../comparativeAnnotator/src/annotationPipeline.py --tgtGenomes ${srcOrg} --srcGenomes ${mappedOrgs} --tgtSizes ${targetChromSizes} \
		--psls ${transMapChainedAllPsls} --tgtGps ${transMapEvalAllGp} --srcFastas ${targetFastaFiles} --tgtFastas ${queryFasta} \
		--srcGps ${srcGps} --batchSystem ${batchSystem} --gencodeAttributeMap ${srcAttrsTsv} \
		--defaultMemory ${defaultMemory} --jobTree ${jobTreeDir} --maxJobDuration ${maxJobDuration} \
		--maxThreads ${maxThreads} --stats --outDir ${comparativeAnnotationDir} &> ${log} ;\
	fi
	touch $@

${METRICS_DIR}/DONE: ${comparativeAnnotationDir}/DONE
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator ;\
	${python} scripts/coverage_identity_ok_plots.py --outDir ${METRICS_DIR} --genomes ${mappedOrgs} \
	--comparativeAnnotationDir ${comparativeAnnotationDir} --header ${MSCA_VERSION} --attrs ${srcAttrsTsv} \
	--annotationGp ${srcGp}
	touch $@
