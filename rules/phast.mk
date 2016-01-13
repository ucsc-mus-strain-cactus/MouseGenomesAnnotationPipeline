include defs.mk

PHAST_ANALYSIS_DIR=${DATA_DIR}/comparative/${VERSION}/phastAnalysis
modFile=${PHAST_ANALYSIS_DIR}/rates.mod
errorFile=${PHAST_ANALYSIS_DIR}/rates.err
4dSitesBed=${PHAST_ANALYSIS_DIR}/4d.bed

# FIXME: don't hardcode this
cleanedCdsBed=/hive/groups/recon/projs/mus_strain_cactus/experiments/phylogeny/basic_vm8_cds.bed
refGenome=C57B6J

all: phyloFit

phyloFit: ${modFile}

# --conserved option will ensure that the 4d sites are actually 4d
# sites in all species. This helps protect against poor annotations,
# or underestimating the rate due to conserved nonsynonymous mutations.
${4dSitesBed}: ${cleanedCdsBed}
	@mkdir -p $(dir $@)
	hal4dExtract --conserved ${halFile} ${refGenome} ${cleanedCdsBed} ${4dSitesBed}.${tmpExt}
	mv -f $@.${tmpExt} $@

${modFile}: ${4dSitesBed}
	@mkdir -p $(dir $@)
	halPhyloPTrain.py --numProc 4 --noAncestors --no4d ${halFile} ${refGenome} ${4dSitesBed} ${modFile} --error ${errorFile}
	mv -f $@.${tmpExt} $@
