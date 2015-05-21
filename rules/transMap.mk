include defs.mk

###
# mappings
# These are only defined when mapTargetOrg is defined by recursive make: mapTargetOrg= specifies the target organism
###
ifneq (${mapTargetOrg},)
TRANSMAP_DATA_DIR = ${TRANS_MAP_DIR}/transMap/${mapTargetOrg}

# sequence files needed
targetFasta = ${ASM_GENOMES_DIR}/${mapTargetOrg}.fa
targetTwoBit = ${ASM_GENOMES_DIR}/${mapTargetOrg}.2bit
targetChromSizes = ${ASM_GENOMES_DIR}/${mapTargetOrg}.chrom.sizes

# block transMap
transMapMappedRegionIdAllPsl = ${transMapGencodeSubsets:%=${TRANSMAP_DATA_DIR}/%.region.idpsl}
transMapMappedBlockAllPsl = ${transMapGencodeSubsets:%=${TRANSMAP_DATA_DIR}/%.block.psl}
transMapMappedBlockAllMapInfo = ${transMapGencodeSubsets:%=${TRANSMAP_DATA_DIR}/%.block.mapinfo}

# chained (final results)
transMapChainedAllPsls = ${transMapGencodeSubsets:%=${TRANSMAP_DATA_DIR}/%.psl}

# final transMap predicted transcript annotations
transMapEvalAllGp = ${transMapGencodeSubsets:%=${TRANSMAP_DATA_DIR}/%.gp}
endif

all: srcData transMap

###
# src genes
###
srcData: ${srcAttrsTsv} ${srcGencodeAllGp} ${srcGencodeAllBed} ${srcGencodeAllFa} ${srcGencodeAllPsl} ${srcGencodeAllCds} ${queryFasta} ${queryTwoBit} ${queryChromSizes}

# awk expression to edit chrom names in UCSC format.  Assumse all alts are version 1.
# chr1_GL456211_random, chrUn_GL456239
# FIXME: this is also build_browser/bin/ucscToEnsemblChrom
editUcscChrom = $$chromCol=="chrM"{$$chromCol="MT"} {$$chromCol = gensub("_random$$","", "g", $$chromCol);$$chromCol = gensub("^chr.*_([0-9A-Za-z]+)$$","\\1.1", "g", $$chromCol);  gsub("^chr","",$$chromCol); print $$0}

${srcAttrsTsv}:
	@mkdir -p $(dir $@)
	hgsql -e 'select geneId,geneName,geneType,transcriptId,transcriptType from ${srcGencodeAttrs}' ${srcOrgHgDb} > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${SRC_GENCODE_DATA_DIR}/%.gp:
	@mkdir -p $(dir $@)
	hgsql -Ne 'select * from $*' ${srcOrgHgDb} | cut -f 2- | tawk -v chromCol=2 '${editUcscChrom}' > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${srcGencodeDataDir}/%.bed: ${srcGencodeDataDir}/%.gp
	@mkdir -p $(dir $@)
	genePredToBed $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${SRC_GENCODE_DATA_DIR}/%.fa:
	@mkdir -p $(dir $@)
	getRnaPred ${srcOrgHgDb} $* all $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${SRC_GENCODE_DATA_DIR}/%.cds: ${SRC_GENCODE_DATA_DIR}/%.psl
	@

${SRC_GENCODE_DATA_DIR}/%.psl:
	@mkdir -p $(dir $@)
	genePredToFakePsl ${srcOrgHgDb} $* stdout ${SRC_GENCODE_DATA_DIR}/$*.cds | tawk -v chromCol=14 '${editUcscChrom}' >$@.${tmpExt}
	mv -f $@.${tmpExt} $@

${queryFasta}:
	@mkdir -p $(dir $@)
	n="$(shell basename $@ | cut -d "." -f 1)" ;\
	${HAL_BIN_DIR}/hal2fasta ${halFile} $$n > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${queryTwoBit}: ${queryFasta}
	@mkdir -p $(dir $@)
	faToTwoBit ${queryFasta} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${queryChromSizes}: ${queryTwoBit}
	@mkdir -p $(dir $@)
	twoBitInfo ${queryTwoBit} stdout | sort -k2rn > $@.${tmpExt}
	mv -f $@.${tmpExt} $@


###
# transMap recursive target for each organism
###
transMap: ${mappedOrgs:%=%.transMap}

%.transMap:
	${MAKE} -f rules/transMap.mk transMapOrg mapTargetOrg=$*


ifneq (${mapTargetOrg},)
transMapOrg: ${targetFasta} ${targetTwoBit} ${targetChromSizes} ${transMapMappedRegionIdAllPsl} ${transMapMappedBlockAllPsl} ${transMapChainedAllPsls} ${transMapEvalAllGp}

###
# extracting sequences for this mappedOrg from HAL
###
${targetFasta}:
	@mkdir -p $(dir $@)
	n="$(shell basename $@ | cut -d "." -f 1)" ;\
	${HAL_BIN_DIR}/hal2fasta ${halFile} $$n > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${targetTwoBit}: ${targetFasta}
	@mkdir -p $(dir $@)
	faToTwoBit $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${targetChromSizes}: ${targetTwoBit}
	@mkdir -p $(dir $@)
	n="$(shell basename $@ | cut -d "." -f 1)" ;\
	${HAL_BIN_DIR}/halStats --chromSizes $$n ${halFile} > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

###
# mapping
###
${TRANSMAP_DATA_DIR}/transMap%.region.idpsl: ${SRC_GENCODE_DATA_DIR}/wgEncode%.bed
	@mkdir -p $(dir $@)
	${HAL_BIN_DIR}/halLiftover --tab --outPSLWithName ${halFile} ${srcOrg} $< ${mapTargetOrg} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${TRANSMAP_DATA_DIR}/transMap%.block.mapinfo: ${TRANSMAP_DATA_DIR}/transMap%.block.psl

# map and update match stats, which likes target sort for speed
${TRANSMAP_DATA_DIR}/transMap%.block.psl: ${TRANSMAP_DATA_DIR}/transMap%.region.idpsl ${SRC_GENCODE_DATA_DIR}/wgEncode%.psl  ${SRC_GENCODE_DATA_DIR}/wgEncode%.fa
	@mkdir -p $(dir $@)
	pslMap -mapFileWithInQName -mapInfo=${TRANSMAP_DATA_DIR}/transMap$*.block.mapinfo ${SRC_GENCODE_DATA_DIR}/wgEncode$*.psl $< /dev/stdout \
	    | sort -k 14,14 -k 16,16n \
	    | pslRecalcMatch /dev/stdin ${targetTwoBit} ${SRC_GENCODE_DATA_DIR}/wgEncode$*.fa $@.${tmpExt}
	mv -f $@.${tmpExt} $@

###
# chaining
###
${TRANSMAP_DATA_DIR}/%.psl: ${TRANSMAP_DATA_DIR}/%.block.psl
	@mkdir -p $(dir $@)
	simpleChain -outPsl $< stdout | bin/pslQueryUniq >$@.${tmpExt}
	mv -f $@.${tmpExt} $@

###
# final transMap genes
###
${TRANSMAP_DATA_DIR}/transMap%.gp: ${TRANSMAP_DATA_DIR}/transMap%.psl ${SRC_GENCODE_DATA_DIR}/wgEncode%.cds
	@mkdir -p $(dir $@)
	mrnaToGene -keepInvalid -quiet -genePredExt -ignoreUniqSuffix -insertMergeSize=0 -cdsFile=${SRC_GENCODE_DATA_DIR}/wgEncode$*.cds $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

endif
