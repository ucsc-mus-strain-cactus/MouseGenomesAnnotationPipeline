include defs.mk

###
# transMap two-level recursive target for each method then each organism.
###
all: transMapChainingMethod

transMapChainingMethod: ${transMapChainingMethods:%=%.transMapChainingMethod}
%.transMapChainingMethod:
	${MAKE} -f rules/transMap.mk transMapOrg transMapChainingMethod=$*

transMapOrg: ${mappedOrgs:%=%.transMapOrg}
%.transMapOrg:
	${MAKE} -f rules/transMap.mk transMap transMapChainingMethod=${transMapChainingMethod} mapTargetOrg=$*


ifneq (${mapTargetOrg},)
###
# These are only defined when mapTargetOrg is defined by recursive make: 
#    mapTargetOrg - specifies the target organism
#    transMapChainingMethod - one of simpleChain, all, syn
###
transMapDataDir = $(call transMapDataDirFunc,${mapTargetOrg},${transMapChainingMethod})

# sequence files needed
targetFasta = ${ASM_GENOMES_DIR}/${mapTargetOrg}.fa
targetTwoBit = ${ASM_GENOMES_DIR}/${mapTargetOrg}.2bit
targetChromSizes = ${ASM_GENOMES_DIR}/${mapTargetOrg}.chrom.sizes

# chained (final results)
transMapPsl = ${transMapGencodeSubsets:%=${transMapDataDir}/%.psl}

# final transMap predicted transcript annotations
transMapGp = ${transMapGencodeSubsets:%=${transMapDataDir}/%.gp}

transMap: ${transMapPsl} ${transMapGp}

###
# genomic chain mapping
###

ifneq ($(findstring ${transMapChainingMethod},all syn),)
mappingChains = $(call chainFunc,${transMapChainingMethod},${srcOrg},${mapTargetOrg})

# map and update match stats, which likes target sort for speed
${transMapDataDir}/transMap%.psl: ${SRC_GENCODE_DATA_DIR}/wgEncode%.psl ${SRC_GENCODE_DATA_DIR}/wgEncode%.fa ${mappingChains} ${targetTwoBit}
	@mkdir -p $(dir $@)
	pslMap -mapInfo=${transMapDataDir}/transMap$*.mapinfo -chainMapFile ${SRC_GENCODE_DATA_DIR}/wgEncode$*.psl ${mappingChains} /dev/stdout \
		| bin/postTransMapChain /dev/stdin /dev/stdout \
		| sort -k 14,14 -k 16,16n \
		| pslRecalcMatch /dev/stdin ${targetTwoBit} ${SRC_GENCODE_DATA_DIR}/wgEncode$*.fa stdout \
		| bin/pslQueryUniq >$@.${tmpExt}
	mv -f $@.${tmpExt} $@
endif

###
# simple chain mapping
# @FIXME: delete if we drop it
###
ifeq (${transMapChainingMethod},simpleChain)
# block transMap
transMapMappedRegionIdAllPsl = ${transMapGencodeSubsets:%=${transMapDataDir}/%.region.idpsl}
transMapMappedBlockAllPsl = ${transMapGencodeSubsets:%=${transMapDataDir}/%.block.psl}
transMapMappedBlockAllMapInfo = ${transMapGencodeSubsets:%=${transMapDataDir}/%.block.mapinfo}

${transMapDataDir}/transMap%.region.idpsl: ${SRC_GENCODE_DATA_DIR}/wgEncode%.bed
	@mkdir -p $(dir $@)
	${HAL_BIN_DIR}/halLiftover --tab --outPSLWithName ${halFile} ${srcOrg} $< ${mapTargetOrg} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${transMapDataDir}/transMap%.block.mapinfo: ${transMapDataDir}/transMap%.block.psl

# map and update match stats, which likes target sort for speed
${transMapDataDir}/transMap%.block.psl: ${transMapDataDir}/transMap%.region.idpsl ${SRC_GENCODE_DATA_DIR}/wgEncode%.psl  ${SRC_GENCODE_DATA_DIR}/wgEncode%.fa  ${targetTwoBit}
	@mkdir -p $(dir $@)
	pslMap -mapFileWithInQName -mapInfo=${transMapDataDir}/transMap$*.block.mapinfo ${SRC_GENCODE_DATA_DIR}/wgEncode$*.psl $< /dev/stdout \
		| sort -k 14,14 -k 16,16n \
		| pslRecalcMatch /dev/stdin ${targetTwoBit} ${SRC_GENCODE_DATA_DIR}/wgEncode$*.fa $@.${tmpExt}
	mv -f $@.${tmpExt} $@

###
# chaining
###
${transMapDataDir}/%.psl: ${transMapDataDir}/%.block.psl
	@mkdir -p $(dir $@)
	simpleChain -outPsl $< stdout | bin/pslQueryUniq >$@.${tmpExt}
	mv -f $@.${tmpExt} $@
endif


###
# final transMap genes
###
${transMapDataDir}/transMap%.gp: ${transMapDataDir}/transMap%.psl ${SRC_GENCODE_DATA_DIR}/wgEncode%.cds
	@mkdir -p $(dir $@)
	mrnaToGene -keepInvalid -quiet -genePredExt -ignoreUniqSuffix -insertMergeSize=0 -cdsFile=${SRC_GENCODE_DATA_DIR}/wgEncode$*.cds $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@
endif
