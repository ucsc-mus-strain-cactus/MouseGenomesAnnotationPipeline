"""
Produces genome files input for comparative annotation pipeline.
"""
import luigi
import sys
import os
import itertools
import subprocess
from pycbio.sys.procOps import runProc, callProc
from pycbio.sys.fileOps import ensureDir
from lib.ucsc_chain_net import chainNetStartup
from lib.jobtree_luigi import make_jobtree_dir
from lib.parsing import HashableNamespace
from abstract_classes import AbstractAtomicFileTask, AbstractAtomicManyFileTask


########################################################################################################################
########################################################################################################################
## Genome Files
########################################################################################################################
########################################################################################################################


class GenomeFileConfiguration(HashableNamespace):
    """
    Takes the initial configuration from the main driver script and builds paths to all files that will be produced
    by these tasks.
    """
    def __init__(self, args, genome):
        self.__dict__.update(vars(args))
        self.genome = genome
        self.target_dir = os.path.join(args.workDir, 'genome_files', genome)
        self.genome_fasta = os.path.join(self.target_dir, genome + '.fa')
        self.genome_two_bit = os.path.join(self.target_dir, genome + '.2bit')
        self.chrom_sizes = os.path.join(self.target_dir, genome + '.chrom.sizes')
        self.flat_fasta = self.genome_fasta + '.flat'

    def __repr__(self):
        return '{}: {}'.format(self.__class__.__name__, self.genome)


class RunGenomeFiles(luigi.WrapperTask):
    """
    WrapperTask to produce all input genome files for all genomes.
    """
    args = luigi.Parameter()

    def requires(self):
        for genome in self.args.genomes:
            cfg = GenomeFileConfiguration(self.args, genome)
            yield GenomeFasta(cfg=cfg, target_file=cfg.genome_fasta)
            yield GenomeTwoBit(cfg=cfg, target_file=cfg.genome_two_bit)
            yield GenomeSizes(cfg=cfg, target_file=cfg.chrom_sizes)
            yield GenomeFlatFasta(cfg=cfg, target_file=cfg.flat_fasta)


class GenomeFasta(AbstractAtomicFileTask):
    """
    Produce a fasta file from a hal file. Requires hal2fasta.
    """
    def run(self):
        cmd = ['hal2fasta', self.cfg.hal, self.cfg.genome]
        self.run_cmd(cmd)


class GenomeTwoBit(AbstractAtomicFileTask):
    """
    Produce a 2bit file from a fasta file. Requires kent tool faToTwoBit.
    """
    def requires(self):
        return GenomeFasta(cfg=self.cfg, target_file=self.cfg.genome_fasta)

    def run(self):
        cmd = ['faToTwoBit', self.cfg.genome_fasta, '/dev/stdout']
        self.run_cmd(cmd)


class GenomeSizes(AbstractAtomicFileTask):
    """
    Produces a genome chromosome sizes file. Requires halStats.
    """
    def run(self):
        cmd = ['halStats', '--chromSizes', self.cfg.genome, self.cfg.hal]
        self.run_cmd(cmd)


class GenomeFlatFasta(AbstractAtomicFileTask):
    """
    Flattens a genome fasta in-place using pyfasta. Requires the pyfasta package.
    """
    def requires(self):
        return (GenomeFasta(cfg=self.cfg, target_file=self.cfg.genome_fasta), 
                GenomeTwoBit(cfg=self.cfg, target_file=self.cfg.genome_two_bit))

    def run(self):
        cmd = ['pyfasta', 'flatten', self.cfg.genome_fasta]
        subprocess.call(cmd)


########################################################################################################################
########################################################################################################################
## Annotation Files
########################################################################################################################
########################################################################################################################


