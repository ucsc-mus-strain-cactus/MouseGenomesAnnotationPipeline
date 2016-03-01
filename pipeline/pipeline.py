"""
Run the pipeline
"""
import luigi
import itertools
from pycbio.sys.procOps import runProc
from pycbio.sys.fileOps import ensureDir
from lib.ucsc_chain_net import chainNetStartup
from abstract_classes import AbstractAtomicFileTask, AbstractAtomicManyFileTask, AbstractJobTreeTask
from abstract_classes import RowsSqlTarget
from comparativeAnnotator.annotation_pipeline import main as comp_ann_main
from comparativeAnnotator.plotting.transmap_analysis import paralogy_plot, cov_plot, ident_plot, num_pass_excel,\
    num_pass_excel_gene_level
from comparativeAnnotator.generate_gene_set import generate_consensus
from comparativeAnnotator.plotting.gene_set_plots import gene_set_plots
from comparativeAnnotator.augustus.run_augustus import augustus_tmr
from comparativeAnnotator.augustus.find_intron_vector import find_intron_vector
from comparativeAnnotator.augustus.align_augustus import align_augustus

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
                GenomeFasta(cfg=self.genome_cfg, target_file=self.genome_cfg.genome_fasta))

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
    def output(self):
        return luigi.LocalTarget(self.cfg.chaining.chainFile), luigi.LocalTarget(self.cfg.chaining.netFile)

    def requires(self):
        return (GenomeTwoBit(cfg=self.cfg.target_genome_files, target_file=self.cfg.target_genome_files.genome_two_bit),
                GenomeTwoBit(cfg=self.cfg.query_genome_files, target_file=self.cfg.query_genome_files.genome_two_bit))

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
               '-cdsFile={}'.format(self.cfg.annot_files.cds), self.cfg.transmap.psl, '/dev/stdout']
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
            r.append(RowsSqlTarget(self.cfg.comp_ann.db, table, self.cfg.comp_ann.annotation_gp))
        return r

    def requires(self):
        return GenomeFiles(self.cfg), AnnotationFiles(self.cfg)

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
        return TransMap(self.cfg), GenomeFiles(self.cfg), AnnotationFiles(self.cfg)

    def run(self):
        self.start_jobtree(self.cfg.comp_ann, comp_ann_main, norestart=self.cfg.args.norestart)


########################################################################################################################
########################################################################################################################
## gene sets
########################################################################################################################
########################################################################################################################


class TransMapGeneSet(luigi.Task):
    """
    Produces a gtf and gp of a consensus gene set for just transMap output.
    TODO: this should be split up into individual tasks, which have a guarantee of atomicity.
    """
    cfg = luigi.Parameter()

    def requires(self):
        return ComparativeAnnotator(cfg=self.cfg)

    def output(self):
        return (luigi.LocalTarget(x) for x in itertools.chain(self.cfg.geneset.out_gps.values(),
                                                              self.cfg.geneset.out_gtfs.values()))

    def convert_gp_to_gtf(self, gps, gtfs):
        for gp, gtf in zip(*[gps.itervalues(), gtfs.itervalues()]):
            s = self.cfg.geneset.gene_set_name
            cmd = [['bin/fixGenePredScore', gp],
                   ['genePredToGtf', '-source={}'.format(s), '-honorCdsStat', '-utr', 'file', '/dev/stdin', gtf]]
            runProc(cmd)

    def run(self):
        ensureDir(self.cfg.geneset.out_dir)
        ensureDir(self.cfg.geneset.tmp_dir)
        generate_consensus(self.cfg.geneset)
        self.convert_gp_to_gtf(self.cfg.geneset.out_gps, self.cfg.geneset.out_gtfs)


