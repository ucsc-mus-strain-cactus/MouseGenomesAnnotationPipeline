"""
Produces a configuration class for all downstream applications.
"""
import os
from lib.parsing import HashableNamespace
from frozendict import frozendict


class PipelineConfiguration(HashableNamespace):
    """
    Holds all file definitions for each source gene set.
    """
    def __init__(self, args, gene_set):
        self.args = args
        self.gene_set = gene_set
        self.biotypes = gene_set.biotypes
        self.work_dir = os.path.join(args.workDir, gene_set.sourceGenome, gene_set.geneSet)
        self.metrics_dir = os.path.join(self.work_dir, 'transMap_gene_set_metrics')
        self.output_dir = os.path.join(args.outputDir, gene_set.sourceGenome, gene_set.geneSet)
        self.jobtree_dir = os.path.join(args.jobTreeDir, gene_set.sourceGenome, gene_set.geneSet)
        self.db = os.path.join(self.work_dir, 'comparativeAnnotator', 'classification.db')
        self.target_genomes = frozenset(set(args.targetGenomes) - set([gene_set.sourceGenome]))
        self.ordered_target_genomes = tuple([x for x in gene_set.orderedTargetGenomes if x in self.target_genomes])
        self.query_cfg = QueryCfg(self)
        self.query_target_cfgs = frozendict((genome, QueryTargetCfg(self, genome)) for genome in self.target_genomes)
        self.tm_plots = frozendict((biotype, TransMapPlotCfg(self, self.query_cfg, self.query_target_cfgs, biotype))
                                   for biotype in self.biotypes)
        self.gene_set_plots = GeneSetPlotCfg(self, self.query_target_cfgs, self.metrics_dir, mode='transMap')
        if args.augustus is True:
            mode = 'AugustusTMR' if args.augustusHints is not None else 'AugustusTM'
            self.aug_metrics_dir = os.path.join(self.work_dir, '{}_consensus_gene_set_metrics'.format(mode))
            self.augustus_genomes = frozenset(set(args.augustusGenomes) - set([gene_set.sourceGenome]))
            self.ordered_augustus_genomes = tuple([x for x in gene_set.orderedTargetGenomes
                                                   if x in self.augustus_genomes])
            self.augustus_cfgs = frozendict((genome, AugustusCfg(self.query_target_cfgs[genome], genome,
                                                                 mode, self.aug_metrics_dir))
                                            for genome in self.augustus_genomes)
            self.augustus_gene_set_plots = GeneSetPlotCfg(self, self.query_target_cfgs, self.aug_metrics_dir, mode)

    def __repr__(self):
        return '{}-{}-{}'.format(self.__class__.__name__, self.gene_set.geneSet, self.gene_set.sourceGenome)


class QueryCfg(HashableNamespace):
    """
    Produces files specific to a given reference, and runs reference mode comparative annotator.
    """
    def __init__(self, cfg):
        self.mode = 'reference'
        # input arguments
        self.args = cfg.args
        self.query_genome = cfg.gene_set.sourceGenome
        self.annotation_gp = cfg.gene_set.genePred
        self.attrs_tsv = cfg.gene_set.attributesTsv
        self.gene_set_name = cfg.gene_set.geneSet
        self.work_dir = os.path.join(cfg.work_dir, 'reference_files')
        self.db = cfg.db
        self.jobtree_dir = cfg.jobtree_dir
        # transcript files
        self.bed = os.path.join(self.work_dir, '{}.bed'.format(self.gene_set_name))
        self.transcript_fasta = os.path.join(self.work_dir, '{}.fa'.format(self.gene_set_name))
        self.flat_transcript_fasta = self.transcript_fasta + '.flat'
        self.psl = os.path.join(self.work_dir, '{}.psl'.format(self.gene_set_name))
        self.cds = os.path.join(self.work_dir, '{}.cds'.format(self.gene_set_name))
        # genome files
        self.genome_work_dir = os.path.join(cfg.work_dir, 'genome_files')
        self.ref_fasta = os.path.join(self.genome_work_dir, self.query_genome + '.fa')
        self.ref_sizes = os.path.join(self.genome_work_dir, self.query_genome + '.chrom.sizes')
        self.ref_two_bit = os.path.join(self.genome_work_dir, self.query_genome + '.2bit')
        self.ref_flat_fasta = self.ref_fasta + '.flat'
        # to make QueryCfg and TargetQueryCfg compatible for production of genome files
        self.genome_fasta = self.ref_fasta
        self.genome = self.query_genome
        self.chrom_sizes = self.ref_sizes
        self.flat_fasta = self.ref_flat_fasta
        self.genome_two_bit = self.ref_two_bit
        # comparativeAnnotator
        comp_ann_jobtree = os.path.join(self.jobtree_dir, 'comparativeAnnotator', self.query_genome)
        self.comp_ann = CompAnnJobTree(self, comp_ann_jobtree, mode=self.mode)

    def __repr__(self):
        return '{}: {} ({})'.format(self.__class__.__name__, self.query_genome, self.gene_set_name)


