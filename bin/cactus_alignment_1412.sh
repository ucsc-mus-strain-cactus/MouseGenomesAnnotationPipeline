#!/bin/sh
set -o errexit
set -o pipefail
set -o nounset

# a bit weird, but we get the absolute path of the pipeline src dir.
PIPELINE_DIR=$(readlink -f "$(dirname "$0")/..")
# Read the config file containing MSCA_DATA_DIR variable, etc.
. "${PIPELINE_DIR}/etc/pipeline_vars.sh"

if [ ! -d "$MSCA_DATA_DIR/assemblies/1412/genome" ]; then
    echo "Couldn't find 1412 assemblies; please download them first." >&2
    exit 1
fi

# ProgressiveCactus build
CACTUS_TAG=msca_1412
echo "Checking out progressiveCactus at tag $CACTUS_TAG and building"
mkdir -p "${PIPELINE_DIR}/extern"
cd "${PIPELINE_DIR}/extern"
git clone https://github.com/glennhickey/progressiveCactus progressiveCactus_1412
cd progressiveCactus_1412
git checkout "$CACTUS_TAG" && git submodule update --init && make >/dev/null

# Setup configs
mkdir -p "${MSCA_DATA_DIR}/comparative/1412/cactus"
cd "${MSCA_DATA_DIR}/comparative/1412/cactus"
cp "${PIPELINE_DIR}/etc/cactus_progressive_config_1412.xml" .
sed -i "s/MSCA_DATA_DIR/${MSCA_DATA_DIR}/g" "${PIPELINE_DIR}/etc/1412_seqFile.txt" > 1412_seqFile.txt

# Run the alignment
"${PIPELINE_DIR}/extern/progressiveCactus_1412/bin/runProgressiveCactus.sh" --config cactus_progressive_config_1412.xml $PROGRESSIVE_CACTUS_BATCH_ARGS --root msca_root 1412_seqFile.txt work_1412 1412.hal
