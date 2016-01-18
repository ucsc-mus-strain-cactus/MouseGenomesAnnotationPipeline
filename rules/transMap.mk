include defs.mk

all: ${mappedOrgs:%=%.transMapOrg}

clean: ${mappedOrgs:%=%.transMapOrgClean}

%.transMapOrg:
	${MAKE} -f rules/transMap.mk transMap mapTargetOrg=$*

%.transMapOrgClean:
	${MAKE} -f rules/transMap.mk transMapClean mapTargetOrg=$*


ifneq (${mapTargetOrg},)
###
# These are only defined when mapTargetOrg is defined by recursive make: 
#    mapTargetOrg - specifies the target organism
###
transMapDataDir = ${TRANS_MAP_DIR}/transMap/${mapTargetOrg}

# sequence files needed
targetFasta = ${ASM_GENOMES_DIR}/${mapTargetOrg}.fa
targetTwoBit = ${ASM_GENOMES_DIR}/${mapTargetOrg}.2bit
targetChromSizes = ${ASM_GENOMES_DIR}/${mapTargetOrg}.chrom.sizes

# chained (final results)
transMapPsl = ${transMapGencodeSubsets:%=${transMapDataDir}/%.psl}

# final transMap predicted transcript annotations
transMapGp = ${transMapGencodeSubsets:%=${transMapDataDir}/%.gp}

# chain files
mappingChains = ${CHAINING_DIR}/${srcOrg}-${mapTargetOrg}.chain.gz


transMap: ${transMapPsl} ${transMapGp}

transMapClean: 
	rm -rf ${transMapDataDir}/transMap*.psl ${transMapDataDir}/transMap*.gp


###
# genomic chain mapping
###

# map and update match stats, which likes target sort for speed
${transMapDataDir}/transMap%.psl: | ${SRC_GENCODE_DATA_DIR}/wgEncode%.psl ${SRC_GENCODE_DATA_DIR}/wgEncode%.fa ${mappingChains} ${targetTwoBit}
	@mkdir -p $(dir $@)
	pslMap -mapInfo=${transMapDataDir}/transMap$*.mapinfo -chainMapFile ${SRC_GENCODE_DATA_DIR}/wgEncode$*.psl ${mappingChains} /dev/stdout \
		| bin/postTransMapChain /dev/stdin /dev/stdout \
		| sort -k 14,14 -k 16,16n \
		| pslRecalcMatch /dev/stdin ${targetTwoBit} ${SRC_GENCODE_DATA_DIR}/wgEncode$*.fa stdout \
		| bin/pslQueryUniq >$@.${tmpExt}
	mv -f $@.${tmpExt} $@

###
# final transMap genes
###
${transMapDataDir}/transMap%.gp: | ${transMapDataDir}/transMap%.psl ${SRC_GENCODE_DATA_DIR}/wgEncode%.cds
	@mkdir -p $(dir $@)
	mrnaToGene -keepInvalid -quiet -genePredExt -ignoreUniqSuffix -insertMergeSize=0 -cdsFile=${SRC_GENCODE_DATA_DIR}/wgEncode$*.cds $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

endif