class QueryTargetCfg(HashableNamespace):
    """
    Holds all file definitions for every comnbination of gene_set + genome
    """
    def __init__(self, cfg, target_genome):
        # input arguments
        self.query_cfg = cfg.query_cfg
        self.mode = 'transMap'
        self.args = cfg.args
        self.hal = self.args.hal
        self.ref_fasta = cfg.query_cfg.ref_fasta
        self.ref_two_bit = cfg.query_cfg.ref_two_bit
        self.ref_sizes = cfg.query_cfg.ref_sizes
        self.ref_psl = cfg.query_cfg.psl
        self.ref_cds = cfg.query_cfg.cds
        self.annotation_gp = cfg.gene_set.genePred
        self.transcript_fasta = cfg.query_cfg.transcript_fasta
        self.flat_transcript_fasta = self.transcript_fasta + '.flat'
        self.target_genome = target_genome
        self.query_genome = cfg.gene_set.sourceGenome
        self.attrs_tsv = cfg.gene_set.attributesTsv
        self.gene_set_name = cfg.gene_set.geneSet
        self.db = cfg.db
        self.jobtree_dir = cfg.jobtree_dir
        self.output_dir = cfg.output_dir
        self.work_dir = cfg.work_dir
        self.metrics_dir = cfg.metrics_dir
        self.biotypes = cfg.biotypes
        # genome files
        self.genome_work_dir = os.path.join(cfg.work_dir, 'genome_files')
        self.genome_fasta = os.path.join(self.genome_work_dir, target_genome + '.fa')
        self.genome_two_bit = os.path.join(self.genome_work_dir, target_genome + '.2bit')
        self.chrom_sizes = os.path.join(self.genome_work_dir, target_genome + '.chrom.sizes')
        self.flat_fasta = self.genome_fasta + '.flat'
        # to make QueryCfg and TargetQueryCfg compatible for production of genome files
        self.genome = self.target_genome
        # chaining config (passed to jobTree)
        self.chaining = ChainingCfg(self)
        # transMap
        self.tm_work_dir = os.path.join(cfg.work_dir, 'transMap')
        self.psl = os.path.join(self.tm_work_dir, target_genome + '.psl')
        self.gp = os.path.join(self.tm_work_dir, target_genome + '.gp')
        self.bed = os.path.join(self.tm_work_dir, target_genome + '.bed')
        # comparativeAnnotator
        comp_ann_jobtree = os.path.join(self.jobtree_dir, 'comparativeAnnotator', self.target_genome)
        self.comp_ann = CompAnnJobTree(self, comp_ann_jobtree, mode=self.mode)
        # final gene set
        self.gene_set_dir = os.path.join(self.output_dir, 'transMap_gene_set', target_genome)
        self.geneset_gps = frozendict((x, os.path.join(self.gene_set_dir, x + '.gp')) for x in self.biotypes)
        self.combined_gp = os.path.join(self.gene_set_dir, 'combined.gp')
        self.combined_gtf = os.path.join(self.gene_set_dir, 'combined.gtf')
        self.geneset_gtfs = frozendict((x, os.path.join(self.gene_set_dir, x + '.gtf')) for x in self.biotypes)
        self.pickled_metrics = os.path.join(self.metrics_dir, '{}.pickle'.format(target_genome))
        self.filter_chroms = self.args.filterChroms

    def __repr__(self):
        return '{}: {}->{} ({})'.format(self.__class__.__name__, self.query_genome, self.target_genome,
                                        self.gene_set_name)


