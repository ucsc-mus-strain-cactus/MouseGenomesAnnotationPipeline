#!/bin/sh
# Download and verify the 1412 series of assemblies.
set -o errexit
set -o pipefail
set -o nounset

# a bit weird, but we get the absolute path of the pipeline src dir.
PIPELINE_DIR=$(readlink -f $(dirname $0)/..)
# Read the config file containing MSCA_DATA_DIR variable, etc.
source ${PIPELINE_DIR}/etc/pipeline_vars.sh

mkdir -p ${MSCA_DATA_DIR}/assemblies/1412/genome/
cd ${MSCA_DATA_DIR}/assemblies/1412/genome/
echo "Downloading assemblies. Grab a cup of coffee."
wget ftp://ftp-mouse.sanger.ac.uk/REL-1412-Assembly/*.masked.gz*

echo "Verifying file integrity."
md5sum -c *.gz.md5

echo "Extracting files."
gunzip *.gz

echo "Done."
