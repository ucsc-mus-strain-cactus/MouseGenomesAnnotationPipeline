include ../pipeline/config.mk

# base directory definitions
MSCA_PROJ_DIR = /hive/groups/recon/projs/mus_strain_cactus
MSCA_DATA_DIR = ${MSCA_PROJ_DIR}/pipeline_data
MSCA_ASSMEBLIES_DIR = ${MSCA_DATA_DIR}/assemblies/${MSCA_VERSION}
HAL_BIN_DIR = ${MSCA_PROJ_DIR}/src/progressiveCactus/submodules/hal/bin
PYCBIO_DIR = ${MSCA_PROJ_DIR}/src/pycbio
TRANS_MAP_DIR = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/transMap/${TRANS_MAP_VERSION}
SRC_GENCODE_DATA_DIR = ${TRANS_MAP_DIR}/data
ASM_GENOMES_DIR = ${MSCA_DATA_DIR}/assemblies/${MSCA_VERSION}
CHAIN_DIR = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/chains
ANNOTATION_DIR = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/comparativeAnnotation/${COMPARATIVE_ANNOTATOR_VERSION}

###
# genome and organisms.  The term `org' indicated the abbreviation for the organism,
# the term `orgDb' refers to the browser database name, in the form Mus${org}_${MSCA_VERSION}
###
allOrgs = ${srcOrg} ${mappedOrgs}

# this is function to generate the orgDb name from an org, use it with:
#    $(call orgToOrgDbFunc,${yourOrg})
orgToOrgDbFunc = Mus${0}_${MSCA_VERSION}

# HAL file with simple and browser database names (e.g. Mus_XXX_1411)
halFile = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/cactus/${MSCA_VERSION}.hal
halBrowserFile = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/cactus/${MSCA_VERSION}_browser.hal

# LODs (based off the halBrowserFile)
lodTxtFile = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/cactus/${MSCA_VERSION}_lod.txt
lodDir = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/cactus/${MSCA_VERSION}_lods


###
# GENCODE gene sets
###
# GENCODE databases being compared
gencodeBasic = GencodeBasic${GENCODE_VERSION}
gencodeComp = GencodeComp${GENCODE_VERSION}
gencodePseudo = GencodePseudoGene${GENCODE_VERSION}
gencodeAttrs = GencodeAttrs${GENCODE_VERSION}
gencodeSubsets = ${gencodeBasic} ${gencodeComp} ${gencodePseudo}

# hgDb databases used in transMap/comparativeAnnotator
transMapGencodeBasic = transMap${gencodeBasic}
transMapGencodeComp = transMap${gencodeComp}
transMapGencodePseudo = transMap${gencodePseudo}
transMapGencodeAttrs = transMap${gencodeAttrs}
transMapGencodeSubsets = ${transMapGencodeBasic} ${transMapGencodeComp} ${transMapGencodePseudo}

# GENCODE src annotations based on hgDb databases above
srcGencodeBasic = wgEncode${gencodeBasic}
srcGencodeComp = wgEncode${gencodeComp}
srcGencodePseudo = wgEncode${gencodePseudo}
srcGencodeAttrs = wgEncode${gencodeAttrs}
srcGencodeSubsets = ${srcGencodeBasic} ${srcGencodeComp} ${srcGencodePseudo}
srcAttrsTsv = ${SRC_GENCODE_DATA_DIR}/${srcGencodeAttrs}.tsv
srcGencodeAllGp = ${srcGencodeSubsets:%=${SRC_GENCODE_DATA_DIR}/%.gp}
srcGencodeAllFa = ${srcGencodeSubsets:%=${SRC_GENCODE_DATA_DIR}/%.fa}
srcGencodeAllPsl = ${srcGencodeSubsets:%=${SRC_GENCODE_DATA_DIR}/%.psl}
srcGencodeAllCds = ${srcGencodeSubsets:%=${SRC_GENCODE_DATA_DIR}/%.cds}
srcGencodeAllBed = ${srcGencodeSubsets:%=${SRC_GENCODE_DATA_DIR}/%.bed}

# sequence files needed by comparativeAnnotator
targetFastaFiles = ${mappedOrgs:%=${ASM_GENOMES_DIR}/%.fa}
targetTwoBitFiles = ${mappedOrgs:%=${ASM_GENOMES_DIR}/%.2bit}
targetChromSizes = ${mappedOrgs:%=${ASM_GENOMES_DIR}/%.chrom.sizes}
queryFasta = ${ASM_GENOMES_DIR}/${srcOrg}.fa
queryTwoBit = ${ASM_GENOMES_DIR}/${srcOrg}.2bit
queryChromSizes = ${ASM_GENOMES_DIR}/${srcOrg}.chrom.sizes

# comparative anotations types produced
compAnnTypes = alignmentErrors allProblems assemblyErrors comparativeAnnotation inFrameStop interestingBiology

###
# chaining
###
CHAINING_DIR = ${MSCA_DATA_DIR}/comparative/${MSCA_VERSION}/chaining/${CHAINING_VERSION}

# call functions to obtain path to chain/net files, given a srcORg,targetOrg
chainAllFunc = ${CHAINING_DIR}/${1}-${2}.all.chain.gz
netAllFunc = ${CHAINING_DIR}/${1}-${2}.all.net.gz
chainSynFunc = ${CHAINING_DIR}/${1}-${2}.syn.chain.gz
netSynFunc = ${CHAINING_DIR}/${1}-${2}.syn.net.gz

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

python = ${PYTHON_BIN}/python
export PATH := ${PYTHON_BIN}:${PYCBIO_DIR}/bin:./bin:${PATH}
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
jobTreeRootTmpDir = jobTree.tmp/${MSCA_VERSION}