class AugustusCfg(HashableNamespace):
    """
    Holds all file definitions for every comnbination of gene_set + genome
    """
    def __init__(self, cfg, target_genome, mode, metrics_dir):
        self.__dict__.update(vars(cfg))  # bring in all configurations from query-target
        self.query_target_cfg = cfg
        self.query_cfg = cfg.query_cfg
        self.query_genome = cfg.query_genome
        self.gene_set_name = cfg.gene_set_name
        self.mode = mode
        self.args = cfg.args
        self.target_genome = target_genome
        self.fasta = cfg.genome_fasta
        self.chrom_sizes = cfg.chrom_sizes
        self.transcript_fasta = cfg.transcript_fasta
        # files that will be produced
        self.augustus_gtf = os.path.join(cfg.work_dir, mode, target_genome + '.gtf')
        self.augustus_gp = os.path.join(cfg.work_dir, mode, target_genome + '.gp')
        self.augustus_bed = os.path.join(cfg.work_dir, mode, target_genome + '.bed')
        self.tmr_transcript_fasta = os.path.join(cfg.work_dir, mode, target_genome + '.transcripts.fa')
        self.vector_gp = os.path.join(cfg.work_dir, mode, target_genome + '.vector.gp')
        # run augustus
        tmr_jobtree = os.path.join(self.jobtree_dir, mode, self.target_genome)
        self.tmr = TMRJobTree(self, tmr_jobtree)
        # align augustus
        align_jobtree = os.path.join(self.jobtree_dir, 'align' + mode, self.target_genome)
        self.align = AlignAugustusJobTree(self, align_jobtree)
        # comparative Annotator
        aug_comp_ann_jobtree = os.path.join(self.jobtree_dir, 'augustusComparativeAnnotator', self.target_genome)
        self.comp_ann = CompAnnJobTree(self, aug_comp_ann_jobtree, mode='augustus')
        # consensus gene set
        self.gene_set_dir = os.path.join(self.output_dir, '{}_consensus_gene_set'.format(mode), target_genome)
        self.geneset_gps = frozendict((x, os.path.join(self.gene_set_dir, x + '.gp')) for x in self.biotypes)
        self.combined_gp = os.path.join(self.gene_set_dir, 'combined.gp')
        self.combined_gtf = os.path.join(self.gene_set_dir, 'combined.gtf')
        self.geneset_gtfs = frozendict((x, os.path.join(self.gene_set_dir, x + '.gtf')) for x in self.biotypes)
        self.metrics_dir = metrics_dir
        self.pickled_metrics = os.path.join(self.metrics_dir, '{}.pickle'.format(target_genome))

    def __repr__(self):
        return '{}: {}->{} ({})'.format(self.__class__.__name__, self.query_genome, self.target_genome,
                                        self.gene_set_name)


########################################################################################################################
# Configuration objects passed directly to jobTree portions of the pipeline
########################################################################################################################


class ChainingCfg(HashableNamespace):
    """
    Produces chain/net files from a hal alignment.
    Using camelCase here to interface with Mark's code.
    """
    def __init__(self, query_tgt_cfg):
        args = query_tgt_cfg.args
        self.__dict__.update(vars(args.jobTreeOptions))  # add jobTree options to this cfg
        self.defaultMemory = 16 * 1024 ** 3
        self.targetGenome = query_tgt_cfg.target_genome
        self.queryGenome = query_tgt_cfg.query_genome
        self.queryTwoBit = query_tgt_cfg.ref_two_bit
        self.targetTwoBit = query_tgt_cfg.genome_two_bit
        self.out_dir = os.path.join(args.workDir, 'chaining')
        self.hal = args.hal
        self.chainFile = os.path.join(self.out_dir, '{}_{}.chain.gz'.format(self.queryGenome, self.targetGenome))
        self.netFile = os.path.join(self.out_dir, '{}_{}.net.gz'.format(self.queryGenome, self.targetGenome))
        self.jobTree = os.path.join(query_tgt_cfg.jobtree_dir, 'chaining', '{}_{}'.format(self.queryGenome,
                                                                                          self.targetGenome))

    def __repr__(self):
        return '{}: {}->{}'.format(self.__class__.__name__, self.queryGenome, self.targetGenome)


