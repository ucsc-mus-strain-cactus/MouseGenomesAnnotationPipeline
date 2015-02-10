# Config file for shell scripts.

# Data directory: where the analysis results and assembly data goes.
export MSCA_DATA_DIR=/hive/groups/recon/projs/mus_strain_cactus/pipeline_data

# Batch system parameters for progressiveCactus. Adjust to suit your setup.
export PROGRESSIVE_CACTUS_BATCH_ARGS="--batchSystem parasol --bigBatchSystem singleMachine --defaultMemory 8589934593 --bigMemoryThreshold 8589934592 --bigMaxMemory 893353197568 --bigMaxCpus 30 --maxThreads 30 --parasolCommand='/cluster/home/jcarmstr/bin/parasol -host=ku' --retryCount 3"
