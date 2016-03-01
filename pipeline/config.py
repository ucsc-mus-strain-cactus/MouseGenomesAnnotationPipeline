"""
Produces a configuration class for all downstream applications.
"""
import os
from lib.parsing import HashableNamespace
from frozendict import frozendict


class QueryTargetConfiguration(HashableNamespace):
    """
    Builds a huge namespace denoting every file produced for a combination of geneset-genome.
    """
    def __init__(self, args, query_genome, target_genome, gene_set):
        self.args = args
        self.hal = args.hal
        self.query_genome = query_genome
        self.target_genome = target_genome
        self.gene_set = gene_set
        self.target_genome_files = GenomeFileConfiguration(args, target_genome)
        self.query_genome_files = GenomeFileConfiguration(args, query_genome)
        self.annot_files = AnnotationFileConfiguration(args, gene_set)
        self.chaining = ChainingFileConfiguration(args, target_genome, query_genome,
                                                  self.target_genome_files.genome_two_bit,
                                                  self.query_genome_files.genome_two_bit)
        self.transmap = TransMapConfiguration(args, target_genome, query_genome,
                                              self.target_genome_files.genome_two_bit,
                                              self.query_genome_files.genome_two_bit, gene_set)
        if self.query_genome == self.target_genome:
            self.comp_ann = CompAnnReferenceConfiguration(args, self.gene_set, self.query_genome_files,
                                                          self.annot_files)
        else:
            self.comp_ann = CompAnnTransMapConfiguration(args, self.query_genome_files, self.target_genome_files,
                                                         self.annot_files, self.transmap, gene_set)
            self.geneset = TransMapGeneSet(args, self.comp_ann, gene_set)
        if self.args.augustus is True:
            self.tmr = AugustusTMR(self.args, self.transmap, self.gene_set, self.target_genome,
                                   self.target_genome_files, self.annot_files)

    def __repr__(self):
        return '{}: {}-{} ({})'.format(self.__class__.__name__, self.query_genome, self.target_genome, self.gene_set)


class GenomeFileConfiguration(HashableNamespace):
    """
    General genome files.
    """
    def __init__(self, args, genome):
        self.genome = genome
        self.hal = args.hal
        self.target_dir = os.path.join(args.workDir, 'genome_files', genome)
        self.genome_fasta = os.path.join(self.target_dir, genome + '.fa')
        self.genome_two_bit = os.path.join(self.target_dir, genome + '.2bit')
        self.chrom_sizes = os.path.join(self.target_dir, genome + '.chrom.sizes')
        self.flat_fasta = self.genome_fasta + '.flat'


class AnnotationFileConfiguration(HashableNamespace):
    """
    Produces files specific to each source annotation set, including a transcriptome fasta, a transcript bed,
    and a fake psl that will be projected by transMap.
    """
    def __init__(self, args, gene_set):
        self.__dict__.update(vars(gene_set))  # add this gene set
        self.hal = args.hal
        base_source_dir = os.path.join(args.workDir, 'annotation_files', self.sourceGenome, self.geneSet)
        base_gene_set = os.path.splitext(os.path.basename(self.genePred))[0]
        base_out_path = os.path.join(base_source_dir, base_gene_set)
        self.gp = base_out_path + '.gp'  # genePred will be copied to this directory too for simplicity
        self.attributes = base_out_path + '.tsv'
        self.bed = base_out_path + '.bed'
        self.transcript_fasta = base_out_path + '.fa'
        self.flat_transcript_fasta = self.transcript_fasta + '.flat'
        self.psl = base_out_path + '.psl'
        self.cds = base_out_path + '.cds'


class ChainingFileConfiguration(HashableNamespace):
    """
    Produces chain/net files from a hal alignment.
    Using camelCase here to interface with Mark's code.
    """
    def __init__(self, args, target_genome, query_genome, target_two_bit, query_two_bit):
        self.__dict__.update(vars(args.jobTreeOptions))  # add jobTree options to this cfg
        self.targetGenome = target_genome
        self.queryGenome = query_genome
        self.queryTwoBit = query_two_bit
        self.targetTwoBit = target_two_bit
        self.out_dir = os.path.join(args.workDir, 'chaining')
        self.hal = args.hal
        self.chainFile = os.path.join(self.out_dir, '{}_{}.chain.gz'.format(query_genome, target_genome))
        self.netFile = os.path.join(self.out_dir, '{}_{}.net.gz'.format(query_genome, target_genome))
        self.jobTree = os.path.join(args.jobTreeDir, 'chaining', '{}_{}'.format(query_genome, target_genome))


