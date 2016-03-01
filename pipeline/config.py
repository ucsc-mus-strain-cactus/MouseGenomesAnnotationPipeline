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
        self.out_dir = os.path.join(args.outputDir, 'transMap_gene_set', gene_set.sourceGenome, gene_set.geneSet,
                                    self.genome)
        self.out_gps = frozendict((x, os.path.join(self.out_dir, x + '.gp')) for x in gene_set.biotypes)
        self.out_gffs = frozendict((x, os.path.join(self.out_dir, x + '.gff')) for x in gene_set.biotypes)
        self.tmp_dir = os.path.join(args.workDir, 'transMap_gene_set_metrics', gene_set.sourceGenome, gene_set.geneSet)
        self.tmp_pickle = os.path.join(self.tmp_dir, self.genome + '.metrics.pickle')


class CompAnnAugustusConfiguration(HashableNamespace):
    """
    The args object that will be passed directly to jobTree
    FIXME
    """
    def __init__(self, args, target_genome_files, annot_files, augustus_files, out_dir, gene_set):
        self.__dict__.update(vars(args.jobTreeOptions))
        self.out_dir = out_dir
        self.genome = target_genome_files.genome
        self.annotation_gp = annot_files.gp
        self.augustus_gp = augustus_files.gp
        self.mode = 'augustus'
        self.db = os.path.join(args.workDir, 'comparativeAnnotator', gene_set.sourceGenome, gene_set.geneSet,
                               'classification.db')
        self.jobTree = os.path.join(args.jobTreeDir, 'augustusComparativeAnnotator', gene_set.sourceGenome,
                                    gene_set.geneSet, self.genome)


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
        self.tm_plots = tuple([TransMapPlots(args, gene_set, b) for b in self.biotypes])
        self.tm_gene_set_plots = tuple([TransMapGeneSetPlots(args, gene_set, b) for b in self.biotypes])
        self.biotype_stacked_plot = os.path.join(args.outputDir, 'transMap_GeneSet_plots')


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


class TransMapGeneSetPlots(HashableNamespace):
    """
    Takes the initial configuration from the main driver script and builds paths to all files that will be produced
    by these tasks.
    """
    def __init__(self, args, gene_set, biotype):
        self.args = args
        self.gene_set = gene_set
        self.biotype = biotype
        self.out_dir = os.path.join(args.outputDir, 'transMap_GeneSet_plots', biotype)
        self.tx_gene_plot = os.path.join(self.out_dir, biotype + '_transcript_gene_plot.pdf')
        self.fail_plot = os.path.join(self.out_dir, biotype + '_gene_fail_plot.pdf')
        self.dup_rate_plot = os.path.join(self.out_dir, biotype + '_dup_rate_plot.pdf')
        self.size_plot = os.path.join(self.out_dir, biotype + '_size_plot.pdf')
        self.plots = tuple([self.tx_gene_plot, self.fail_plot, self.dup_rate_plot, self.size_plot])
        self.tmp_dir = os.path.join(args.workDir, 'transMap_gene_set_metrics', gene_set.sourceGenome, gene_set.geneSet)
