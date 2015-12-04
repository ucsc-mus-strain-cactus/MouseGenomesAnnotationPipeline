##
# generate UCSC chains and nets from HAL files
# recusively calls self with
#   queryOrg targetOrg
##
include defs.mk

all: ${mappedOrgs:%=%.dochain}

clean: ${mappedOrgs:%=%.doclean}

%.dochain:
	${MAKE} -f rules/chaining.mk chain queryOrg=${srcOrg} targetOrg=$*

%.doclean:
	${MAKE} -f rules/chaining.mk chainClean queryOrg=${srcOrg} targetOrg=$*

# recursive call:
ifneq (${queryOrg},)
jobTreeChainTmpDir = ${jobTreeRootTmpDir}/chaining/${queryOrg}_${targetOrg}
jobTreeJobOutput = ${jobTreeChainTmpDir}/chaining.out
jobTreeJobDir = ${jobTreeChainTmpDir}/jobTree

jobTreeChainingOpts = ${jobTreeOpts} --jobTree=${jobTreeJobDir} --defaultMemory 17179869184

queryTwoBit = ${ASM_GENOMES_DIR}/${queryOrg}.2bit
targetTwoBit = ${ASM_GENOMES_DIR}/${targetOrg}.2bit

# call functions to obtain path to chain/net files, given srcOrg,targetOrg.
chainAllFunc = $(call chainFunc,all,${1},${2})
netAllFunc = $(call netFunc,all,${1},${2})

chainAll = ${CHAINING_DIR}/${queryOrg}-${targetOrg}.all.chain.gz
netAll = ${CHAINING_DIR}/${queryOrg}-${targetOrg}.all.net.gz

chain:  ${chainAll}
${chainAll}: ${halFile} ${queryTwoBit} ${targetTwoBit}
	@mkdir -p $(dir ${chainAll}) ${jobTreeChainTmpDir}
	 ./bin/ucscChainNet ${jobTreeChainingOpts} ${halFile} ${queryOrg} ${queryTwoBit} ${targetOrg} \
	        ${targetTwoBit} ${chainAll} ${netAll} > ${jobTreeJobOutput} 2>&1

chainClean:
	rm -rf ${chainAll} ${netAll}

endif