class TransMapConfiguration(HashableNamespace):
    """
    Takes the initial configuration from the main driver script and builds paths to all files that will be produced
    by these tasks.
    """
    def __init__(self, args, target_genome, query_genome, target_two_bit, query_two_bit, gene_set):
        self.chain_cfg = ChainingFileConfiguration(args, target_genome, query_genome, target_two_bit, query_two_bit)
        self.annot_cfg = AnnotationFileConfiguration(args, gene_set)
        tm_dir = os.path.join(args.workDir, 'transMap', gene_set.sourceGenome, gene_set.geneSet)
        self.psl = os.path.join(tm_dir, target_genome + '.psl')
        self.gp = os.path.join(tm_dir, target_genome + '.gp')


class CompAnnReferenceConfiguration(HashableNamespace):
    """
    The args object that will be passed directly to jobTree
    """
    def __init__(self, args, gene_set, query_genome_files, annot_files):
        self.__dict__.update(vars(args.jobTreeOptions))
        self.ref_genome = query_genome_files.genome
        self.ref_fasta = query_genome_files.genome_fasta
        self.ref_psl = annot_files.psl
        self.sizes = query_genome_files.chrom_sizes
        self.annotation_gp = annot_files.gp
        self.gencode_attributes = annot_files.attributes
        self.mode = 'reference'
        self.db = os.path.join(args.workDir, 'comparativeAnnotator', gene_set.sourceGenome, gene_set.geneSet,
                               'classification.db')
        self.jobTree = os.path.join(args.jobTreeDir, 'comparativeAnnotator', gene_set.sourceGenome, gene_set.geneSet,
                                    self.ref_genome)


class CompAnnTransMapConfiguration(CompAnnReferenceConfiguration):
    """
    The args object that will be passed directly to jobTree
    """
    def __init__(self, args, query_genome_files, target_genome_files, annot_files, transmap, gene_set):
        super(CompAnnTransMapConfiguration, self).__init__(args, gene_set, query_genome_files, annot_files)
        self.genome = target_genome_files.genome
        self.psl = transmap.psl
        self.target_gp = transmap.gp
        self.fasta = target_genome_files.genome_fasta
        self.mode = 'transMap'
        self.jobTree = os.path.join(args.jobTreeDir, 'comparativeAnnotator', gene_set.sourceGenome, gene_set.geneSet,
                                    self.genome)


class TransMapGeneSet(HashableNamespace):
    """
    Produces a gene set from transMap alignments, taking into account classifications.
    """
    def __init__(self, args, comp_ann, gene_set):
        self.args = args
        self.filter_chroms = args.filterChroms
        self.genome = comp_ann.genome
        self.ref_genome = gene_set.sourceGenome
        self.target_gp = comp_ann.target_gp
        self.annotation_gp = comp_ann.annotation_gp
        self.db_path = comp_ann.db
        self.biotypes = gene_set.biotypes
        self.mode = 'transMap'
        self.gene_set_name = gene_set.geneSet
        self.out_dir = os.path.join(args.outputDir, 'transMap_gene_set', gene_set.sourceGenome, gene_set.geneSet,
                                    self.genome)
        self.out_gps = frozendict((x, os.path.join(self.out_dir, x + '.gp')) for x in gene_set.biotypes)
        self.out_gtfs = frozendict((x, os.path.join(self.out_dir, x + '.gtf')) for x in gene_set.biotypes)
        self.tmp_dir = os.path.join(args.workDir, 'transMap_gene_set_metrics', gene_set.sourceGenome, gene_set.geneSet)
        self.tmp_pickle = os.path.join(self.tmp_dir, self.genome + '.metrics.pickle')


########################################################################################################################
########################################################################################################################
## Configuration for shared analyses
########################################################################################################################
########################################################################################################################


