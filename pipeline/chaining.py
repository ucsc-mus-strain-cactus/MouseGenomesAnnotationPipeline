"""
Chains genome alignments for use by transMap.
"""
import luigi
import sys
import os
import itertools
import subprocess
from pycbio.sys.procOps import runProc, callProc
from pycbio.sys.fileOps import ensureDir, rmTree
from lib.ucsc_chain_net import chainNetStartup
from lib.jobtree_luigi import make_jobtree_dir
from lib.parsing import HashableNamespace
from abstract_classes import AbstractAtomicFileTask, AbstractAtomicManyFileTask
# import all other targets so they can build the tree
import genome_files


########################################################################################################################
########################################################################################################################
## Chaining Files
########################################################################################################################
########################################################################################################################


class ChainingFileConfiguration(HashableNamespace):
    """
    Takes the initial configuration from the main driver script and builds paths to all files that will be produced
    by these tasks.
    Using camelCase here to interface with Mark's code.
    """
    def __init__(self, args, target_genome, query_genome):
        self.__dict__.update(vars(args.jobTreeOptions))  # add jobTree options to this cfg
        self.targetGenome = target_genome
        self.queryGenome = query_genome
        self.base_source_dir = os.path.join(args.workDir, 'chaining')
        self.hal = args.hal
        self.chainFile = os.path.join(self.base_source_dir, '{}_{}.chain.gz'.format(query_genome, target_genome))
        self.netFile = os.path.join(self.base_source_dir, '{}_{}.net.gz'.format(query_genome, target_genome))
        self.jobTree = os.path.join(args.jobTreeDir, 'chaining', '{}_{}'.format(query_genome, target_genome))
        self.query_file_cfg = genome_files.GenomeFileConfiguration(args, query_genome)
        self.target_file_cfg = genome_files.GenomeFileConfiguration(args, target_genome)
        self.queryTwoBit = self.query_file_cfg.genome_two_bit
        self.targetTwoBit = self.target_file_cfg.genome_two_bit

    def __repr__(self):
        return '{}: {}-{}'.format(self.__class__.__name__, self.queryGenome, self.targetGenome)


class RunChainingFiles(luigi.WrapperTask):
    """
    WrapperTask for all chaining commands. Produces a ChainingFileConfiguration for each pair of query-target.
    """
    args = luigi.Parameter()

    def requires(self):
        for geneSet in self.args.geneSets:
            for target_genome in self.args.genomes:
                if target_genome != geneSet.sourceGenome:
                    chaining_cfg = ChainingFileConfiguration(self.args, target_genome, geneSet.sourceGenome)
                    yield ChainGenomes(cfg=chaining_cfg)


class ChainGenomes(AbstractJobTreeTask):
    """
    Interfaces with jobTree and does chaining.
    """
    def output(self):
        return (luigi.LocalTarget(self.cfg.chainFile), luigi.LocalTarget(self.cfg.netFile))
    
    def requires(self):
        return (genome_files.GenomeTwoBit(cfg=self.cfg.target_file_cfg, target_file=self.cfg.targetTwoBit), 
                genome_files.GenomeTwoBit(cfg=self.cfg.query_file_cfg, target_file=self.cfg.queryTwoBit))

    def run(self):
        # make sure jobTree has a clean starting directory
        ensureDir(self.cfg.base_source_dir)
        make_jobtree_dir(self.cfg.jobTree)
        chainNetStartup(self.cfg)
