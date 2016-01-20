import luigi
import sys
import os
import subprocess
import tempfile
import shutil
sys.path.append('comparativeAnnotator/lib')
from general_lib import mkdir_p


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
            cfg = GenomeFileConfiguration(self.params)
            mkdir_p(cfg.target_dir)
            yield GenomeFasta(cfg, cfg.genome_fasta)
            yield GenomeTwoBit(cfg, cfg.genome_two_bit)
            yield GenomeSizes(cfg, cfg.chrom_sizes)


class HalFile(luigi.ExternalTask):
    hal_file = luigi.Parameter()

    def output(self):
        return luigi.LocalTarget(self.hal_file)


class AbstractGenomeFile(luigi.Task):
    cfg = luigi.Parameter()
    target_file = luigi.Parameter()

    def output(self):
        return luigi.LocalTarget(self.target_file)


class GenomeFasta(AbstractGenomeFile):
    def requires(self):
        return HalFile(self.cfg.hal_file)

    def run(self):
        with tempfile.TemporaryFile() as outf:
            cmd = ['hal2fasta', self.cfg.hal_file, self.cfg.genome, '--outFaPath', outf]
            subprocess.call(cmd)
            shutil.move(outf, self.output())


class GenomeTwoBit(AbstractGenomeFile):
    def requires(self):
        return GenomeFasta(self.cfg)

    def run(self):
        with tempfile.TemporaryFile() as outf:
            cmd = ['faToTwoBit', self.cfg.genome_fasta, outf]
            subprocess.call(cmd)
            shutil.move(outf, self.output())


class GenomeSizes(AbstractGenomeFile):
    def requires(self):
        return HalFile(self.cfg.hal_file)

    def run(self):
        with tempfile.TemporaryFile() as outf:
            cmd = ['halStats', '--chromSizes', self.cfg.genome, self.cfg.hal_file, outf]
            subprocess.call(cmd)
            shutil.move(outf, self.output())