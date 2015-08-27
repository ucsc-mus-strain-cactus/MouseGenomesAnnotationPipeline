##
# generate UCSC chains and nets from HAL files
# recusively calls self with
#   queryOrg targetOrg
##
include defs.mk

all: ${mappedOrgs:%=%.dochain}

%.dochain:
	${MAKE} -f rules/chaining.mk chain queryOrg=${srcOrg} targetOrg=$*

# recurisve call:
ifneq (${queryOrg},)
jobTreeChainTmpDir = ${jobTreeRootTmpDir}/chaining/${queryOrg}_${targetOrg}
jobTreeJobOutput = ${jobTreeChainTmpDir}/chaining.out
jobTreeJobDir = ${jobTreeChainTmpDir}/jobTree
# maybe bigger than needed when -inMemory is removed
#defaultMemory = 33285996544
defaultMemory = 16106127360
jobTreeOpts = --defaultMemory=${defaultMemory} --stats --batchSystem=parasol --parasolCommand=bin/remparasol --jobTree=${jobTreeJobDir}

queryTwoBit = ${ASM_GENOMES_DIR}/${queryOrg}.2bit
targetTwoBit = ${ASM_GENOMES_DIR}/${targetOrg}.2bit

chainAll = $(call chainAllFunc,${queryOrg},${targetOrg})
netAll = $(call netAllFunc,${queryOrg},${targetOrg})
chainSyn = $(call chainSynFunc,${queryOrg},${targetOrg})
netSyn = $(call netSynFunc,${queryOrg},${targetOrg})

# chainSyn is used as a flag because it's defined to be the last one created.
# Can't mix shell atomic file create with jobTree restarts, as the output file
# name changes.

chain:  ${chainSyn}
${chainSyn}: ${halFile} ${queryTwoBit} ${targetTwoBit}
	@mkdir -p $(dir ${chainAll}) ${jobTreeChainTmpDir}
	 ./bin/ucscChainNet ${jobTreeOpts} ${halFile} ${queryOrg} ${queryTwoBit} ${targetOrg} ${targetTwoBit} \
	        ${chainAll} ${netAll} ${chainSyn} ${netSyn} >${jobTreeJobOutput} 2>&1

endif