class AugustusGeneSet(luigi.Task):
    """
    Produces a gtf and gp of a consensus gene set for just transMap output.
    TODO: this should be split up into individual tasks, which have a guarantee of atomicity.
    """
    cfg = luigi.Parameter()

    def requires(self):
        return ComparativeAnnotator(cfg=self.cfg)

    def output(self):
        return (luigi.LocalTarget(x) for x in itertools.chain(self.cfg.tmr.aug_geneset.out_gps.values(),
                                                              self.cfg.tmr.aug_geneset.out_gtfs.values()))

    def convert_gp_to_gtf(self, gps, gtfs):
        for gp, gtf in zip(*[gps.itervalues(), gtfs.itervalues()]):
            s = self.cfg.aug_geneset.gene_set_name
            cmd = [['bin/fixGenePredScore', gp],
                   ['genePredToGtf', '-source={}'.format(s), '-honorCdsStat', '-utr', 'file', '/dev/stdin', gtf]]
            runProc(cmd)

    def run(self):
        ensureDir(self.cfg.tmr.aug_geneset.out_dir)
        ensureDir(self.cfg.tmr.aug_geneset.tmp_dir)
        generate_consensus(self.cfg.tmr.aug_geneset)
        self.convert_gp_to_gtf(self.cfg.tmr.aug_geneset.out_gps, self.cfg.tmr.aug_geneset.out_gtfs)


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
        r = []
        for cfg in self.cfg.cfgs:
            if cfg.query_genome == cfg.target_genome:
                r.append(ReferenceComparativeAnnotator(cfg=cfg))
            else:
                r.append(ComparativeAnnotator(cfg=cfg))
        return r

    def output(self):
        r = []
        for tm_plot in self.cfg.tm_plots.itervalues():
            for plot in tm_plot.plots:
                r.append(luigi.LocalTarget(plot))
        return r

    def run(self):
        for biotype, tm_cfg in self.cfg.tm_plots.iteritems():
            ensureDir(tm_cfg.out_dir)
            paralogy_plot(self.cfg.target_genomes, self.cfg.query_genome, biotype, tm_cfg.para_plot, 
                          self.cfg.db)
            cov_plot(self.cfg.target_genomes, self.cfg.query_genome, biotype, tm_cfg.cov_plot, self.cfg.db)
            ident_plot(self.cfg.target_genomes, self.cfg.query_genome, biotype, tm_cfg.ident_plot, self.cfg.db)
            num_pass_excel(self.cfg.target_genomes, self.cfg.query_genome, biotype, tm_cfg.num_pass_excel,
                           self.cfg.db, self.cfg.args.filterChroms)
            num_pass_excel_gene_level(self.cfg.target_genomes, self.cfg.query_genome, biotype,
                                      tm_cfg.num_pass_excel_gene, self.cfg.db, self.cfg.args.filterChroms)


class TransMapGeneSetPlots(luigi.Task):
    """
    Analysis plots on how well transMap gene set finding did. Produced based on comparativeAnnotator output.
    TODO: make this a individual luigi task for each plot
    """
    cfg = luigi.Parameter()

    def requires(self):
        r = []
        for cfg in self.cfg.cfgs:
            if cfg.query_genome != cfg.target_genome:
                r.append(TransMapGeneSet(cfg=cfg))
        return r

    def output(self):
        r = [luigi.LocalTarget(self.cfg.transcript_biotype_plot), luigi.LocalTarget(self.cfg.gene_biotype_plot)]
        for tm_plot in self.cfg.tm_gene_set_plots.itervalues():
            for plot in tm_plot.plots:
                r.append(luigi.LocalTarget(plot))
        return r

    def run(self):
        gene_set_plots(self.cfg)


class AugustusGeneSetPlots(luigi.Task):
    """
    Analysis plots on how well transMap gene set finding did. Produced based on comparativeAnnotator output.
    TODO: make this a individual luigi task for each plot
    """
    cfg = luigi.Parameter()

    def requires(self):
        r = []
        for cfg in self.cfg.cfgs:
            if cfg.query_genome != cfg.target_genome:
                r.append(TransMapGeneSet(cfg=cfg))
        return r

    def output(self):
        r = [luigi.LocalTarget(self.cfg.transcript_biotype_plot), luigi.LocalTarget(self.cfg.gene_biotype_plot)]
        for tm_plot in self.cfg.tm_gene_set_plots.itervalues():
            for plot in tm_plot.plots:
                r.append(luigi.LocalTarget(plot))
        return r

    def run(self):
        gene_set_plots(self.cfg)


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
        yield ExtractIntronVector(cfg=self.cfg, target_file=self.cfg.tmr.vector_gp)
        yield RunAugustusTMR(cfg=self.cfg)
        yield ConvertGtfToGp(cfg=self.cfg, target_file=self.cfg.tmr.out_gp)
        yield AugustusComparativeAnnotator(cfg=self.cfg)
        yield ConvertGpToBed(cfg=self.cfg, target_file=self.cfg.tmr.tmr_bed)
        yield ConvertBedToFa(cfg=self.cfg, target_file=self.cfg.tmr.tmr_fa)
        yield AlignAugustus(cfg=self.cfg)


