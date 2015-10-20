####
# Run comparativeAnnotator on the reference
####
include defs.mk

all: gencode

clean: ${gencodeSubsets:%=%.gencode.clean}

gencode: ${gencodeSubsets:%=%.gencode}

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

# output location
comparativeAnnotationDir = ${ANNOTATION_DIR}/${gencodeSubset}

# input files
refGp = ${SRC_GENCODE_DATA_DIR}/wgEncode${gencodeSubset}.gp
refFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa
refSizes = ${ASM_GENOMES_DIR}/${srcOrg}.chrom.sizes

annotationGencodeSubset: ${comparativeAnnotationDone}

${comparativeAnnotationDone}: ${refGp} ${refFasta} ${refSizes}
	@mkdir -p $(dir $@)
	@mkdir -p ${comparativeAnnotationDir}
	@mkdir -p ${jobTreeCompAnnTmpDir}
	cd ../comparativeAnnotator && ${python} src/annotation_pipeline.py ${mode} ${jobTreeOpts} \
	--refGenome ${srcOrg} --annotationGp ${refGp} --refFasta ${refFasta} --sizes ${refSizes} \
	--gencodeAttributes ${srcGencodeAttrsTsv} --outDir ${comparativeAnnotationDir} \
	--jobTree ${jobTreeCompAnnJobDir} &> ${jobTreeCompAnnJobOutput}
	touch $@

annotationGencodeSubsetClean:
	rm -rf ${jobTreeCompAnnJobDir} ${comparativeAnnotationDone}

endif