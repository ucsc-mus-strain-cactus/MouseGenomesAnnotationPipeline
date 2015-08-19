##
# generate UCSC browser chains from HAL files
# recusively calls self with
#   chainQueryOrg chainTargetOrg
##
include defs.mk

all: ${mappedOrgs:%=%.dochain}

%.dochain:
	${MAKE} -f rules/chaining.mk chain chainQueryOrg=${srcOrg} chainTargetOrg=$*

# recurisve call:
ifneq (${chainQueryOrg},)
chainQueryOrgDb = Mus${chainQueryOrg}_${MSCA_VERSION}
chainTargetOrgDb = Mus${chainTargetOrg}_${MSCA_VERSION}

chain:



endif
