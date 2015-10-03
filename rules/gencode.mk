####
# obtain gencode data for the reference mouse
####
include defs.mk

###
# src genes
###
all: ${srcGencodeAttrsTsv} ${srcGencodeAllGp} ${srcGencodeAllBed} ${srcGencodeAllFa} ${srcGencodeAllFaidx} ${srcGencodeAllPsl} ${srcGencodeAllCds} ${queryFasta} ${queryTwoBit} ${queryChromSizes}

# awk expression to edit chrom names in UCSC format.  Assumse all alts are version 1.
# chr1_GL456211_random, chrUn_GL456239
# FIXME: this is also build_browser/bin/ucscToEnsemblChrom
# FIXME: this can be build using assembly summary tables
editUcscChrom = $$chromCol=="chrM"{$$chromCol="MT"} {$$chromCol = gensub("_random$$","", "g", $$chromCol);$$chromCol = gensub("^chr.*_([0-9A-Za-z]+)$$","\\1.1", "g", $$chromCol);  gsub("^chr","",$$chromCol); print $$0}

${srcGencodeAttrsTsv}:
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
	getRnaPred ${srcOrgHgDb} $* all stdout | faFilter -uniq stdin $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${SRC_GENCODE_DATA_DIR}/%.fa.fai: ${SRC_GENCODE_DATA_DIR}/%.fa
	@mkdir -p $(dir $@)
	samtools faidx $<

# sillyness to make multiple productions work in make.
# touch ensures that CDS is newer than psl
${SRC_GENCODE_DATA_DIR}/%.cds: ${SRC_GENCODE_DATA_DIR}/%.psl
	touch $@
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


