####################################################################################################
# Configuration
# Modify variables below as new releases are made.
# Tag the commit when running the pipeline.
####################################################################################################


MSCA_VERSION = 1411
#MSCA_VERSION = 1504

ifeq (${MSCA_VERSION},1504)
mappedOrgs = Rattus 129S1 AJ AKRJ BALBcJ C3HHeJ C57B6NJ CASTEiJ CBAJ DBA2J FVBNJ LPJ NODShiLtJ NZOHlLtJ PWKPhJ SPRETEiJ WSBEiJ CAROLIEiJ PAHARIEiJ
GENCODE_VERSION = VM4
TRANS_MAP_VERSION = 2015-05-27
COMPARATIVE_ANNOTATOR_VERSION = 2015-05-20
else $(${MSCA_VERSION},1411)
mappedOrgs = Rattus 129S1 AJ AKRJ BALBcJ C3HHeJ C57B6NJ CASTEiJ CBAJ DBA2J FVBNJ LPJ NODShiLtJ NZOHlLtJ PWKPhJ SPRETEiJ WSBEiJ
GENCODE_VERSION = VM4
TRANS_MAP_VERSION = 2015-05-28
COMPARATIVE_ANNOTATOR_VERSION = 2015-05-28
endif

# source organism information (reference mouse)
srcOrg = C57B6J
srcOrgHgDb = mm10

