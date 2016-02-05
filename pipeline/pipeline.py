"""
Run the pipeline
"""
import luigi
import sys
import os
import itertools
import subprocess
import argparse
from pycbio.sys.procOps import runProc, callProc
from pycbio.sys.fileOps import ensureDir
from lib.ucsc_chain_net import chainNetStartup
#from lib.comparative_annotator import comparativeAnnotatorStartup TODO: do it this way
from lib.parsing import HashableNamespace
from abstract_classes import AbstractAtomicFileTask, AbstractAtomicManyFileTask, AbstractJobTreeTask
from comparativeAnnotator.comparativeAnnotator import start_pipeline


########################################################################################################################
########################################################################################################################
## Genome Files
########################################################################################################################
########################################################################################################################


class GenomeFiles(luigi.WrapperTask):
    """
    WrapperTask to produce all input genome files for all genomes.
    """
    cfg = luigi.Parameter()

    def requires(self):
        for genome_cfg in [self.cfg.target_genome_files, self.cfg.query_genome_files]:
            yield GenomeFasta(cfg=genome_cfg, target_file=genome_cfg.genome_fasta)
            yield GenomeTwoBit(cfg=genome_cfg, target_file=genome_cfg.genome_two_bit)
            yield GenomeSizes(cfg=genome_cfg, target_file=genome_cfg.chrom_sizes)
            yield GenomeFlatFasta(cfg=genome_cfg, target_file=genome_cfg.flat_fasta)


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
        runProc(cmd)


########################################################################################################################
########################################################################################################################
## Annotation Files
########################################################################################################################
########################################################################################################################


class AnnotationFiles(luigi.WrapperTask):
    """
    WrapperTask for all annotation file commands.
    """
    cfg = luigi.Parameter()

    def requires(self):
        annot_files = self.cfg.annot_files
        yield GenePred(cfg=annot_files, target_file=annot_files.gp)
        yield Attributes(cfg=annot_files, target_file=annot_files.attributes)
        yield TranscriptFasta(cfg=annot_files, target_file=annot_files.transcript_fasta, 
                              genome_cfg=self.cfg.query_genome_files)
        yield TranscriptBed(cfg=annot_files, target_file=annot_files.bed)
        yield FakePsl(cfg=annot_files, target_files=(annot_files.psl, annot_files.cds),
                      genome_cfg=self.cfg.query_genome_files)


class GenePred(AbstractAtomicFileTask):
    """
    Copies the source genePred to the same directory as all the other annotation input files will be generated.
    """
    def run(self):
        self.atomic_install(luigi.LocalTarget(self.cfg.genePred), force_copy=True)


class Attributes(AbstractAtomicFileTask):
    """
    Copies the source attributes.tsv to the same directory as all the other annotation input files will be generated.
    """
    def run(self):
        self.atomic_install(luigi.LocalTarget(self.cfg.attributesTsv), force_copy=True)


class TranscriptBed(AbstractAtomicFileTask):
    """
    Produces a BED record from the input genePred annotation. Makes use of Kent tool genePredToBed
    """
    def requires(self):
        return GenePred(cfg=self.cfg, target_file=self.cfg.gp)

    def run(self):
        cmd = ['genePredToBed', self.requires().output().path, '/dev/stdout']
        self.run_cmd(cmd)


class TranscriptFasta(AbstractAtomicFileTask):
    """
    Produces a fasta for each transcript. Requires bedtools.
    """
    genome_cfg = luigi.Parameter()

    def requires(self):
        return (TranscriptBed(cfg=self.cfg, target_file=self.cfg.bed),
                GenomeFasta(cfg=self.cfg, target_file=self.genome_cfg.genome_fasta))

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
    genome_cfg = luigi.Parameter()

    def requires(self):
        return (GenePred(cfg=self.cfg, target_file=self.cfg.gp),
                GenomeSizes(cfg=self.genome_cfg, target_file=self.genome_cfg.chrom_sizes))

    def run(self):
        tmp_psl = luigi.LocalTarget(is_tmp=True)
        tmp_cds = luigi.LocalTarget(is_tmp=True)
        tmp_files = (tmp_psl, tmp_cds)
        cmd = ['genePredToFakePsl', '-chromSize={}'.format(self.genome_cfg.chrom_sizes), 'noDB', 
               self.cfg.gp, tmp_psl.path, tmp_cds.path]
        self.run_cmd(cmd, tmp_files)


########################################################################################################################
########################################################################################################################
## Chaining Files
########################################################################################################################
########################################################################################################################


