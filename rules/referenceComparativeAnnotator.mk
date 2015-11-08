####
# Run comparativeAnnotator on the reference
####
include defs.mk

all: gencode

gencode: ${gencodeSubsets:%=%.gencode}

clean: ${gencodeSubsets:%=%.gencode.clean}

%.gencode:
	${MAKE} -f rules/referenceComparativeAnnotator.mk annotationGencodeSubset gencodeSubset=$*

%.gencode.clean:
	${MAKE} -f rules/referenceComparativeAnnotator.mk annotationGencodeSubsetClean gencodeSubset=$*

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
jobTreeClusteringTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/clustering/${srcOrg}/${gencodeSubset}
jobTreeClusteringJobOutput = ${jobTreeClusteringTmpDir}/clustering.out
jobTreeClusteringJobDir = ${jobTreeClusteringTmpDir}/jobTree
clusteringDone = ${doneFlagDir}/classifierClustering.done

# output location
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}
metricsDir = ${comparativeAnnotationDir}/metrics

# input files
refGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
refFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa
refSizes = ${ASM_GENOMES_DIR}/${srcOrg}.chrom.sizes

annotationGencodeSubset: ${comparativeAnnotationDone} ${clusteringDone}

${comparativeAnnotationDone}: ${refGp} ${refFasta} ${refSizes}
	@mkdir -p $(dir $@)
	@mkdir -p ${comparativeAnnotationDir}
	@mkdir -p ${jobTreeCompAnnTmpDir}
	cd ../comparativeAnnotator && ${python} src/annotation_pipeline.py ${mode} ${jobTreeOpts} \
	--refGenome ${srcOrg} --annotationGp ${refGp} --refFasta ${refFasta} --sizes ${refSizes} \
	--gencodeAttributes ${srcGencodeAttrsTsv} --outDir ${comparativeAnnotationDir} \
	--jobTree ${jobTreeCompAnnJobDir} &> ${jobTreeCompAnnJobOutput}
	touch $@

${clusteringDone}: ${comparativeAnnotationDone}
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeClusteringTmpDir}
	cd ../comparativeAnnotator && ${python} plotting/clustering.py ${jobTreeOpts} --mode reference \
	--genome ${srcOrg} --refGenome ${srcOrg} --outDir ${metricsDir} \
	--comparativeAnnotationDir ${comparativeAnnotationDir} --gencode ${gencodeSubset} \
	--jobTree ${jobTreeClusteringJobDir} &> ${jobTreeClusteringJobOutput}
	touch $@

annotationGencodeSubsetClean:
	rm -rf ${jobTreeCompAnnJobDir} ${comparativeAnnotationDone} ${clusteringDone} ${jobTreeClusteringJobDir}

endif