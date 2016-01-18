include defs.mk

all: ${allOrgs:%=%.getfiles}

clean: ${allOrgs:%=%.cleanfiles}

%.getfiles:
	${MAKE} -f rules/genomeFiles.mk file org=$*

%.cleanfiles:
	${MAKE} -f rules/genomeFiles.mk cleanfiles org=$*

ifneq (${org},)

fasta = ${ASM_GENOMES_DIR}/${org}.fa
twoBit = ${ASM_GENOMES_DIR}/${org}.2bit
flatFasta = ${ASM_GENOMES_DIR}/${org}.fa.flat
size = ${ASM_GENOMES_DIR}/${org}.chrom.sizes

file: ${fasta} ${twoBit} ${flatFasta} ${size}

${fasta}: ${halFile}
	@mkdir -p $(dir $@)
	${HAL_BIN_DIR}/hal2fasta ${halFile} ${org} > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${twoBit}: ${fasta}
	@mkdir -p $(dir $@)
	faToTwoBit $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${flatFasta}: ${fasta} ${twoBit}
	pyfasta flatten $<
	# need to make the timestamps correct now
	touch ${twoBit}
	touch $@

${size}:
	@mkdir -p $(dir $@)
	${HAL_BIN_DIR}/halStats --chromSizes ${org} ${halFile} > $@.${tmpExt}
	mv -f $@.${tmpExt} $@

cleanfiles:
	rm -rf ${fasta}* ${twoBit} ${size}

endif