import luigi
import sys
import os
import subprocess
import shutil
from common_functions import TemporaryFilePath


class GenomeFileConfiguration(object):
    """
    Takes the initial configuration from the main driver script and builds paths to all files that will be produced
    by these tasks.
    """
    def __init__(self, cfg, genome):
        self.genome = genome
        self.hal_file = cfg['Cactus']['hal']
        self.target_dir = os.path.join(cfg['Directories']['output'], 'genome_files', genome)
        self.genome_fasta = os.path.join(self.target_dir, genome + ".fa")
        self.genome_two_bit = os.path.join(self.target_dir, genome + ".2bit")
        self.chrom_sizes = os.path.join(self.target_dir, genome + ".chrom.sizes")
        self.flat_fasta = self.genome_fasta + ".flat"


class RunGenomeFiles(luigi.WrapperTask):
    params = luigi.Parameter()

    def requires(self):
        for genome in self.params['genomes']:
            cfg = GenomeFileConfiguration(self.params, genome)
            yield GenomeFasta(cfg=cfg, target_file=cfg.genome_fasta)
            yield GenomeTwoBit(cfg=cfg, target_file=cfg.genome_two_bit)
            yield GenomeSizes(cfg=cfg, target_file=cfg.chrom_sizes)
            yield GenomeFlatFasta(cfg=cfg, target_file=cfg.flat_fasta)


class HalFile(luigi.ExternalTask):
    hal_file = luigi.Parameter()

    def output(self):
        return luigi.LocalTarget(self.hal_file)


class AbstractGenomeFile(luigi.Task):
    cfg = luigi.Parameter()
    target_file = luigi.Parameter()

    def output(self):
        return luigi.LocalTarget(self.target_file)

    def move_output_to_destination(self, outf_path):
        self.output().makedirs()
        shutil.move(outf_path, self.output().path)


class GenomeFasta(AbstractGenomeFile):
    def requires(self):
        return HalFile(self.cfg.hal_file)

    def run(self):
        with TemporaryFilePath() as outf_path:
            cmd = ['hal2fasta', self.cfg.hal_file, self.cfg.genome, '--outFaPath', outf_path]
            subprocess.call(cmd)
            self.move_output_to_destination(outf_path)


class GenomeTwoBit(AbstractGenomeFile):
    def requires(self):
        return GenomeFasta(cfg=self.cfg, target_file=self.cfg.genome_fasta)

    def run(self):
        with TemporaryFilePath() as outf_path:
            cmd = ['faToTwoBit', self.cfg.genome_fasta, outf_path]
            subprocess.call(cmd)
            self.move_output_to_destination(outf_path)


class GenomeSizes(AbstractGenomeFile):
    def requires(self):
        return HalFile(self.cfg.hal_file)

    def run(self):
        with TemporaryFilePath() as outf_path:
            with open(outf_path, 'w') as outf:
                cmd = ['halStats', '--chromSizes', self.cfg.genome, self.cfg.hal_file]
                subprocess.call(cmd, stdout=outf)
                self.move_output_to_destination(outf_path)


class GenomeFlatFasta(AbstractGenomeFile):
    def requires(self):
        return (GenomeFasta(cfg=self.cfg, target_file=self.cfg.genome_fasta), 
                GenomeTwoBit(cfg=self.cfg, target_file=self.cfg.genome_two_bit))

    def run(self):
        cmd = ['pyfasta', 'flatten', self.cfg.genome_fasta]
        subprocess.call(cmd)