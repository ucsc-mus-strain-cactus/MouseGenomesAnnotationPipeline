########
# Specify targetGenomes= on command line when running to subset the alignment
########

include defs.mk

# FIXME: don't hardcode this
cleanedCdsBed=/hive/groups/recon/projs/mus_strain_cactus/experiments/phylogeny/basic_vm8_cds.bed

comma = ,
# function to convert commas to underscores
make_dots = $(subst ${comma},.,$1)
# function to convert spaces to commas. $(eval) is a hack to get a space
make_commas = $(subst $(eval) ,${comma},$1)

# if targetGenomes is defined on the command line, format it for dless
ifneq (${targetGenomes},)
targetGenomeStr = --targetGenomes ${targetGenomes}
outputDirBase = $(call make_dots,${targetGenomes})
tree = --tree "$(shell bin/extractHalTreeSubset ${halFile} ${targetGenomes})"
else
targetGenomeCommas = $(call make_commas,${mappedOrgs})
outputDirBase = $(call make_dots,${targetGenomeCommas})
targetGenomeStr = 
tree = 
endif

PHAST_ANALYSIS_DIR=${DATA_DIR}/comparative/${VERSION}/phastAnalysis/${outputDirBase}
dlessOutDir = ${PHAST_ANALYSIS_DIR}/dless
outputDlessGff = ${dlessOutDir}/dless.gff
phastConsOutDir = ${PHAST_ANALYSIS_DIR}/phastCons
phastConsBed = ${phastConsOutDir}/phastCons.bed
phastConsWig = ${phastConsOutDir}/phastCons.wig
modFile=${PHAST_ANALYSIS_DIR}/rates.mod
errorFile=${PHAST_ANALYSIS_DIR}/rates.err
4dSitesBed=${PHAST_ANALYSIS_DIR}/4d_no_conserved.bed
wigDir=${PHAST_ANALYSIS_DIR}/phyloPWigs
refFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa

# jobTree for dless
jobTreeDlessTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/dless/${outputDirBase}
jobTreeDlessJobOutput = ${jobTreeDlessTmpDir}/dless.out
jobTreeDlessJobDir = ${jobTreeDlessTmpDir}/jobTree

# jobTree for phastCons
jobTreePhastConsTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/phastCons/${outputDirBase}
jobTreePhastConsJobOutput = ${jobTreePhastConsTmpDir}/phastCons.out
jobTreePhastConsJobDir = ${jobTreePhastConsTmpDir}/jobTree

all: phyloP dless phastCons

phyloP: ${modFile}
	@mkdir -p ${wigDir}
	halTreePhyloP.py --numProc 20 ${halFile} ${modFile} ${wigDir}

dless: ${outputDlessGff}

${outputDlessGff}: ${modFile}
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeDlessTmpDir}
	cd ../comparativeAnnotator && ${python} phast/dless.py ${halFile} ${srcOrg} $< $@.${tmpExt} --ref-fasta-path ${refFasta} \
	${jobTreeOpts} --jobTree ${jobTreeDlessJobDir} &> ${jobTreeDlessJobOutput}
	mv -f $@.${tmpExt} $@

phastCons: ${phastConsBed}

# this is ugly, but hacks to have 2 files made by 1 target seemed uglier. We may lose the wiggle.
${phastConsBed}: ${modFile}
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreePhastConsTmpDir}
	cd ../comparativeAnnotator && ${python} phast/phastcons.py ${halFile} ${srcOrg} $< $@ ${phastConsWig} --ref-fasta-path ${refFasta} \
	${jobTreeOpts} --jobTree ${jobTreePhastConsJobDir} &> ${jobTreePhastConsJobOutput}


# --conserved option will ensure that the 4d sites are actually 4d
# sites in all species. This helps protect against poor annotations,
# or underestimating the rate due to conserved nonsynonymous mutations.
${4dSitesBed}: ${cleanedCdsBed}
	@mkdir -p $(dir $@)
	hal4dExtract ${halFile} ${srcOrg} ${cleanedCdsBed} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

# .mod extension required after tmpExt because phast will check the
# output file extension for some reason
${modFile}: ${4dSitesBed}
	@mkdir -p $(dir $@)
	cd ../comparativeAnnotator && ${python} hal/phyloP/halPhyloPTrain.py --numProc 6 --noAncestors \
	--no4d ${halFile} ${srcOrg} ${4dSitesBed} $@.${tmpExt}.mod --error ${errorFile} ${targetGenomeStr} ${tree}
	mv -f $@.${tmpExt}.mod $@
