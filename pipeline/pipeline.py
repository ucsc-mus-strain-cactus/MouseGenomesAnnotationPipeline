"""
Run the pipeline
"""
import luigi
import itertools
from pycbio.sys.procOps import runProc
from pycbio.sys.fileOps import ensureDir
from lib.ucsc_chain_net import chainNetStartup
from abstract_classes import AbstractAtomicFileTask, AbstractJobTreeTask
from abstract_classes import RowsSqlTarget
from comparativeAnnotator.annotation_pipeline import main as comp_ann_main
from comparativeAnnotator.plotting.transmap_analysis import paralogy_plot, cov_plot, ident_plot, num_pass_excel,\
    num_pass_excel_gene_level
from comparativeAnnotator.generate_gene_set import generate_gene_set_wrapper
from comparativeAnnotator.plotting.gene_set_plots import gene_set_plots
from comparativeAnnotator.augustus.run_augustus import augustus_tmr
from comparativeAnnotator.augustus.find_intron_vector import find_intron_vector
from comparativeAnnotator.augustus.align_augustus import align_augustus


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
        yield TranscriptFasta(cfg=self.cfg, target_file=self.cfg.transcript_fasta)
        yield FlatTranscriptFasta(cfg=self.cfg, target_file=self.cfg.flat_transcript_fasta)
        yield TranscriptBed(cfg=self.cfg, target_file=self.cfg.bed)
        yield FakePsl(cfg=self.cfg, target_file=self.cfg.psl)
        yield GenomeFiles(cfg=self.cfg)


class TranscriptBed(AbstractAtomicFileTask):
    """
    Produces a BED record from the input genePred annotation. Makes use of Kent tool genePredToBed
    """
    def run(self):
        cmd = ['genePredToBed', self.cfg.annotation_gp, '/dev/stdout']
        self.run_cmd(cmd)


class TranscriptFasta(AbstractAtomicFileTask):
    """
    Produces a fasta for each transcript. Requires bedtools.
    """
    def requires(self):
        return (TranscriptBed(cfg=self.cfg, target_file=self.cfg.bed),
                GenomeFlatFasta(cfg=self.cfg, target_file=self.cfg.flat_fasta))

    def run(self):
        cmd = ['bedtools', 'getfasta', '-fi', self.cfg.ref_fasta, '-bed', self.cfg.bed, '-fo', '/dev/stdout',
               '-name', '-split', '-s']
        self.run_cmd(cmd)


class FlatTranscriptFasta(AbstractAtomicFileTask):
    """
    Flattens the transcript fasta for pyfasta.
    """
    def requires(self):
        return TranscriptFasta(cfg=self.cfg, target_file=self.cfg.transcript_fasta)

    def run(self):
        cmd = ['pyfasta', 'flatten', self.cfg.transcript_fasta]
        runProc(cmd)


class FakePsl(AbstractAtomicFileTask):
    """
    Produces a fake PSL mapping transcripts to the genome, using the Kent tool genePredToFakePsl
    """
    def requires(self):
        return GenomeSizes(cfg=self.cfg, target_file=self.cfg.ref_sizes)

    def run(self):
        cmd = ['genePredToFakePsl', '-chromSize={}'.format(self.cfg.ref_sizes), 'noDB',
               self.cfg.annotation_gp, '/dev/stdout', '/dev/null']
        self.run_cmd(cmd)


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
        yield GenomeFasta(cfg=self.cfg, target_file=self.cfg.genome_fasta)
        yield GenomeTwoBit(cfg=self.cfg, target_file=self.cfg.genome_two_bit)
        yield GenomeSizes(cfg=self.cfg, target_file=self.cfg.chrom_sizes)
        yield GenomeFlatFasta(cfg=self.cfg, target_file=self.cfg.flat_fasta)


class GenomeFasta(AbstractAtomicFileTask):
    """
    Produce a fasta file from a hal file. Requires hal2fasta.
    """
    def run(self):
        cmd = ['hal2fasta', self.cfg.args.hal, self.cfg.genome]
        self.run_cmd(cmd)