class AnnotationFileConfiguration(HashableNamespace):
    """
    Takes the initial configuration from the main driver script and builds paths to all files that will be produced
    by these tasks.
    Produces files specific to each source annotation set, including a transcriptome fasta, a transcript bed,
    and a fake psl that will be projected by transMap.
    """
    def __init__(self, args, GeneSetNamespace):
        self.__dict__.update(vars(GeneSetNamespace))  # add this gene set
        genome_file_cfg = GenomeFileConfiguration(args, self.sourceGenome)  # construct config for genome files
        self.genome_fasta = genome_file_cfg.genome_fasta
        self.genome_sizes = genome_file_cfg.chrom_sizes
        base_source_dir = os.path.join(args.workDir, 'annotation_files', self.sourceGenome, self.geneSet)
        base_gene_set = os.path.splitext(os.path.basename(self.genePred))[0]
        base_out_path = os.path.join(base_source_dir, base_gene_set)
        self.genepred_copy = base_out_path + '.gp'  # genePred will be copied to this directory too for simplicity
        self.transcript_bed = base_out_path + '.bed'
        self.transcript_fasta = base_out_path + '.fa'
        self.flat_transcript_fasta = self.transcript_fasta + '.flat'
        self.fake_psl = base_out_path + '.psl'
        self.fake_psl_cds = base_out_path + '.cds'

    def __repr__(self):
        return '{}: {}-{}'.format(self.__class__.__name__, self.sourceGenome, self.geneSet)


class RunAnnotationFiles(luigi.WrapperTask):
    """
    WrapperTask for all annotation file commands.
    """
    args = luigi.Parameter()

    def requires(self):
        for GeneSetNamespace in self.args.geneSets:
            cfg = AnnotationFileConfiguration(self.args, GeneSetNamespace)
            yield GenePred(cfg=cfg, target_file=cfg.genepred_copy)
            yield TranscriptFasta(cfg=cfg, target_file=cfg.transcript_fasta)
            yield TranscriptBed(cfg=cfg, target_file=cfg.transcript_bed)
            yield FakePsl(cfg=cfg, target_files=(cfg.fake_psl, cfg.fake_psl_cds))


class GenePred(AbstractAtomicFileTask):
    """
    Copies the source genePred to the same directory as all the other annotation input files will be generated.
    """
    def run(self):
        self.atomic_install(luigi.LocalTarget(self.cfg.genePred), force_copy=True)


class TranscriptBed(AbstractAtomicFileTask):
    """
    Produces a BED record from the input genePred annotation. Makes use of Kent tool genePredToBed
    """
    def requires(self):
        return GenePred(cfg=self.cfg, target_file=self.cfg.genepred_copy)

    def run(self):
        cmd = ['genePredToBed', self.requires().output().path, '/dev/stdout']
        self.run_cmd(cmd)


class TranscriptFasta(AbstractAtomicFileTask):
    """
    Produces a fasta for each transcript. Requires bedtools.
    """
    def requires(self):
        return (TranscriptBed(cfg=self.cfg, target_file=self.cfg.transcript_bed),
                GenomeFasta(cfg=self.cfg, target_file=self.cfg.genome_fasta))

    def run(self):
        bed_target, genome_fasta = self.requires()
        bed_target_path = bed_target.output().path
        genome_fasta_target_path = genome_fasta.output().path
        cmd = ['bedtools', 'getfasta', '-fi', genome_fasta_target_path, '-bed', bed_target_path, '-fo', '/dev/stdout',
               '-name', '-split', '-s']
        self.run_cmd(cmd)


class FakePsl(AbstractAtomicManyFileTask):
    """
    Produces a fake PSL mapping transcripts to the genome, using the Kent tool genePredToFakePsl
    """

    def requires(self):
        return GenePred(cfg=self.cfg, target_file=self.cfg.genepred_copy)

    def run(self):
        tmp_fake_psl = luigi.LocalTarget(is_tmp=True)
        tmp_fake_cds = luigi.LocalTarget(is_tmp=True)
        tmp_files = (tmp_fake_psl, tmp_fake_cds)
        cmd = ['genePredToFakePsl', '-chromSize={}'.format(self.cfg.genome_sizes), 'noDB', self.cfg.genepred_copy,
               tmp_fake_psl.path, tmp_fake_cds.path]
        self.run_cmd(cmd, tmp_files)