class AnalysesConfiguration(HashableNamespace):
    """
    Takes the initial configuration and builds paths to files that are shared between analyses. Mostly plots.
    """
    def __init__(self, args, cfgs, gene_set):
        self.args = args
        self.cfgs = cfgs
        self.biotypes = gene_set.biotypes
        self.query_genome = gene_set.sourceGenome
        self.target_genomes = gene_set.orderedTargetGenomes
        self.db = os.path.join(args.workDir, 'comparativeAnnotator', gene_set.sourceGenome, gene_set.geneSet,
                               'classification.db')
        self.gene_set = gene_set
        self.tm_plots = frozendict([b, TransMapPlots(args, gene_set, b)] for b in self.biotypes)
        self.gene_set_plot_dir = os.path.join(args.outputDir, 'transMap_GeneSet_plots')
        self.gene_biotype_plot = os.path.join(self.gene_set_plot_dir, 'gene_biotype_stacked_plot.pdf')
        self.transcript_biotype_plot = os.path.join(self.gene_set_plot_dir, 'transcript_biotype_stacked_plot.pdf')
        self.tm_gene_set_plots = frozendict([b, GeneSetPlotsConfig(args, gene_set, b, self.gene_set_plot_dir)]
                                            for b in self.biotypes)
        self.pickle_dir = os.path.join(args.workDir, 'transMap_gene_set_metrics', gene_set.sourceGenome,
                                       gene_set.geneSet)
        if args.augustus is True:
            p = 'AugustusTMR' if args.augustusHints is not None else 'AugustusTM'
            self.aug_gene_set_plot_dir = os.path.join(args.outputDir, '{}_GeneSet_plots'.format(p))
            self.aug_gene_set_plots = frozendict([b, GeneSetPlotsConfig(args, gene_set, b, self.aug_gene_set_plot_dir)]
                                                 for b in self.biotypes)

    def __repr__(self):
        return 'AnalysesConfiguration: {}-{}'.format(self.gene_set.sourceGenome, self.gene_set.geneSet)


class TransMapPlots(HashableNamespace):
    """
    Takes the initial configuration from the main driver script and builds paths to all files that will be produced
    by these tasks.
    """
    def __init__(self, args, gene_set, biotype):
        self.args = args
        self.gene_set = gene_set
        self.biotype = biotype
        self.out_dir = os.path.join(args.outputDir, 'transMap_plots', biotype)
        self.para_plot = os.path.join(self.out_dir, biotype + '_alignment_paralogy.pdf')
        self.ident_plot = os.path.join(self.out_dir, biotype + '_alignment_identity.pdf')
        self.cov_plot = os.path.join(self.out_dir, biotype + '_alignment_coverage.pdf')
        self.num_pass_excel = os.path.join(self.out_dir, biotype + '_alignment_num_pass_excel.pdf')
        self.num_pass_excel_gene = os.path.join(self.out_dir, biotype + '_alignment_num_pass_excel_gene.pdf')
        self.plots = tuple([self.para_plot, self.ident_plot, self.cov_plot, self.num_pass_excel,
                           self.num_pass_excel_gene])


class GeneSetPlotsConfig(HashableNamespace):
    """
    Takes the initial configuration from the main driver script and builds paths to all files that will be produced
    by these tasks.
    """
    def __init__(self, args, gene_set, biotype, gene_set_plot_dir):
        self.args = args
        self.gene_set = gene_set
        self.biotype = biotype
        self.out_dir = gene_set_plot_dir
        self.tx_plot = os.path.join(self.out_dir, biotype, biotype + '_transcript_plot.pdf')
        self.gene_plot = os.path.join(self.out_dir, biotype, biotype + '_gene_plot.pdf')
        self.size_plot = os.path.join(self.out_dir, biotype, biotype + '_transcript_size_plot.pdf')
        self.gene_size_plot = os.path.join(self.out_dir, biotype, biotype + '_gene_size_plot.pdf')
        self.fail_plot = os.path.join(self.out_dir, biotype, biotype + '_gene_fail_plot.pdf')
        self.dup_rate_plot = os.path.join(self.out_dir, biotype, biotype + '_dup_rate_plot.pdf')
        self.plots = tuple([self.tx_plot, self.gene_plot, self.size_plot, self.gene_size_plot, self.fail_plot,
                            self.dup_rate_plot])


########################################################################################################################
########################################################################################################################
## Configuration for Augustus
########################################################################################################################
########################################################################################################################


class AugustusTMR(HashableNamespace):
    """
    AugustusTMR
    TODO: many of these things should not be hard coded like they are.
    TODO: should ask user which Augustus training set to use, right now it defaults to human.
    """
    def __init__(self, args, transmap_cfg, gene_set, target_genome, target_genome_files, annot_files):
        self.input_gp = transmap_cfg.gp
        self.path = 'AugustusTMR' if args.augustusHints is not None else 'AugustusTM'
        self.work_dir = os.path.join(args.workDir, self.path)
        self.output_dir = os.path.join(args.outputDir, self.path)
        self.genome = target_genome
        self.vector_gp = os.path.join(self.work_dir, 'intron_vector_gps', self.genome + '.intron_vector.gp')
        self.tmr_fa = os.path.join(self.work_dir, self.path + '_fastas', self.genome + '.fa')
        self.tmr_bed = os.path.join(self.work_dir, self.path + '_bed', self.genome + '.bed')
        self.out_gtf = os.path.join(self.output_dir, self.genome + '.gtf')
        self.out_gp = os.path.join(self.output_dir, self.genome + '.gp')
        self.chrom_sizes = target_genome_files.chrom_sizes
        self.fasta = target_genome_files.genome_fasta
        self.jobTree = os.path.join(args.jobTreeDir, self.path, gene_set.sourceGenome, gene_set.geneSet, self.genome)
        self.comp_ann_tm = CompAnnAugustusConfiguration(args, target_genome_files, annot_files, self, transmap_cfg,
                                                        gene_set)
        self.run_tmr = TMRJobTree(args, self, gene_set)
        self.align = AlignAugustusJobTree(args, self, gene_set, annot_files)
        self.aug_geneset = AugustusGeneSetConfig(args, self, gene_set, annot_files, transmap_cfg)