class GenomeTwoBit(AbstractAtomicFileTask):
    """
    Produce a 2bit file from a fasta file. Requires kent tool faToTwoBit.
    Needs to be done BEFORE we flatten.
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
        cmd = ['halStats', '--chromSizes', self.cfg.genome, self.cfg.args.hal]
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
        # re-do index now
        cmd = ['samtools', 'faidx', self.cfg.genome_fasta]
        runProc(cmd)


########################################################################################################################
########################################################################################################################
## Chaining Files
########################################################################################################################
########################################################################################################################


class ChainFiles(AbstractJobTreeTask):
    """
    Interfaces with jobTree to make Kent chains over the HAL alignment.
    """
    def output(self):
        return luigi.LocalTarget(self.cfg.chaining.chainFile), luigi.LocalTarget(self.cfg.chaining.netFile)

    def requires(self):
        return (GenomeTwoBit(cfg=self.cfg, target_file=self.cfg.genome_two_bit),
                GenomeTwoBit(cfg=self.cfg.query_cfg, target_file=self.cfg.query_cfg.genome_two_bit))

    def run(self):
        ensureDir(self.cfg.chaining.out_dir)
        self.start_jobtree(self.cfg.chaining, chainNetStartup, norestart=self.cfg.args.norestart)


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
        yield TransMapPsl(cfg=self.cfg, target_file=self.cfg.psl)
        yield TransMapGp(cfg=self.cfg, target_file=self.cfg.gp)


class TransMapPsl(AbstractAtomicFileTask):
    """
    Runs transMap.
    """
    def requires(self):
        return ChainFiles(self.cfg), AnnotationFiles(self.cfg.query_cfg)

    def run(self):
        psl_cmd = ['pslMap', '-chainMapFile', self.cfg.ref_psl,
                   self.cfg.chaining.chainFile, '/dev/stdout']
        post_chain_cmd = ['bin/postTransMapChain', '/dev/stdin', '/dev/stdout']
        sort_cmd = ['sort', '-k', '14,14', '-k', '16,16n']
        recalc_cmd = ['pslRecalcMatch', '/dev/stdin', self.cfg.chaining.targetTwoBit,
                      self.cfg.transcript_fasta, 'stdout']
        uniq_cmd = ['bin/pslQueryUniq']
        cmd_list = [psl_cmd, post_chain_cmd, sort_cmd, recalc_cmd, uniq_cmd]
        self.run_cmd(cmd_list)


class TransMapGp(AbstractAtomicFileTask):
    """
    Produces the final transMapped genePred
    """
    def requires(self):
        return TransMapPsl(cfg=self.cfg, target_file=self.cfg.psl)

    def run(self):
        cmd = ['transMapPslToGenePred', '-nonCodingGapFillMax=30', '-codingGapFillMax=30',
               self.cfg.annotation_gp, self.cfg.psl, '/dev/stdout']
        self.run_cmd(cmd)


########################################################################################################################
########################################################################################################################
## comparativeAnnotator
########################################################################################################################
########################################################################################################################


class ReferenceComparativeAnnotator(AbstractJobTreeTask):
    """
    Runs transMap.
    """
    def output(self):
        r = []
        genome = self.cfg.comp_ann.ref_genome
        for table in [genome + '_Attributes', genome + '_Classify', genome + '_Details']:
            r.append(RowsSqlTarget(self.cfg.db, table, self.cfg.annotation_gp))
        return r

    def requires(self):
        return AnnotationFiles(self.cfg)

    def run(self):
        self.start_jobtree(self.cfg.comp_ann, comp_ann_main, norestart=self.cfg.args.norestart)


class ComparativeAnnotator(AbstractJobTreeTask):
    """
    Runs comparativeAnnotator.
    """
    def output(self):
        r = []
        genome = self.cfg.comp_ann.genome
        for table in [genome + '_Attributes', genome + '_Classify', genome + '_Details']:
            r.append(RowsSqlTarget(self.cfg.comp_ann.db, table, self.cfg.comp_ann.target_gp))
        return r

    def requires(self):
        return TransMap(self.cfg), GenomeFiles(self.cfg), AnnotationFiles(self.cfg.query_cfg)

    def run(self):
        self.start_jobtree(self.cfg.comp_ann, comp_ann_main, norestart=self.cfg.args.norestart)


########################################################################################################################
########################################################################################################################
## gene sets
########################################################################################################################
########################################################################################################################


class GeneSet(luigi.Task):
    """
    Produces a gtf and gp of a consensus gene set for just transMap output.
    TODO: this should be split up into individual tasks, which have a guarantee of atomicity.
    """
    cfg = luigi.Parameter()
    mode = luigi.Parameter()

    def requires(self):
        if self.mode == 'transMap':
            return ComparativeAnnotator(cfg=self.cfg), ReferenceComparativeAnnotator(cfg=self.cfg.query_cfg)
        else:
            return (AugustusComparativeAnnotator(cfg=self.cfg), AlignAugustus(cfg=self.cfg),
                    ComparativeAnnotator(cfg=self.cfg.query_target_cfg),
                    ReferenceComparativeAnnotator(cfg=self.cfg.query_cfg))

    def output(self):
        r = [luigi.LocalTarget(x) for x in itertools.chain(self.cfg.geneset_gps.values(),
                                                           self.cfg.geneset_gtfs.values())]
        r.append(luigi.LocalTarget(self.cfg.pickled_metrics))
        return r

    def convert_gp_to_gtf(self, gp, gtf):
        s = self.cfg.gene_set_name
        cmd = [['bin/fixGenePredScore', gp],
               ['genePredToGtf', '-source={}'.format(s), '-honorCdsStat', '-utr', 'file', '/dev/stdin', gtf]]
        runProc(cmd)

    def run(self):
        ensureDir(self.cfg.gene_set_dir)
        ensureDir(self.cfg.metrics_dir)
        generate_gene_set_wrapper(self.cfg)
        for gp, gtf in zip(*[self.cfg.geneset_gps.itervalues(), self.cfg.geneset_gtfs.itervalues()]):
            self.convert_gp_to_gtf(gp, gtf)
        self.convert_gp_to_gtf(self.cfg.combined_gp, self.cfg.combined_gtf)


########################################################################################################################
########################################################################################################################
## combined plots
########################################################################################################################
########################################################################################################################


class TransMapAnalysis(luigi.Task):
    """
    Analysis plots on how well transMap did. Produced based on comparativeAnnotator output.
    TODO: make this a individual luigi task for each plot
    """
    cfg = luigi.Parameter()

    def requires(self):
        r = [ReferenceComparativeAnnotator(cfg=self.cfg.query_cfg)]
        for cfg in self.cfg.query_target_cfgs.itervalues():
            r.append(ComparativeAnnotator(cfg=cfg))
        return r

    def output(self):
        r = []
        for biotype, tm_cfg in self.cfg.tm_plots.iteritems():
            for plot in tm_cfg.plots:
                r.append(luigi.LocalTarget(plot))
        return r

    def run(self):
        for biotype, tm_cfg in self.cfg.tm_plots.iteritems():
            ensureDir(tm_cfg.output_dir)
            paralogy_plot(tm_cfg.ordered_target_genomes, tm_cfg.query_genome, biotype, tm_cfg.para_plot,
                          self.cfg.db)
            cov_plot(tm_cfg.ordered_target_genomes, tm_cfg.query_genome, biotype, tm_cfg.cov_plot, self.cfg.db)
            ident_plot(tm_cfg.ordered_target_genomes, tm_cfg.query_genome, biotype, tm_cfg.ident_plot, self.cfg.db)
            num_pass_excel(tm_cfg.ordered_target_genomes, tm_cfg.query_genome, biotype, tm_cfg.num_pass_excel,
                           self.cfg.db, self.cfg.args.filterChroms)
            num_pass_excel_gene_level(tm_cfg.ordered_target_genomes, tm_cfg.query_genome, biotype,
                                      tm_cfg.num_pass_excel_gene, self.cfg.db, self.cfg.args.filterChroms)


class GeneSetPlots(luigi.Task):
    """
    Analysis plots on how well gene set finding did. Produced based on comparativeAnnotator output.
    TODO: make this a individual luigi task for each plot
    """
    cfg = luigi.Parameter()
    mode = luigi.Parameter()

    def requires(self):
        if self.mode == 'transMap':
            r = [GeneSet(cfg=x, mode=self.mode) for x in self.cfg.query_target_cfgs.itervalues()]
        else:
            r = [GeneSet(cfg=x, mode=self.mode) for x in self.cfg.augustus_cfgs.itervalues()]
        return r

    def output(self):
        if self.mode == 'transMap':
            return [luigi.LocalTarget(x) for x in self.cfg.gene_set_plots.plots]
        else:
            return [luigi.LocalTarget(x) for x in self.cfg.augustus_gene_set_plots.plots]

    def run(self):
        if self.mode == 'augustus':
            gene_set_plots(self.cfg.augustus_gene_set_plots)
        else:
            gene_set_plots(self.cfg.gene_set_plots)


########################################################################################################################
########################################################################################################################
## Augustus
########################################################################################################################
########################################################################################################################


class RunAugustus(luigi.WrapperTask):
    """
    Wrapper for AugustusTMR.
    """
    cfg = luigi.Parameter()

    def requires(self):
        yield ExtractIntronVector(cfg=self.cfg, target_file=self.cfg.vector_gp)
        yield RunAugustusTMR(cfg=self.cfg)
        yield ConvertGtfToGp(cfg=self.cfg, target_file=self.cfg.augustus_gp)
        yield AugustusComparativeAnnotator(cfg=self.cfg)
        yield ConvertGpToBed(cfg=self.cfg, target_file=self.cfg.augustus_bed)
        yield ConvertBedToFa(cfg=self.cfg, target_file=self.cfg.tmr_transcript_fasta)
        yield AlignAugustus(cfg=self.cfg)


class ExtractIntronVector(AbstractAtomicFileTask):
    """
    Extracts the intron vector information from transMap, producing a genePred with an extra column.
    """
    def requires(self):
        return ComparativeAnnotator(cfg=self.cfg.query_target_cfg)

    def run(self):
        outf = self.output().open('w')
        for line in find_intron_vector(self.cfg):
            outf.write(line)
        outf.close()


class RunAugustusTMR(AbstractJobTreeTask):
    """
    Runs AugustusTM(R) on transcripts produced by transMap.
    """
    def requires(self):
        return ExtractIntronVector(cfg=self.cfg, target_file=self.cfg.vector_gp)

    def output(self):
        return luigi.LocalTarget(self.cfg.tmr.out_gtf)

    def run(self):
        self.start_jobtree(self.cfg.tmr, augustus_tmr, norestart=self.cfg.args.norestart)


class AugustusComparativeAnnotator(AbstractJobTreeTask):
    """
    Runs augustusComparativeAnnotator.
    """
    def requires(self):
        return RunAugustusTMR(cfg=self.cfg)

    def output(self):
        r = []
        for table in [self.cfg.target_genome + '_AugustusClassify', self.cfg.target_genome + '_AugustusDetails']:
            r.append(RowsSqlTarget(self.cfg.db, table, self.cfg.augustus_gp))
        return r

    def run(self):
        self.start_jobtree(self.cfg.comp_ann, comp_ann_main, norestart=self.cfg.args.norestart)


class ConvertGtfToGp(AbstractAtomicFileTask):
    """
    Converts the output GTF from Augustus TMR to genePred.
    """
    def requires(self):
        return RunAugustusTMR(cfg=self.cfg)

    def run(self):
        cmd = ['gtfToGenePred', '-genePredExt', self.cfg.augustus_gtf, '/dev/stdout']
        self.run_cmd(cmd)


class ConvertGpToBed(AbstractAtomicFileTask):
    """
    Converts to BED
    """
    def requires(self):
        return ConvertGtfToGp(cfg=self.cfg, target_file=self.cfg.augustus_gp)

    def run(self):
        cmd = ['genePredToBed', self.cfg.augustus_gp, '/dev/stdout']
        self.run_cmd(cmd)


class ConvertBedToFa(AbstractAtomicFileTask):
    """
    Converts the TMR genePred to fasta for alignment.
    """
    def requires(self):
        return ConvertGpToBed(cfg=self.cfg, target_file=self.cfg.augustus_bed)

    def run(self):
        tmp_fa = luigi.LocalTarget(is_tmp=True)
        cmd = ['fastaFromBed', '-bed', self.cfg.augustus_bed, '-fi', self.cfg.genome_fasta, '-name',
               '-split', '-s', '-fo', tmp_fa.path]
        runProc(cmd)
        self.atomic_install(tmp_fa)


class AlignAugustus(AbstractJobTreeTask):
    """
    Aligns Augustus transcripts to reference, constructing the attributes table.
    """
    def requires(self):
        return ConvertBedToFa(cfg=self.cfg, target_file=self.cfg.tmr_transcript_fasta)

    def output(self):
        table = self.cfg.target_genome + '_AugustusAttributes'
        return RowsSqlTarget(self.cfg.db, table, self.cfg.augustus_gp)

    def run(self):
        cmd = ['pyfasta', 'flatten', self.cfg.tmr_transcript_fasta]
        runProc(cmd)  # pre-flatten the transcript fasta
        self.start_jobtree(self.cfg.align, align_augustus)