class CompAnnJobTree(HashableNamespace):
    """
    Run comparativeAnnotator in any of its modes
    """
    def __init__(self, cfg, jobtree_dir, mode):
        args = cfg.args
        self.__dict__.update(vars(args.jobTreeOptions))
        self.defaultMemory = 8 * 1024 ** 3
        self.mode = mode
        self.db = cfg.db
        self.jobTree = jobtree_dir
        self.ref_genome = cfg.query_genome
        self.ref_fasta = cfg.ref_fasta
        self.sizes = cfg.ref_sizes
        self.annotation_gp = cfg.annotation_gp
        self.gencode_attributes = cfg.attrs_tsv
        self.gene_set_name = cfg.gene_set_name
        if mode == 'transMap' or mode == 'augustus':
            self.ref_psl = cfg.ref_psl
            self.psl = cfg.psl
            self.genome = cfg.target_genome
            self.target_gp = cfg.gp
            self.fasta = cfg.genome_fasta
        if mode == 'augustus':
            self.augustus_gp = cfg.augustus_gp

    def __repr__(self):
        return self.mode + self.__class__.__name__


class TMRJobTree(HashableNamespace):
    """
    The args object that will be passed directly to jobTree
    """
    def __init__(self, cfg, jobtree_dir):
        args = cfg.args
        self.__dict__.update(vars(args.jobTreeOptions))
        self.defaultMemory = 8 * 1024 ** 3
        self.jobTree = jobtree_dir
        tm_2_hints_script = 'submodules/comparativeAnnotator/augustus/transMap2hints.pl'  # TODO: don't hardcode
        assert os.path.exists(tm_2_hints_script)
        tm_2_hints_params = ("--ep_cutoff=0 --ep_margin=12 --min_intron_len=40 --start_stop_radius=5 --tss_tts_radius=5"
                             " --utrend_cutoff=6 --in=/dev/stdin --out=/dev/stdout")
        self.tm_2_hints_cmd = " ".join([tm_2_hints_script, tm_2_hints_params])
        # can we run TMR or just TM?
        self.cfgs = {1: "submodules/comparativeAnnotator/augustus/extrinsic.ETM1.cfg"}
        if args.augustusHints is not None:
            self.cfgs[2] = "submodules/comparativeAnnotator/augustus/extrinsic.ETM2.cfg"
        self.cfgs = frozendict(self.cfgs)
        assert all([os.path.exists(x) for x in self.cfgs.itervalues()])
        self.augustus_bin = 'submodules/augustus/bin/augustus'
        assert os.path.exists(self.augustus_bin)
        self.padding = 20000
        self.max_gene_size = 3000000
        self.hints_db = args.augustusHints
        self.out_gtf = cfg.augustus_gtf
        self.genome = cfg.target_genome
        self.fasta = cfg.fasta
        self.chrom_sizes = cfg.chrom_sizes
        self.input_gp = cfg.vector_gp

    def __repr__(self):
        return self.__class__.__name__


class AlignAugustusJobTree(HashableNamespace):
    """
    The args object that will be passed directly to jobTree
    """
    def __init__(self, cfg, jobtree_dir):
        args = cfg.args
        self.__dict__.update(vars(args.jobTreeOptions))
        self.jobTree = jobtree_dir
        self.genome = cfg.target_genome
        self.fasta = cfg.tmr_transcript_fasta
        self.ref_fasta = cfg.transcript_fasta
        self.db = cfg.db
        self.augustus_gp = cfg.augustus_gp

    def __repr__(self):
        return self.__class__.__name__


