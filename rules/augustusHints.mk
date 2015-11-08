#####
# Build an Augustus hints database. Expects a base folder to find bamfiles in.
# which you pass as FOLDER=
# TODO: make this work pan-genome. right now it is required you also pass mapTargetOrg=
#####
include defs.mk


all: ${augustusOrgs:%=%.runOrg}

clean: ${augustusOrgs:%=%.runOrgClean}

%.runOrg:
	${MAKE} -f rules/augustusHints.mk runOrg mapTargetOrg=$*

%.runOrgClean:
	${MAKE} -f rules/augustusHints.mk runOrgClean mapTargetOrg=$*


ifneq (${mapTargetOrg},)

ifneq (${filterTissues},)
ft = --filterTissues ${filterTissues}
endif

ifneq (${filterCenters},)
fc = --filterCenters ${filterCenters}
endif

 # TODO: make this the actual hints file in defs.mk
db = ${AUGUSTUS_DIR}/hints_ian_build.db 
fofn = ${AUGUSTUS_DIR}/rnaseq_fofn/${mapTargetOrg}

fasta = ${ASM_GENOMES_DIR}/${mapTargetOrg}.fa

# done flag dir
doneFlagDir = ${DONE_FLAG_DIR}/${mapTargetOrg}

# jobTree
jobTreeTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/augustus_db/${mapTargetOrg}
jobTreeJobOutput = ${jobTreeTmpDir}/augustus_hints_db.out
jobTreeJobDir = ${jobTreeTmpDir}/jobTree
done = ${doneFlagDir}/hints_db.done

runOrg: ${fofn} ${done}

${fofn}:
	@mkdir -p $(dir $@)
	find ${rnaSeqDataDir} | grep bam$$ > $@

${done}:
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeTmpDir}
	cd ../comparativeAnnotator && ${python} augustus/build_hints_db.py ${jobTreeOpts} \
	--genome ${mapTargetOrg} --bamFofn ${fofn} --fasta ${fasta} --database ${db} ${fc} ${ft} \
	--jobTree ${jobTreeJobDir} --batchSystem singleMachine --maxThreads 60 &> ${jobTreeJobOutput}
	touch $@

runOrgClean:
	rm -rf ${fofn} ${done} ${jobTreeJobDir}

endif