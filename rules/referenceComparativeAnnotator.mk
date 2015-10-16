####
# Run comparativeAnnotator on the reference
####
include defs.mk

all: gencode

gencode: ${gencodeSubsets:%=%.gencode}

%.gencode:
	${MAKE} -f rules/comparativeAnnotator.mk annotationGencodeSubset gencodeSubset=$*

ifneq (${gencodeSubset},)

# comparativeAnnotator mode
mode = reference

# done flag dir
doneFlagDir = ${DONE_FLAG_DIR}/${srcOrg}/${gencodeSubset}

#######
# These will run for every GencodeSubset
#######
# jobTree (for transMap comparativeAnnotator)
jobTreeCompAnnTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/comparativeAnnotator/${srcOrg}/${gencodeSubset}
jobTreeCompAnnJobOutput = ${jobTreeCompAnnTmpDir}/comparativeAnnotator.out
jobTreeCompAnnJobDir = ${jobTreeCompAnnTmpDir}/jobTree
comparativeAnnotationDone = ${doneFlagDir}/comparativeAnnotation.done

# jobTree (for clustering classifiers)
jobTreeClusteringTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/clustering/${srcOrg}$/${gencodeSubset}
jobTreeClusteringJobOutput = ${jobTreeClusteringTmpDir}/clustering.out
jobTreeClusteringJobDir = ${jobTreeClusteringTmpDir}/jobTree
clusteringDone = ${doneFlagDir}/classifierClustering.done

# output location
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}
# input files
refGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
refFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa
refSizes = ${ASM_GENOMES_DIR}/${srcOrg}.chrom.sizes

annotationGencodeSubset: ${comparativeAnnotationDone} ${clusteringDone}

${comparativeAnnotationDone}: ${refGp} ${refFasta} ${refSizes}
	@mkdir -p $(dir $@)
	@mkdir -p ${comparativeAnnotationDir}
	if [ -d ${jobTreeCompAnnJobDir} ]; then rm -rf ${jobTreeCompAnnJobDir}; fi
	cd ../comparativeAnnotator ${mode} && ${python} src/annotation_pipeline.py ${jobTreeOpts} \
	--refGenome ${srcOrg} --annotationGp ${refGp} --refFasta ${refFasta} --sizes ${targetSizes} \
	--outDir ${comparativeAnnotationDir} --jobTree ${jobTreeCompAnnJobDir} &> ${jobTreeCompAnnJobOutput}
	touch $@

${clusteringDone}: ${comparativeAnnotationDone}
	@mkdir -p $(dir $@)
	if [ -d ${jobTreeClusteringJobDir} ]; then rm -rf ${jobTreeClusteringJobDir}; fi
	cd ../comparativeAnnotator && ${python} plotting/clustering.py ${jobTreeOpts} \
	--genome ${srcOrg} --outDir ${metricsDir} --comparativeAnnotationDir ${comparativeAnnotationDir} \
	--annotationGp ${refGp} --gencode ${gencodeSubset} --attributePath ${srcGencodeAttrsTsv} \
	--jobTree ${jobTreeClusteringJobDir} &> ${jobTreeClusteringJobOutput}
	touch $@

endif