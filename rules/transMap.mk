###
# configuration  FIXME: move to common file
###
MSCA_VERSION = 1411
#MSCA_VERSION = 1412
GENCODE_VERSION = VM4
TRANS_MAP_VERSION = 2015-05-15

MSCA_PROJ_DIR = /hive/groups/recon/projs/mus_strain_cactus
MSCA_DATA_DIR = ${MSCA_PROJ_DIR}/pipeline_data
MSCA_ASSMEBLIES_DIR = ${MSCA_DATA_DIR}/assemblies/${MSCA_VERSION}
HAL_BIN = ${MSCA_PROJ_DIR}/src/progressiveCactus/submodules/hal/bin
PYCBIO_DIR = ${MSCA_PROJ_DIR}/src/pycbio
TRANS_MAP_DIR = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/transMap/${TRANS_MAP_VERSION}


# programs
# FIXME: integrate geneCheck changes to Ian's tree
geneCheck = ~markd/compbio/genefinding/GeneTools/bin/x86_64/opt/gene-check
halLiftover = ${HAL_BIN}/halLiftover


halFile = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/cactus/${MSCA_VERSION}.hal
ASM_GENOMES_DIR = ${MSCA_DATA_DIR}/assemblies/${MSCA_VERSION}/genome
srcHgDb= mm10
srcOrg = C57B6J
# FIXME: includeing srcOrg below is a hack
ifeq (${MSCA_VERSION},1411)
mappedOrgs = 129S1 AJ AKRJ BALBcJ C3HHeJ C57B6J C57B6NJ CASTEiJ CBAJ DBA2J FVBNJ LPJ NODShiLtJ NZOHlLtJ PWKPhJ SPRETEiJ WSBEiJ  Rattus
else ifeq (${MSCA_VERSION},1412)
mappedOrgs = 129S1 AJ AKRJ BALBcJ C3HHeJ C57B6J C57B6NJ CAROLIEiJ CASTEiJ CBAJ DBA2J FVBNJ LPJ NODShiLtJ NZOHlLtJ PAHARIEiJ PWKPhJ Rattus SPRETEiJ WSBEiJ
else
$(error MSCA_VERSION=${MSCA_VERSION} not handled in makefile.
endif

# FIXME due to different naming conventions, there are rules at the bottom to create 2bit from
# FASTA files
genomeMap_129S1 = 129S1_SvImJ
genomeMap_AJ = A_J
genomeMap_AKRJ = AKR_J
genomeMap_BALBcJ = BALB_cJ
genomeMap_C3HHeJ = C3H_HeJ
genomeMap_C57B6NJ = C57BL_6NJ
genomeMap_CAROLIEiJ = CAROLI_EiJ
genomeMap_CASTEiJ = CAST_EiJ
genomeMap_CBAJ = CBA_J
genomeMap_DBA2J = DBA_2J
genomeMap_FVBNJ = FVB_NJ
genomeMap_LPJ = LP_J
genomeMap_C57B6J = Mus_musculus.GRCm38.dna_sm.primary_assembly
genomeMap_NODShiLtJ = NOD_ShiLtJ
genomeMap_NZOHlLtJ = NZO_HlLtJ
genomeMap_PAHARIEiJ = Pahari_EiJ
genomeMap_PWKPhJ = PWK_PhJ
genomeMap_Rattus = Rattus_norvegicus.Rnor_5.0.dna_sm.toplevel
genomeMap_SPRETEiJ = SPRET_EiJ
genomeMap_WSBEiJ = WSB_EiJ


###
# make stuff
##
host=$(shell hostname)
ppid=$(shell echo $$PPID)
tmpExt = ${host}.${ppid}.tmp

.SECONDARY:  # keep intermediates
SHELL = /bin/bash -beEu
export SHELLOPTS=pipefail
export PATH:=${PATH}:${PYCBIO_DIR}/bin:./bin
ifneq ($(wildcard ${HOME}/.hg.rem.conf),)
    # if this exists, it allows running on kolossus because of remote access to UCSC databases
    export HGDB_CONF=${HOME}/.hg.rem.conf
endif
# insist on group-writable umask
ifneq ($(shell umask),0002)
     $(error umask must be 0002)
endif

##
# GENCODE src annotations
##
srcGencodeBasic = wgEncodeGencodeBasic${GENCODE_VERSION}
srcGencodeComp = wgEncodeGencodeComp${GENCODE_VERSION}
srcGencodePseudo = wgEncodeGencodePseudoGene${GENCODE_VERSION}
srcGencodeAttrs = wgEncodeGencodeAttrs${GENCODE_VERSION}
srcGencodeSubsets = ${srcGencodeBasic} ${srcGencodeComp} ${srcGencodePseudo}
srcGencodeDataDir = ${TRANS_MAP_DIR}/data
srcAttrsTsv = ${srcGencodeDataDir}/${srcGencodeAttrs}.tsv
srcGencodeAllGp = ${srcGencodeSubsets:%=${srcGencodeDataDir}/%.gp}
srcGencodeAllFa = ${srcGencodeSubsets:%=${srcGencodeDataDir}/%.fa}
srcGencodeAllPsl = ${srcGencodeSubsets:%=${srcGencodeDataDir}/%.psl}
srcGencodeAllCds = ${srcGencodeSubsets:%=${srcGencodeDataDir}/%.cds}
srcGencodeAllSizes = ${srcGencodeSubsets:%=${srcGencodeDataDir}/%.sizes}
srcGencodeAllBed = ${srcGencodeSubsets:%=${srcGencodeDataDir}/%.bed}
srcGencodeAllCheck =  ${srcGencodeSubsets:%=${srcGencodeDataDir}/%.gene-check}
srcGencodeAllCheckDetails =  ${srcGencodeSubsets:%=${srcGencodeDataDir}/%.gene-check-details}
srcGencodeCheckBed =  ${srcGencodeSubsets:%=${srcGencodeDataDir}/%.gene-check.bed}
srcGencodeAllCheckDetailsBed =  ${srcGencodeSubsets:%=${srcGencodeDataDir}/%.gene-check-details.bed}
srcGencodeAllCheckStats =  ${srcGencodeSubsets:%=${srcGencodeDataDir}/%.gene-check.stats}


##
# mappings  These are only define when mapTargetOrg is defined by recurisve make
# mapTargetOrg= specifies the target organism
##
ifneq (${mapTargetOrg},)
transMapDataDir = ${TRANS_MAP_DIR}/transMap/${mapTargetOrg}

transMapGencodeBasic = transMapGencodeBasic${GENCODE_VERSION}
transMapGencodeComp = transMapGencodeComp${GENCODE_VERSION}
transMapGencodePseudo = transMapGencodePseudoGene${GENCODE_VERSION}
transMapGencodeAttrs = transMapGencodeAttrs${GENCODE_VERSION}
transMapGencodeSubsets = ${transMapGencodeBasic} ${transMapGencodeComp} ${transMapGencodePseudo}

# block transMap
transMapMappedRegionIdAllPsl = ${transMapGencodeSubsets:%=${transMapDataDir}/%.region.idpsl}
transMapMappedBlockAllPsl = ${transMapGencodeSubsets:%=${transMapDataDir}/%.block.psl}
transMapMappedBlockAllMapInfo = ${transMapGencodeSubsets:%=${transMapDataDir}/%.block.mapinfo}

# chained (final results)
transMapChainedAllPsls = ${transMapGencodeSubsets:%=${transMapDataDir}/%.psl}
transMapChainedAllQstats = ${transMapGencodeSubsets:%=${transMapDataDir}/%.qstats}

# geneCheck of mapped
transMapEvalAllGp = ${transMapGencodeSubsets:%=${transMapDataDir}/%.gp}
transMapEvalAllGeneCheck = ${transMapGencodeSubsets:%=${transMapDataDir}/%.gene-check}
transMapEvalAllGeneCheckDetails = ${transMapGencodeSubsets:%=${transMapDataDir}/%.gene-check-details}
transMapEvalAllGeneCheckStats = ${transMapGencodeSubsets:%=${transMapDataDir}/%.gene-check.stats}
transMapEvalAllGeneCheckBed = ${transMapGencodeSubsets:%=${transMapDataDir}/%.gene-check.bed}
transMapEvalAllGeneCheckDetailsBed = ${transMapGencodeSubsets:%=${transMapDataDir}/%.gene-check-details.bed}
endif

all: srcData transMap

###
# src genes
###
srcData: ${srcAttrsTsv} ${srcGencodeAllGp} ${srcGencodeAllFa} ${srcGencodeAllPsl} \
	${srcGencodeAllCds} ${srcGencodeAllSizes} ${srcGencodeAllBed} \
	${srcGencodeAllCheck} ${srcGencodeAllCheckDetails} ${srcGencodeCheckBed} ${srcGencodeAllCheckDetailsBed} ${srcGencodeAllCheckStats}

# awk expression to edit chrom names in UCSC format.  Assumse all alts are version 1.
# chr1_GL456211_random, chrUn_GL456239
# FIXME: this is also build_browser/bin/ucscToEnsemblChrom
editUcscChrom = $$chromCol=="chrM"{$$chromCol="MT"} {$$chromCol = gensub("_random$$","", "g", $$chromCol);$$chromCol = gensub("^chr.*_([0-9A-Za-z]+)$$","\\1.1", "g", $$chromCol);  gsub("^chr","",$$chromCol); print $$0}

${srcAttrsTsv}:
	@mkdir -p $(dir $@)
	hgsql -e 'select * from ${srcGencodeAttrs}' ${srcHgDb} >$@.${tmpExt}
	mv -f $@.${tmpExt} $@

${srcGencodeDataDir}/%.gp:
	@mkdir -p $(dir $@)
	hgsql -Ne 'select * from $*' ${srcHgDb} | cut -f 2- | tawk -v chromCol=2 '${editUcscChrom}' >$@.${tmpExt}
	mv -f $@.${tmpExt} $@

${srcGencodeDataDir}/%.fa:
	@mkdir -p $(dir $@)
	getRnaPred ${srcHgDb} $* all $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${srcGencodeDataDir}/%.bed: ${srcGencodeDataDir}/%.gp
	@mkdir -p $(dir $@)
	genePredToBed $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${srcGencodeDataDir}/%.cds: ${srcGencodeDataDir}/%.psl
	@
${srcGencodeDataDir}/%.psl:
	@mkdir -p $(dir $@)
	genePredToFakePsl ${srcHgDb} $* stdout ${srcGencodeDataDir}/$*.cds | tawk -v chromCol=14 '${editUcscChrom}' >$@.${tmpExt}
	mv -f $@.${tmpExt} $@

${srcGencodeDataDir}/%.sizes: ${srcGencodeDataDir}/%.psl
	tawk '{print $$10,$$11}' $< >$@.${tmpExt}
	mv -f $@.${tmpExt} $@

${transMapDataDir}/%.qstats: %.psl ${srcGencodeDataDir}/%.sizes
	pslStats -queryStats -queries=${srcGencodeDataDir}/$*.sizes $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

# gene-check of source
${srcGencodeDataDir}/%.gene-check-details: ${srcGencodeDataDir}/%.gene-check
	@
${srcGencodeDataDir}/%.gene-check: ${srcGencodeDataDir}/%.gp ${MSCA_ASSMEBLIES_DIR}/${srcOrg}.2bit
	@mkdir -p $(dir $@)
	sort -k2,2 -k 4,4n $< | ${geneCheck} --allow-non-coding --genome-seqs=${MSCA_ASSMEBLIES_DIR}/${srcOrg}.2bit --details-out=$@-details stdin $@.${tmpExt}
	mv -f $@.${tmpExt} $@

####
# transMap recursive target for each organism
####
transMap: ${mappedOrgs:%=%.transMap}

%.transMap:
	${MAKE} -f rules/transMap.mk transMapOrg mapTargetOrg=$*

ifneq (${mapTargetOrg},)
transMapOrg: ${transMapMappedRegionIdAllPsl} ${transMapMappedBlockAllPsl} ${transMapChainedAllPsls} ${transMapChainedAllQstats} ${transMapEvalAllGp} \
	${transMapEvalAllGeneCheck} ${transMapEvalAllGeneCheckDetails} ${transMapEvalAllGeneCheckStats} ${transMapEvalAllGeneCheckBed} \
	${transMapEvalAllGeneCheckDetailsBed}


####
# mapping
#
${transMapDataDir}/transMap%.region.idpsl: ${srcGencodeDataDir}/wgEncode%.bed
	@mkdir -p $(dir $@)
	${halLiftover} --tab --outPSLWithName ${halFile} ${srcOrg} $< ${mapTargetOrg}  $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${transMapDataDir}/transMap%.block.mapinfo: ${transMapDataDir}/transMap%.block.psl
	@
# map and update match stats, which likes target sort for speed
${transMapDataDir}/transMap%.block.psl: ${transMapDataDir}/transMap%.region.idpsl ${srcGencodeDataDir}/wgEncode%.psl  ${srcGencodeDataDir}/wgEncode%.fa
	@mkdir -p $(dir $@)
	pslMap -mapFileWithInQName -mapInfo=${transMapDataDir}/transMap$*.block.mapinfo ${srcGencodeDataDir}/wgEncode$*.psl $< /dev/stdout \
	    | sort -k 14,14 -k 16,16n \
	    | pslRecalcMatch /dev/stdin ${MSCA_ASSMEBLIES_DIR}/${mapTargetOrg}.2bit ${srcGencodeDataDir}/wgEncode$*.fa $@.${tmpExt}
	mv -f $@.${tmpExt} $@

####
# chaining
#
${transMapDataDir}/%.psl: ${transMapDataDir}/%.block.psl
	@mkdir -p $(dir $@)
	simpleChain -outPsl $< stdout | bin/pslQueryUniq >$@.${tmpExt}
	mv -f $@.${tmpExt} $@

##
# gene validations
#
${transMapDataDir}/transMap%.gp: ${transMapDataDir}/transMap%.psl ${srcGencodeDataDir}/wgEncode%.cds
	@mkdir -p $(dir $@)
	mrnaToGene -keepInvalid -quiet -genePredExt -ignoreUniqSuffix -insertMergeSize=0 -cdsFile=${srcGencodeDataDir}/wgEncode$*.cds $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${transMapDataDir}/%.gene-check-details: ${transMapDataDir}/%.gene-check
	@
${transMapDataDir}/%.gene-check: ${transMapDataDir}/%.gp ${MSCA_ASSMEBLIES_DIR}/${mapTargetOrg}.2bit
	@mkdir -p ${transMapDataDir}
	sort -k2,2 -k 4,4n $< | ${geneCheck} --allow-non-coding --genome-seqs=${MSCA_ASSMEBLIES_DIR}/${mapTargetOrg}.2bit --details-out=$@-details stdin $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${transMapDataDir}/transMap%.qstats: ${transMapDataDir}/transMap%.psl ${srcGencodeDataDir}/wgEncode%.sizes
	pslStats -queryStats -queries=${srcGencodeDataDir}/wgEncode$*.sizes $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@
endif

##
# common rules
#
%.basestats: %.psl
	@mkdir -p $(dir $@)
	mrnaBasesMapped $< ${srcBasicPsl} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

%.gene-check.stats: %.gene-check
	@mkdir -p $(dir $@)
	geneCheckStats $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

%.gene-check.bed: %.gp %.gene-check
	@mkdir -p $(dir $@)
	genePredCheckToBed $*.gp $*.gene-check $@.${tmpExt}
	mv -f $@.${tmpExt} $@

%.gene-check-details.bed: %.gene-check-details
	@mkdir -p $(dir $@)
	genePredCheckDetailsToBed $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@


