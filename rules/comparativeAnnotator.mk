####
# Run comparativeAnnotator
####
include defs.mk

all: gencode

gencode: ${gencodeSubsets:%=%.gencode}

clean: ${gencodeSubsets:%=%.gencode.clean}

%.gencode:
	${MAKE} -f rules/comparativeAnnotator.mk annotationGencodeSubset gencodeSubset=$*

%.gencode.clean:
	${MAKE} -f rules/comparativeAnnotator.mk annotationGencodeSubsetClean gencodeSubset=$*

annotationGencodeSubset: ${mappedOrgs:%=%.annotationGencodeSubset}

annotationGencodeSubsetClean: ${mappedOrgs:%=%.annotationGencodeSubsetClean}

%.annotationGencodeSubset:
	${MAKE} -f rules/comparativeAnnotator.mk runOrg mapTargetOrg=$* gencodeSubset=${gencodeSubset}

%.annotationGencodeSubsetClean:
	${MAKE} -f rules/comparativeAnnotator.mk cleanOrg mapTargetOrg=$* gencodeSubset=${gencodeSubset}

ifneq (${gencodeSubset},)
ifneq (${mapTargetOrg},)

# comparativeAnnotator mode
mode = transMap

# done flag dir
doneFlagDir = ${DONE_FLAG_DIR}/${mapTargetOrg}/${gencodeSubset}

#######
# These will run for every combination of GencodeSubset-mapTargetOrg
#######
# jobTree (for transMap comparativeAnnotator)
jobTreeCompAnnTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/comparativeAnnotator/${mapTargetOrg}/${gencodeSubset}
jobTreeCompAnnJobOutput = ${jobTreeCompAnnTmpDir}/comparativeAnnotator.out
jobTreeCompAnnJobDir = ${jobTreeCompAnnTmpDir}/jobTree
comparativeAnnotationDone = ${doneFlagDir}/comparativeAnnotation.done

# jobTree (for clustering classifiers)
jobTreeClusteringTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/clustering/${mapTargetOrg}/${gencodeSubset}
jobTreeClusteringJobOutput = ${jobTreeClusteringTmpDir}/clustering.out
jobTreeClusteringJobDir = ${jobTreeClusteringTmpDir}/jobTree
clusteringDone = ${doneFlagDir}/classifierClustering.done

# output location
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}
metricsDir = ${comparativeAnnotationDir}/metrics

# input files
transMapDataDir = ${TRANS_MAP_DIR}/transMap/${mapTargetOrg}
refGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
refFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa
psl = ${transMapDataDir}/transMap${gencodeSubset}.psl
refPsl = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.psl
targetGp = ${transMapDataDir}/transMap${gencodeSubset}.gp
targetFasta = ${ASM_GENOMES_DIR}/${mapTargetOrg}.fa
targetSizes = ${ASM_GENOMES_DIR}/${mapTargetOrg}.chrom.sizes

runOrg: ${comparativeAnnotationDone} ${clusteringDone}

${comparativeAnnotationDone}: ${psl} ${targetGp} ${refGp} ${refFasta} ${targetFasta} ${targetSizes}
	@mkdir -p $(dir $@)
	@mkdir -p ${comparativeAnnotationDir}
	@mkdir -p ${jobTreeCompAnnTmpDir}
	cd ../comparativeAnnotator && ${python} src/annotation_pipeline.py ${mode} ${jobTreeOpts} \
	--refGenome ${srcOrg} --genome ${mapTargetOrg} --annotationGp ${refGp} --psl ${psl} --targetGp ${targetGp} \
	--fasta ${targetFasta} --refFasta ${refFasta} --sizes ${targetSizes} --outDir ${comparativeAnnotationDir} \
	--gencodeAttributes ${srcGencodeAttrsTsv} --jobTree ${jobTreeCompAnnJobDir} --refPsl ${refPsl} \
	&> ${jobTreeCompAnnJobOutput}
	touch $@

${clusteringDone}: ${comparativeAnnotationDone}
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeClusteringTmpDir}
	cd ../comparativeAnnotator && ${python} plotting/clustering.py ${jobTreeOpts} \
	--genome ${mapTargetOrg} --refGenome ${srcOrg} --outDir ${metricsDir} \
	--comparativeAnnotationDir ${comparativeAnnotationDir} --gencode ${gencodeSubset} \
	--jobTree ${jobTreeClusteringJobDir} &> ${jobTreeClusteringJobOutput}
	touch $@


cleanOrg:
	rm -rf ${jobTreeCompAnnJobDir} ${comparativeAnnotationDone} ${jobTreeClusteringJobDir} ${clusteringDone}

endif
endif