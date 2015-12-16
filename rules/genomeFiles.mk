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
size = ${ASM_GENOMES_DIR}/${org}.chrom.sizes

file: ${fasta} ${twoBit} ${size}

${fasta}:
	@mkdir -p $(dir $@)
	${HAL_BIN_DIR}/hal2fasta ${halFile} ${org} > $@.${tmpExt}
	pyfasta flatten $@.${tmpExt}  # produce flat fasta for pyfasta module
	mv -f $@.${tmpExt} $@

${twoBit}: ${fasta}
	@mkdir -p $(dir $@)
	faToTwoBit $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

${size}: ${twoBit}
	@mkdir -p $(dir $@)
	twoBitInfo $< $@.${tmpExt}
	mv -f $@.${tmpExt} $@

cleanfiles:
	rm -rf ${fasta} ${twoBit} ${size}

endif