class TMRJobTree(HashableNamespace):
    """
    The args object that will be passed directly to jobTree
    """
    def __init__(self, args, augustus_files, gene_set):
        self.__dict__.update(vars(args.jobTreeOptions))
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
        self.padding = 25000
        self.max_gene_size = 2000000
        self.hints_db = args.augustusHints
        self.out_gtf = augustus_files.out_gtf
        self.genome = augustus_files.genome
        self.fasta = augustus_files.fasta
        self.chrom_sizes = augustus_files.chrom_sizes
        self.input_gp = augustus_files.vector_gp
        self.jobTree = os.path.join(args.jobTreeDir, augustus_files.path, gene_set.sourceGenome, gene_set.geneSet,
                                    self.genome)


class CompAnnAugustusConfiguration(HashableNamespace):
    """
    The args object that will be passed directly to jobTree
    """
    def __init__(self, args, target_genome_files, annot_files, augustus_files, transmap_cfg, gene_set):
        self.__dict__.update(vars(args.jobTreeOptions))
        self.genome = target_genome_files.genome
        self.annotation_gp = annot_files.gp
        self.augustus_gp = augustus_files.out_gp
        self.target_gp = transmap_cfg.gp
        self.mode = 'augustus'
        self.db = os.path.join(args.workDir, 'comparativeAnnotator', gene_set.sourceGenome, gene_set.geneSet,
                               'classification.db')
        self.jobTree = os.path.join(args.jobTreeDir, 'augustusComparativeAnnotator', gene_set.sourceGenome,
                                    gene_set.geneSet, self.genome)


class AlignAugustusJobTree(HashableNamespace):
    """
    The args object that will be passed directly to jobTree
    """
    def __init__(self, args, augustus_files, gene_set, annot_files):
        self.__dict__.update(vars(args.jobTreeOptions))
        self.genome = augustus_files.genome
        self.fasta = augustus_files.tmr_fa
        self.ref_fasta = annot_files.transcript_fasta
        self.db = os.path.join(args.workDir, 'comparativeAnnotator', gene_set.sourceGenome, gene_set.geneSet,
                               'classification.db')
        self.jobTree = os.path.join(args.jobTreeDir, 'alignAugustus', gene_set.sourceGenome,
                                    gene_set.geneSet, self.genome)


class AugustusGeneSetConfig(HashableNamespace):
    """
    Produces a gene set from transMap alignments, taking into account classifications.
    """
    def __init__(self, args, tmr, gene_set, annot_files, transmap_cfg):
        self.args = args
        self.filter_chroms = args.filterChroms
        self.genome = tmr.genome
        self.ref_genome = gene_set.sourceGenome
        self.target_gp = transmap_cfg.gp
        self.annotation_gp = annot_files.gp
        self.db = os.path.join(args.workDir, 'comparativeAnnotator', gene_set.sourceGenome, gene_set.geneSet,
                               'classification.db')
        self.biotypes = gene_set.biotypes
        self.mode = 'augustus'
        self.gene_set_name = gene_set.geneSet
        self.out_dir = os.path.join(args.outputDir, 'consensus_gene_set', gene_set.sourceGenome, gene_set.geneSet,
                                    self.genome)
        self.out_gps = frozendict((x, os.path.join(self.out_dir, x + '.gp')) for x in gene_set.biotypes)
        self.out_gtfs = frozendict((x, os.path.join(self.out_dir, x + '.gtf')) for x in gene_set.biotypes)
        self.tmp_dir = os.path.join(args.workDir, 'consensus_gene_set_metrics', gene_set.sourceGenome, gene_set.geneSet)
        self.tmp_pickle = os.path.join(self.tmp_dir, self.genome + '.metrics.pickle')
