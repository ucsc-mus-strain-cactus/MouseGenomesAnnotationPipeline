#include ../pipeline_msca/config.mk
include ../pipeline/config.mk

# base directory definitions
PROJ_DIR = /hive/groups/recon/projs/mus_strain_cactus
DATA_DIR = ${PROJ_DIR}/pipeline_data
ASSMEBLIES_DIR = ${DATA_DIR}/assemblies/${VERSION}
HAL_BIN_DIR = ${PROJ_DIR}/src/progressiveCactus/submodules/hal/bin
PYCBIO_DIR = ${PROJ_DIR}/src/pycbio

TRANS_MAP_DIR = ${DATA_DIR}/comparative/${VERSION}/transMap/${TRANS_MAP_VERSION}
TMR_DIR = ${DATA_DIR}/comparative/${VERSION}/augustus/tmr
SRC_GENCODE_DATA_DIR = ${TRANS_MAP_DIR}/data
ASM_GENOMES_DIR = ${DATA_DIR}/assemblies/${VERSION}
CHAIN_DIR = ${DATA_DIR}/comparative/${VERSION}/chains
ANNOTATION_DIR = ${DATA_DIR}/comparative/${VERSION}/comparativeAnnotation/${COMPARATIVE_ANNOTATOR_VERSION}

DONE_FLAG_DIR = ${DATA_DIR}/comparative/${VERSION}/pipeline_completion_flags

# this is function to generate the orgDb name from an org, use it with:
#    $(call orgToOrgDbFunc,${yourOrg})
orgToOrgDbFunc = Mus${1}_${VERSION}

# HAL file with simple and browser database names (e.g. Mus_XXX_1411)
halFile = ${DATA_DIR}/comparative/${VERSION}/cactus/${VERSION}.hal
halBrowserFile = ${DATA_DIR}/comparative/${VERSION}/cactus/${VERSION}_browser.hal

# LODs (based off the halBrowserFile)
lodTxtFile = ${DATA_DIR}/comparative/${VERSION}/cactus/${VERSION}_lod.txt
lodDir = ${DATA_DIR}/comparative/${VERSION}/cactus/${VERSION}_lods

###
# GENCODE gene sets
###

# GENCODE databases being compared
gencodeBasic = GencodeBasic${GENCODE_VERSION}
gencodeComp = GencodeComp${GENCODE_VERSION}
gencodePseudo = GencodePseudoGene${GENCODE_VERSION}
gencodeAttrs = GencodeAttrs${GENCODE_VERSION}
gencodeSubsets = ${gencodeComp} ${gencodeBasic} ${gencodePseudo}

# GENCODE src annotations based on hgDb databases above
srcGencodeBasic = wgEncode${gencodeBasic}
srcGencodeComp = wgEncode${gencodeComp}
srcGencodePseudo = wgEncode${gencodePseudo}
srcGencodeAttrs = wgEncode${gencodeAttrs}
srcGencodeSubsets = ${srcGencodeBasic} ${srcGencodeComp} ${srcGencodePseudo}
srcGencodeAttrsTsv = ${SRC_GENCODE_DATA_DIR}/${srcGencodeAttrs}.tsv
srcGencodeAllGp = ${srcGencodeSubsets:%=${SRC_GENCODE_DATA_DIR}/%.gp}
srcGencodeAllFa = ${srcGencodeSubsets:%=${SRC_GENCODE_DATA_DIR}/%.fa}
srcGencodeAllPsl = ${srcGencodeSubsets:%=${SRC_GENCODE_DATA_DIR}/%.psl}
srcGencodeAllCds = ${srcGencodeSubsets:%=${SRC_GENCODE_DATA_DIR}/%.cds}
srcGencodeAllBed = ${srcGencodeSubsets:%=${SRC_GENCODE_DATA_DIR}/%.bed}

# hgDb tables used in transMap/comparativeAnnotator
transMapGencodeBasic = transMap${gencodeBasic}
transMapGencodeComp = transMap${gencodeComp}
transMapGencodePseudo = transMap${gencodePseudo}
transMapGencodeAttrs = transMap${gencodeAttrs}
transMapGencodeSubsets = ${transMapGencodeComp} ${transMapGencodeBasic} ${transMapGencodePseudo}


