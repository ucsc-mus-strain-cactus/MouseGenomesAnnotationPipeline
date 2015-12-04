#####
# Build an Augustus hints database.
# Pass filterTissues=X and/or filterCenters=Y to filter out any BAMfiles whose path contains those strings
# I.E. filterTissues=lung heart filterCenters=unc. This assumes you have a similar directory structure to what I use
# genome/center/tissue/bamfiles
#####
include defs.mk


all: ${augustusOrgs:%=%.runOrg} finishDb

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

hintsDir = ${AUGUSTUS_WORK_DIR}/hints

fofn = ${AUGUSTUS_DIR}/rnaseq_fofn/${mapTargetOrg}

fasta = ${ASM_GENOMES_DIR}/${mapTargetOrg}.fa

# done flag dir
doneFlagDir = ${DONE_FLAG_DIR}/${mapTargetOrg}

# jobTree
jobTreeTmpDir = $(shell pwd -P)/${jobTreeRootTmpDir}/augustus_db/${mapTargetOrg}
jobTreeJobOutput = ${jobTreeTmpDir}/augustus_hints_db.out
jobTreeJobDir = ${jobTreeTmpDir}/jobTree
done = ${doneFlagDir}/hintsDb.done

runOrg: ${fofn} ${done}

${fofn}:
	@mkdir -p $(dir $@)
	find ${rnaSeqDataDir}/${mapTargetOrg} | grep bam$$ > $@

${done}:
	@mkdir -p $(dir $@)
	@mkdir -p ${jobTreeTmpDir}
	@mkdir -p ${hintsDir}
	${python} ../comparativeAnnotator/augustus/build_hints_db.py ${jobTreeOpts} \
	--genome ${mapTargetOrg} --bamFofn ${fofn} --fasta ${fasta} --database ${hintsDb} ${fc} ${ft} \
	--jobTree ${jobTreeJobDir} --hintsDir ${hintsDir} &> ${jobTreeJobOutput}
	touch $@

runOrgClean:
	rm -rf ${fofn} ${done} ${jobTreeJobDir}

else

dbDone = ${DONE_FLAG_DIR}/indexedHints.done

finishDb: ${dbDone}

${dbDone}:
	load2sqlitedb --makeIdx --dbaccess ${hintsDb}

endif