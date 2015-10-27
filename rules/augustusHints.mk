#####
# Build an Augustus hints database. Expects a base folder to find bamfiles in.
# which you pass as FOLDER=
# TODO: make this work pan-genome. right now it is required you also pass GENOME=
#####
include defs.mk

ifeq (${FOLDER},)
	 $(error FOLDER environment variable not set)
endif

ifeq (${GENOME},)
	 $(error GENOME environment variable not set)
endif


db = ${AUGUSTUS_DIR}/hints.db
fofn = ${AUGUSTUS_DIR}/rnaseq_files

fasta = ${ASM_GENOMES_DIR}/${GENOME}.fa

# jobTree
jobTreeTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/augustus_db
jobTreeJobOutput = ${jobTreeTmpDir}/augustus_hints_db.out
jobTreeJobDir = ${jobTreeTmpDir}/jobTree
done = ${doneFlagDir}/hints_db.done

all: ${fofn} ${db}

clean:
	rm -rf ${fofn} ${db} ${jobTreeJobDir}

${fofn}:
	@mkdir -p $(dir $@)
	find ${FOLDER} | grep bam$$ > $@

${db}:
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeTmpDir}
	cd ../comparativeAnnotator && ${python} augustus/build_hints_db.py ${jobTreeOpts} \
	--genome ${GENOME} --bamFofn ${fofn} --fasta ${fasta} --database ${db} \
	--jobTree ${jobTreeJobDir} &> ${jobTreeJobOutput}