##
# Sequence files
##

# call function to obtain a assembly file given an organism and extension
asmFileFunc = ${ASM_GENOMES_DIR}/${1}.${2}

# call functions to get particular assembly files given an organism
asmFastaFunc = $(call asmFileFunc ${1},fa)
asmTwoBitFunc = $(call asmFileFunc ${1},2bit)
asmChromSizesFunc = $(call asmFileFunc ${1},chrom.sizes)

# list of sequence files
targetFastaFiles = ${mappedOrgs:%=$(call asmFastaFunc,%)}
targetTwoBitFiles = ${mappedOrgs:%=$(call asmTwoBitFunc,%)}
targetChromSizes = ${mappedOrgs:%=$(call asmChromSizesFunc,%)}
queryFasta = $(call asmFastaFunc,${srcOrg})
queryTwoBit = $(call asmTwoBitFunc,${srcOrg})
queryChromSizes = $(call asmChromSizesFunc,${srcOrg})


##
# AugustusTMR
# at this point is only run on one gencode subset to avoid wasted computation
##
augustusGencodeSet = ${gencodePseudo}
AUGUSTUS_DIR = ${DATA_DIR}/comparative/${VERSION}/augustus
AUGUSTUS_TMR_DIR = ${AUGUSTUS_DIR}/tmr
AUGUSTUS_WORK_DIR = ${AUGUSTUS_DIR}/work


##
# AugustusCGP
##
AUGUSTUS_CGP_BASE_DIR = ${AUGUSTUS_DIR}/cgp
AUGUSTUS_CGP_DIR = ${AUGUSTUS_CGP_BASE_DIR}/filteredCGP
AUGUSTUS_CGP_INTRON_BITS_DIR = ${AUGUSTUS_CGP_DIR}/intronbits


# comparative anotations types produced
compAnnTypes = allClassifiers allAugustusClassifiers potentiallyInterestingBiology assemblyErrors alignmentErrors transMapGood augustusGood

###
# chaining
###
CHAINING_DIR = ${DATA_DIR}/comparative/${VERSION}/chaining/${CHAINING_VERSION}

###
# parasol
###
parasolHost = ku

###
# makefile stuff
###
host=$(shell hostname)
ppid=$(shell echo $$PPID)
tmpExt = ${host}.${ppid}.tmp

.SECONDARY:  # keep intermediates
SHELL = /bin/bash -beEu
export SHELLOPTS := pipefail
PYTHON_BIN = /hive/groups/recon/local/bin
AUGUSTUS_BIN_DIR = /hive/users/ifiddes/augustus/trunks/bin

python = ${PYTHON_BIN}/python
export PATH := ${PYTHON_BIN}:${PYCBIO_DIR}/bin:./bin:${HAL_BIN_DIR}:${AUGUSTUS_BIN_DIR}:${PATH}
export PYTHONPATH := ./:${PYTHONPATH}

ifneq (${HOSTNAME},hgwdev)
ifneq ($(wildcard ${HOME}/.hg.rem.conf),)
    # if this exists, it allows running on kolossus because of remote access to UCSC databases
    # however must load databases on hgwdev
    export HGDB_CONF=${HOME}/.hg.rem.conf
endif
endif

# insist on group-writable umask
ifneq ($(shell umask),0002)
     $(error umask must be 0002)
endif

ifeq (${TMPDIR},)
     $(error TMPDIR environment variable not set)
endif

KENT_DIR = ${HOME}/kent
KENT_HG_LIB_DIR = ${KENT_DIR}/src/hg/lib

# root directory for jobtree jobs.  Subdirectories should
# be create for each task
jobTreeRootTmpDir = jobTree.tmp/${VERSION}

# jobTree configuration
batchSystem = parasol
maxThreads = 40
defaultMemory = 8589934592
maxJobDuration = 28800
jobTreeOpts = --defaultMemory ${defaultMemory} --batchSystem ${batchSystem} --parasolCommand $(shell pwd -P)/bin/remparasol \
              --maxJobDuration ${maxJobDuration} --maxThreads ${maxThreads} --stats