class ExtractIntronVector(AbstractAtomicFileTask):
    """
    Extracts the intron vector information from transMap, producing a genePred with an extra column.
    """
    def requires(self):
        return ComparativeAnnotator(cfg=self.cfg)

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
        return ExtractIntronVector(cfg=self.cfg, target_file=self.cfg.tmr.vector_gp)

    def output(self):
        return luigi.LocalTarget(self.cfg.tmr.out_gtf)

    def run(self):
        self.start_jobtree(self.cfg.tmr.run_tmr, augustus_tmr, norestart=self.cfg.args.norestart)


class AugustusComparativeAnnotator(AbstractJobTreeTask):
    """
    Runs augustusComparativeAnnotator.
    """
    def requires(self):
        return RunAugustusTMR(cfg=self.cfg)

    def output(self):
        r = []
        genome = self.cfg.tmr.comp_ann_tm.genome
        for table in [genome + '_AugustusClassify', genome + '_AugustusDetails']:
            r.append(RowsSqlTarget(self.cfg.tmr.comp_ann_tm.db, table, self.cfg.tmr.comp_ann_tm.augustus_gp))
        return r

    def run(self):
        self.start_jobtree(self.cfg.tmr.comp_ann_tm, comp_ann_main, norestart=self.cfg.args.norestart)


class ConvertGtfToGp(AbstractAtomicFileTask):
    """
    Converts the output GTF from Augustus TMR to genePred.
    """
    def requires(self):
        return RunAugustusTMR(cfg=self.cfg)

    def run(self):
        cmd = ['gtfToGenePred', '-genePredExt', self.cfg.tmr.out_gtf, '/dev/stdout']
        self.run_cmd(cmd)


class ConvertGpToBed(AbstractAtomicFileTask):
    """
    Converts to BED
    """
    def requires(self):
        return ConvertGtfToGp(cfg=self.cfg, target_file=self.cfg.tmr.out_gp)

    def run(self):
        cmd = ['genePredToBed', self.cfg.tmr.out_gp, '/dev/stdout']
        self.run_cmd(cmd)


class ConvertBedToFa(AbstractAtomicFileTask):
    """
    Converts the TMR genePred to fasta for alignment.
    """
    def requires(self):
        return ConvertGpToBed(cfg=self.cfg, target_file=self.cfg.tmr.tmr_bed)

    def run(self):
        tmp_fa = luigi.LocalTarget(is_tmp=True)
        cmd = ['fastaFromBed', '-bed', self.cfg.tmr.tmr_bed, '-fi', self.cfg.tmr.fasta, '-name',
               '-split', '-s', '-fo', tmp_fa.path]
        runProc(cmd)
        self.atomic_install(tmp_fa)


class AlignAugustus(AbstractJobTreeTask):
    """
    Aligns Augustus transcripts to reference, constructing the attributes table.
    """
    def requires(self):
        return ConvertBedToFa(cfg=self.cfg)

    def output(self):
        table = self.cfg.target_genome + '_AugustusAttributes'
        return RowsSqlTarget(self.cfg.comp_ann_tm.db, table, self.cfg.comp_ann_tm.augustus_gp)

    def run(self):
        cmd = ['pyfasta', 'flatten', self.cfg.tmr.tmr_fa]
        runProc(cmd)
        self.start_jobtree(self.cfg.tmr.align, align_augustus)
