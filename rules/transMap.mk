###
# configuration  FIXME: move to common file
###
MSCA_VERSION = 1411
#MSCA_VERSION = 1412
MSCA_PROJ_DIR = /hive/groups/recon/projs/mus_strain_cactus
MSCA_DATA_DIR = ${MSCA_PROJ_DIR}/pipeline_data
HAL_BIN = ${MSCA_PROJ_DIR}/src/progressiveCactus/submodules/hal/bin
PYCBIO_DIR = ${MSCA_PROJ_DIR}/src/pycbio
GENCODE_VERSION = VM2
TRANS_MAP_VERSION = 2015-02-22
TRANS_MAP_DIR = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/transMap/${TRANS_MAP_VERSION}

# programs
# FIXME: integrate geneCheck changes to Ian's tree
geneCheck = ~markd/compbio/genefinding/GeneTools/bin/x86_64/opt/gene-check
halLiftover = ${HAL_BIN}/halLiftover


halFile = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/cactus/${MSCA_VERSION}.hal
ASM_GENOMES_DIR = ${MSCA_DATA_DIR}/assemblies/${MSCA_VERSION}/genome
srcGencodeSet = wgEncodeGencodeBasic${GENCODE_VERSION}
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


# make config stuff
host=$(shell hostname)
ppid=$(shell echo $$PPID)
tmpExt = ${host}.${ppid}.tmp

.SECONDARY:
SHELL = /bin/bash -e
export SHELLOPTS=pipefail
export PATH:=${PATH}:${PYCBIO_DIR}/bin:./bin
ifneq ($(wildcard ${HOME}/.hg.rem.conf),)
    # if this exists, it allows running on kolossus because of remote access to UCSC databases
    export HGDB_CONF=${HOME}/.hg.rem.conf
endif



# gencode src files
srcDataDir = ${TRANS_MAP_DIR}/data
genomeDir = ${srcDataDir}/genomes
srcBasicPre = ${srcDataDir}/${srcGencodeSet}
srcBasicGp =  ${srcBasicPre}.gp
srcBasicFa =  ${srcBasicPre}.fa
srcBasicBed = ${srcBasicPre}.bed
srcBasicPsl = ${srcBasicPre}.psl
srcBasicSizes = ${srcBasicPre}.sizes
srcBasicCds = ${srcBasicPre}.cds
srcBasicCheck = ${srcBasicPre}.gene-check
srcBasicCheckDetails = ${srcBasicPre}.gene-check-details
srcBasicStats = ${srcBasicPre}.gene-check.stats
srcBasicCheckBed = ${srcBasicPre}.gene-check.bed
srcBasicCheckDetailsBed = ${srcBasicPre}.gene-check-details.bed

# mappings
mappedDataDir = ${TRANS_MAP_DIR}/mapped
mappedRegionIdPsls = ${mappedOrgs:%=${mappedDataDir}/%.region.idpsl}
mappedBlockPsls = ${mappedOrgs:%=${mappedDataDir}/%.block.psl}


# chained
chainedDataDir = ${TRANS_MAP_DIR}/results/chained
chainedPsls = ${mappedOrgs:%=${chainedDataDir}/%.chained.psl}
chainedQstats = ${mappedOrgs:%=${chainedDataDir}/%.chained.qstats}

# filtered
filteredDataDir = ${TRANS_MAP_DIR}/results/filtered
filteredPsls = ${mappedOrgs:%=${filteredDataDir}/%.filtered.psl}
filteredQstats = ${mappedOrgs:%=${filteredDataDir}/%.filtered.qstats}

# mapped genes
# FIXME: these names are confusing.
geneCheckDataDir = ${TRANS_MAP_DIR}/results/geneCheck
geneCheckGps = ${mappedOrgs:%=${geneCheckDataDir}/%.gp}
geneCheckEvals = ${mappedOrgs:%=${geneCheckDataDir}/%.gene-check}
geneCheckEvalsDetails = ${mappedOrgs:%=${geneCheckDataDir}/%.gene-check-details}
geneCheckEvalStats = ${mappedOrgs:%=${geneCheckDataDir}/%.gene-check.stats}
geneCheckEvalsBed = ${mappedOrgs:%=${geneCheckDataDir}/%.gene-check.bed}
geneCheckEvalsDetailsBed = ${mappedOrgs:%=${geneCheckDataDir}/%.gene-check-details.bed}

all: srcData mapping chaining filtered geneValidate

###
# src genes
###
srcData: ${srcBasicGp} ${srcBasicFa} ${srcBasicPsl} ${srcBasicCds} ${srcBasicSizes} ${srcBasicCheck} ${srcBasicStats} ${srcBasicCheckBed} ${srcBasicCheckDetailsBed}

# awk expression to edit chrom names in UCSC format.  Assumse all alts are version 1.
# chr1_GL456211_random, chrUn_GL456239
editUcscChrom = $$chromCol=="chrM"{$$chromCol="MT"} {$$chromCol = gensub("_random$$","", "g", $$chromCol);$$chromCol = gensub("^chr.*_([0-9A-Za-z]+)$$","\\1.1", "g", $$chromCol);  gsub("^chr","",$$chromCol); print $$0}
${srcBasicGp}:
	@mkdir -p $(dir $@)
	hgsql -Ne 'select * from ${srcGencodeSet}' ${srcHgDb} | cut -f 2- | tawk -v chromCol=2 '${editUcscChrom}' >$@.${tmpExt}
	mv -f $@.${tmpExt} $@

