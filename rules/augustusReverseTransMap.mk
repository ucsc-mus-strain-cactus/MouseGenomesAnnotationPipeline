include defs.mk

mappedOrgs = 129S1 AJ AKRJ BALBcJ C3HHeJ C57B6NJ CASTEiJ CBAJ DBA2J FVBNJ LPJ NODShiLtJ NZOHlLtJ PWKPhJ SPRETEiJ WSBEiJ CAROLIEiJ PAHARIEiJ

AUGUSTUS_DIR = /hive/groups/recon/projs/mus_strain_cactus/pipeline_data/comparative/1504/augustus/using_transmap/aug1

augustus_table = augustusTM

refOrg = ${srcOrg}
refTwoBit = ${targetTwoBit}
refChromSizes = ${queryChromSizes}

ifneq (${mapSrcOrg},)
TRANSMAP_DATA_DIR = ${TRANS_MAP_DIR}/transMap/${mapSrcOrg}
# sequence files needed
queryFasta = ${ASM_GENOMES_DIR}/${mapSrcOrg}.fa
queryTwoBit = ${ASM_GENOMES_DIR}/${mapSrcOrg}.2bit
queryChromSizes = ${ASM_GENOMES_DIR}/${mapSrcOrg}.chrom.sizes
OUT_DIR = /cluster/home/ifiddes/mus_strain_data/pipeline_data/comparative/1504/augustus_transMap
srcOrgHgDb = Mus${mapSrcOrg}_${MSCA_VERSION}
srcGp = ${OUT_DIR}/${mapSrcOrg}.augustusTranscripts.gp
tgtFakePsl = ${OUT_DIR}/${mapSrcOrg}.augustusTranscripts.fake.psl
tgtCds = ${OUT_DIR}/${mapSrcOrg}.augustusTranscripts.cds
tgtRegionPsl = ${OUT_DIR}/${mapSrcOrg}.augustusTranscripts.region.idpsl
tgtBlockPsl = ${OUT_DIR}/${mapSrcOrg}.augustusTranscripts.block.psl
tgtPsl = ${OUT_DIR}/${mapSrcOrg}.augustusTranscripts.psl
tgtFa = ${OUT_DIR}/${mapSrcOrg}.augustusTranscripts.fa
tgtBed = ${OUT_DIR}/${mapSrcOrg}.augustusTranscripts.bed
tgtGp = ${OUT_DIR}/${mapSrcOrg}.augustusTranscripts.transMapped.gp

endif

targetFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa
targetTwoBit = ${ASM_GENOMES_DIR}/${srcOrg}.2bit
targetChromSizes = ${ASM_GENOMES_DIR}/${srcOrg}.chrom.sizes

all: srcData

srcData: ${mappedOrgs:%=%.transMap}

%.transMap:
	${MAKE} -f rules/augustusReverseTransMap.mk srcDataOrg mapSrcOrg=$*

ifneq (${mapSrcOrg},)
srcDataOrg: ${srcGp} ${tgtFa} ${tgtFakePsl} ${tgtFakeRenamedPsl} ${tgtCds} ${tgtBed} ${tgtRegionPsl} ${tgtBlockPsl} ${tgtPsl} ${tgtGp}

${srcGp}: ${AUGUSTUS_DIR}/${mapSrcOrg}.gp
	@mkdir -p $(dir $@)
	ln -s $< $@

${tgtFa}:
	@mkdir -p $(dir $@)
	getRnaPred ${srcOrgHgDb} ${augustus_table} all $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${tgtCds}: ${tgtFakePsl}
	touch $@

${tgtFakePsl}:
	@mkdir -p $(dir $@)
	genePredToFakePsl ${srcOrgHgDb} ${augustus_table} /dev/stdout ${tgtCds} > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${tgtBed}: ${srcGp}
	@mkdir -p $(dir $@)
	genePredToBed $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${tgtRegionPsl}: ${tgtBed}
	@mkdir -p $(dir $@)
	${HAL_BIN_DIR}/halLiftover --tab --outPSLWithName ${halFile} ${mapSrcOrg} ${tgtBed} ${refOrg} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${tgtBlockPsl}: ${tgtRegionPsl} ${tgtFakePsl}
	@mkdir -p $(dir $@)
	pslMap -mapFileWithInQName ${tgtFakePsl} $< /dev/stdout | sort -k 14,14 -k 16,16n | pslRecalcMatch /dev/stdin \
	${refTwoBit} ${tgtFa} $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${tgtPsl}: ${tgtBlockPsl}
	@mkdir -p $(dir $@)
	simpleChain -outPsl $< stdout | bin/pslQueryUniq >$@.${tmpExt}
	mv -f $@.${tmpExt} $@

${tgtGp}: ${tgtPsl} ${tgtCds}
	@mkdir -p $(dir $@)
	mrnaToGene -keepInvalid -quiet -genePredExt -ignoreUniqSuffix -insertMergeSize=0 -cdsFile=${tgtCds} $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

endif