class ChainFiles(AbstractJobTreeTask):
    """
    Interfaces with jobTree to make Kent chains over the HAL alignment.
    """
    cfg = luigi.Parameter()

    def output(self):
        return (luigi.LocalTarget(self.cfg.chaining.chainFile), luigi.LocalTarget(self.cfg.chaining.netFile))
    
    def requires(self):
        return (GenomeTwoBit(cfg=self.cfg.target_genome_files, target_file=self.cfg.target_genome_files.genome_two_bit), 
                GenomeTwoBit(cfg=self.cfg.query_genome_files, target_file=self.cfg.query_genome_files.genome_two_bit))

    def run(self):
        ensureDir(self.cfg.chaining.out_dir)
        self.make_jobtree_dir(self.cfg.chaining.jobTree)
        chainNetStartup(self.cfg.chaining)


########################################################################################################################
########################################################################################################################
## transMap
########################################################################################################################
########################################################################################################################


class TransMap(luigi.WrapperTask):
    """
    WrapperTask for all transMap commands.
    """
    cfg = luigi.Parameter()

    def requires(self):
        yield TransMapPsl(cfg=self.cfg, target_file=self.cfg.transmap.psl)
        yield TransMapGp(cfg=self.cfg, target_file=self.cfg.transmap.gp)


class TransMapPsl(AbstractAtomicFileTask):
    """
    Runs transMap.
    """
    def requires(self):
        return ChainFiles(self.cfg), AnnotationFiles(self.cfg)

    def run(self):
        psl_cmd = ['pslMap', '-chainMapFile', self.cfg.annot_files.psl, 
                    self.cfg.chaining.chainFile, '/dev/stdout']
        post_chain_cmd = ['bin/postTransMapChain', '/dev/stdin', '/dev/stdout']
        sort_cmd = ['sort', '-k', '14,14', '-k', '16,16n']
        recalc_cmd = ['pslRecalcMatch', '/dev/stdin', self.cfg.chaining.targetTwoBit, 
                      self.cfg.annot_files.transcript_fasta, 'stdout']
        uniq_cmd = ['bin/pslQueryUniq']
        cmd_list = [psl_cmd, post_chain_cmd, sort_cmd, recalc_cmd, uniq_cmd]
        self.run_cmd(cmd_list)


class TransMapGp(AbstractAtomicFileTask):
    """
    Produces the final transMapped genePred
    """
    def requires(self):
        return TransMapPsl(cfg=self.cfg, target_file=self.cfg.transmap.psl)

    def run(self):
        cmd = ['mrnaToGene', '-keepInvalid', '-quiet', '-genePredExt', '-ignoreUniqSuffix', '-insertMergeSize=0',
               '-cdsFile={}'.format(self.cfg.annot_files.cds), self.cfg.annot_files.psl, '/dev/stdout']
        self.run_cmd(cmd)



########################################################################################################################
########################################################################################################################
## comparativeAnnotator
########################################################################################################################
########################################################################################################################


class RunComparativeAnnotator(luigi.WrapperTask):
    """
    WrapperTask for all comparativeAnnotator commands.
    """
    cfg = luigi.Parameter()

    def requires(self):
        yield ReferenceComparativeAnnotator(self.cfg)
        #yield ComparativeAnnotator(self.cfg)


class ReferenceComparativeAnnotator(AbstractJobTreeTask):
    """
    Runs transMap.
    """
    def output(self):
        return luigi.LocalTarget(self.cfg.comp_ann.reference.done)

    def requires(self):
        return GenomeFiles(self.cfg), AnnotationFiles(self.cfg)

    def run(self):
        self.make_jobtree_dir(self.cfg.comp_ann.reference.jobTree)
        # TODO: this is a hack because the comparativeAnnotator code cannot see the config module
        test = argparse.Namespace()
        test.__dict__.update(vars(self.cfg.comp_ann.reference))
        start_pipeline(test)
        f_h = luigi.LocalTarget(self.cfg.comp_ann.reference.done).open('w')
        f_h.close()


class ComparativeAnnotator(AbstractJobTreeTask):
    """
    Runs comparativeAnnotator.
    TODO: total re-write of comparative annotator to avoid using a done file.
    """
    def output(self):
        return luigi.LocalTarget(self.cfg.comp_ann.transmap.done)

    def requires(self):
        return (ReferenceComparativeAnnotator(self.cfg), TransMap(self.cfg), GenomeFiles(self.cfg),
                AnnotationFiles(self.cfg))

    def run(self):
        self.make_jobtree_dir(self.cfg.comp_ann.transmap.jobTree)
        start_pipeline(self.cfg.comp_ann.transmap)
        f_h = luigi.LocalTarget(self.cfg.comp_ann.transmap.done).open('w')
        f_h.close()