${srcBasicFa}:
	@mkdir -p $(dir $@)
	getRnaPred ${srcHgDb} ${srcGencodeSet} all $@.${tmpExt}
	mv -f $@.${tmpExt} $@

%.bed: %.gp
	@mkdir -p $(dir $@)
	genePredToBed $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${srcBasicCds}: ${srcBasicPsl}
${srcBasicPsl}: ${srcBasicGp}
	@mkdir -p $(dir $@)
	genePredToFakePsl ${srcHgDb} ${srcGencodeSet} stdout ${srcBasicCds} | tawk -v chromCol=14 '${editUcscChrom}' >$@.${tmpExt}
	mv -f $@.${tmpExt} $@

${srcBasicSizes}: ${srcBasicPsl}
	tawk '{print $$10,$$11}' $< >$@.${tmpExt}
	mv -f $@.${tmpExt} $@

${srcBasicCheckDetails}: ${srcBasicCheck}
${srcBasicCheck}: ${srcBasicGp} ${genomeDir}/${srcOrg}.2bit ${genomeDir}/${srcOrg}.sizes
	@mkdir -p $(dir $@)
	sort -k2,2 -k 4,4n $< | ${geneCheck} --allow-non-coding --genome-seqs=${genomeDir}/${srcOrg}.2bit --details-out=$@-details stdin $@.${tmpExt}
	mv -f $@.${tmpExt} $@

####
# mapping
#
mapping: ${mappedRegionIdPsls} ${mappedBlockPsl} ${mappedBlockBaseStats} ${mappedBlockBaseStatsHistos}
${mappedDataDir}/%.region.idpsl: ${srcBasicBed}
	@mkdir -p $(dir $@)
	${halLiftover} --tab --outPSLWithName ${halFile} ${srcOrg} ${srcBasicBed} $*  $@.${tmpExt}
	mv -f $@.${tmpExt} $@

# map and update match stats, which likes target sort for speed
${mappedDataDir}/%.block.psl: ${mappedDataDir}/%.region.idpsl
	@mkdir -p $(dir $@)
	pslMap -mapFileWithInQName ${srcBasicPsl} $<  /dev/stdout | sort -k 14,14 -k 16,16n | pslRecalcMatch /dev/stdin ${genomeDir}/$*.2bit ${srcBasicFa} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

####
# chaining
#
chaining: ${chainedPsls} ${chainedQstats} ${chainedQstatsHistos} ${chainedBaseStats} ${chainedBaseStatsHistos}

${chainedDataDir}/%.chained.psl: ${mappedDataDir}/%.block.psl
	@mkdir -p $(dir $@)
	simpleChain -outPsl $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

###
# filtereding filtering
#
filtered: ${filteredPsls} ${filteredQstats} ${filteredQstatsHistos} ${filteredBaseStats} ${filteredBaseStatsHistos}

filterOpts=-localNearBest=0.0001

${filteredDataDir}/%.filtered.psl: ${chainedDataDir}/%.chained.psl
	@mkdir -p $(dir $@)
	(pslCDnaFilter ${filterOpts} $< stdout | pslQueryUniq >$@.${tmpExt}) 2> $(basename $@).filterinfo
	mv -f $@.${tmpExt} $@


##
# common rules
#
%.basestats: %.psl
	@mkdir -p $(dir $@)
	mrnaBasesMapped $< ${srcBasicPsl} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

%.qstats: %.psl ${srcBasicSizes}
	pslStats -queryStats -queries=${srcBasicSizes} $< $@.${tmpExt}
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


##
# gene validations
#
geneValidate: ${geneCheckGps} ${geneCheckEvals} ${geneCheckEvalStats} ${geneCheckEvalsBed} ${geneCheckEvalsDetailsBed}

${geneCheckDataDir}/%.gp: ${filteredDataDir}/%.filtered.psl  ${srcBasicCds}
	@mkdir -p $(dir $@)
	mrnaToGene -keepInvalid -quiet -genePredExt -ignoreUniqSuffix -insertMergeSize=0 -cdsFile=${srcBasicCds} $< stdout | tawk '$$6<$$7' >$@.${tmpExt}
	mv -f $@.${tmpExt} $@

# pattern rules only execute once for mutiple targets
${geneCheckDataDir}/%.gene-check ${geneCheckDataDir}/%.gene-check-details: ${geneCheckDataDir}/%.gp ${genomeDir}/%.2bit
	@mkdir -p ${geneCheckDataDir}
	sort -k2,2 -k 4,4n $< | ${geneCheck} --allow-non-coding --genome-seqs=${genomeDir}/$*.2bit --details-out=${geneCheckDataDir}/$*.gene-check-details stdin ${geneCheckDataDir}/$*.gene-check.${tmpExt}
	mv -f ${geneCheckDataDir}/$*.gene-check.${tmpExt} ${geneCheckDataDir}/$*.gene-check


####
## rules to build 2bit from genome sequences:
# FIXME: hacked to del with naming differences
###
###
# genome 2bit from fasta
${genomeDir}/%.2bit: #${halDir}/%.fa
	@mkdir -p $(dir $@)
	faToTwoBit ${ASM_GENOMES_DIR}/${genomeMap_$*}.fa.masked $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${genomeDir}/%.sizes: #${halDir}/%.fa
	@mkdir -p $(dir $@)
	faSize -detailed ${ASM_GENOMES_DIR}/${genomeMap_$*}.fa.masked >$@.${tmpExt}
	mv -f $@.${tmpExt} $@