########################################################################################################################
# Configuration for shared analyses
########################################################################################################################

class TransMapPlotCfg(HashableNamespace):
    """
    Takes the initial configuration from the main driver script and builds paths to all files that will be produced
    by these tasks.
    """
    def __init__(self, cfg, query_cfg, query_target_cfgs, biotype):
        self.args = cfg.args
        self.query_cfg = query_cfg
        self.query_target_cfgs = query_target_cfgs
        self.gene_set = cfg.gene_set
        self.query_genome = self.gene_set.sourceGenome
        self.ordered_target_genomes = cfg.ordered_target_genomes
        self.biotype = biotype
        self.output_dir = os.path.join(cfg.output_dir, 'transMap_plots', biotype)
        self.para_plot = os.path.join(self.output_dir, biotype + '_alignment_paralogy.pdf')
        self.ident_plot = os.path.join(self.output_dir, biotype + '_alignment_identity.pdf')
        self.cov_plot = os.path.join(self.output_dir, biotype + '_alignment_coverage.pdf')
        self.num_pass_excel = os.path.join(self.output_dir, biotype + '_alignment_num_pass_excel.pdf')
        self.num_pass_excel_gene = os.path.join(self.output_dir, biotype + '_alignment_num_pass_excel_gene.pdf')
        self.plots = tuple([self.para_plot, self.ident_plot, self.cov_plot, self.num_pass_excel,
                           self.num_pass_excel_gene])

    def __repr__(self):
        return self.__class__.__name__


class GeneSetPlotCfg(HashableNamespace):
    """
    Takes the initial configuration from the main driver script and builds paths to all files that will be produced
    by these tasks.
    """
    class BiotypeGeneSetPlotConfig(HashableNamespace):
        def __init__(self, biotype, gene_set_plot_dir):
            self.biotype = biotype
            self.out_dir = gene_set_plot_dir
            self.tx_plot = os.path.join(self.out_dir, biotype, biotype + '_transcript_plot.pdf')
            self.gene_plot = os.path.join(self.out_dir, biotype, biotype + '_gene_plot.pdf')
            self.dup_rate_plot = os.path.join(self.out_dir, biotype, biotype + '_dup_rate_plot.pdf')
            self.longest_rate_plot = os.path.join(self.out_dir, biotype, biotype + '_longest_rescue_rate.pdf')
            self.plots = tuple([self.tx_plot, self.gene_plot, self.dup_rate_plot, self.longest_rate_plot])

    def __init__(self, cfg, query_tgt_cfgs, metrics_dir, mode):
        self.mode = mode
        self.gene_set_plot_dir = os.path.join(cfg.output_dir, '{}_gene_set_plots'.format(mode))
        self.query_tgt_cfgs = query_tgt_cfgs
        self.metrics_dir = metrics_dir
        self.biotypes = cfg.biotypes
        self.gene_set = cfg.gene_set
        if mode == 'transMap':
            self.ordered_target_genomes = cfg.ordered_target_genomes
        elif mode == 'AugustusTM' or mode == 'AugustusTMR':
            self.ordered_target_genomes = cfg.ordered_augustus_genomes
        else:
            raise NotImplementedError("mode = {}".format(mode))
        self.gene_biotype_plot = os.path.join(self.gene_set_plot_dir, 'gene_biotype_stacked_plot.pdf')
        self.transcript_biotype_plot = os.path.join(self.gene_set_plot_dir, 'transcript_biotype_stacked_plot.pdf')
        self.biotype_plots = frozendict((b, self.BiotypeGeneSetPlotConfig(b, self.gene_set_plot_dir))
                                        for b in self.biotypes)
        plots = [self.gene_biotype_plot, self.transcript_biotype_plot]
        for biotype_plt_cfg in self.biotype_plots.itervalues():
            plots.extend(biotype_plt_cfg.plots)
        self.plots = tuple(plots)

    def __repr__(self):
        return self.__class__.__name__
