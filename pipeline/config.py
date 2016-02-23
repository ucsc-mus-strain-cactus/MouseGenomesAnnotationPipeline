"""
Produces a configuration class for all downstream applications.
"""
import os
from lib.parsing import HashableNamespace


class Configuration(HashableNamespace):
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
        self.comp_ann = ComparativeAnnotatorConfiguration(args, self.gene_set, self.query_genome_files, 
                                                          self.target_genome_files, self.annot_files, self.transmap)

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


class ComparativeAnnotatorConfiguration(HashableNamespace):
    """
    Takes the initial configuration from the main driver script and builds paths to all files that will be produced
    by these tasks.
    """
    def __init__(self, args, gene_set, query_genome_files, target_genome_files, annot_files, transmap):
        self.work_dir = os.path.join(args.workDir, 'comparativeAnnotator', gene_set.sourceGenome, gene_set.geneSet)
        self.metrics_dir = os.path.join(args.outputDir, 'metrics')
        self.tx_set_dir = os.path.join(args.outputDir, 'tm_transcript_set')
        self.reference = CompAnnReference(args, query_genome_files, annot_files, self.work_dir, gene_set)
        self.transmap = CompAnnTransMap(args, query_genome_files, target_genome_files, annot_files, transmap, 
                                        self.work_dir, gene_set)


class CompAnnReference(HashableNamespace):
    """
    The args object that will be passed directly to jobTree
    """
    def __init__(self, args, query_genome_files, annot_files, out_dir, gene_set):
        self.__dict__.update(vars(args.jobTreeOptions)) 
        self.out_dir = out_dir
        self.ref_genome = query_genome_files.genome
        self.ref_fasta = query_genome_files.genome_fasta
        self.ref_psl = annot_files.psl
        self.sizes = query_genome_files.chrom_sizes
        self.annotation_gp = annot_files.gp
        self.gencode_attributes = annot_files.attributes
        self.mode = 'reference'
        self.db = os.path.join(out_dir, 'classifications.db')
        self.jobTree = os.path.join(args.jobTreeDir, 'comparativeAnnotator', gene_set.sourceGenome, gene_set.geneSet, 
                                    self.ref_genome)


class CompAnnTransMap(CompAnnReference):
    """
    The args object that will be passed directly to jobTree
    """
    def __init__(self, args, query_genome_files, target_genome_files, annot_files, transmap, out_dir, gene_set):
        super(CompAnnTransMap, self).__init__(args, query_genome_files, annot_files, out_dir, gene_set)
        self.genome = target_genome_files.genome
        self.psl = transmap.psl
        self.ref_psl = annot_files.psl
        self.target_gp = transmap.gp
        self.fasta = target_genome_files.genome_fasta
        self.mode = 'transMap'
        self.db = os.path.join(out_dir, 'classifications.db')
        self.jobTree = os.path.join(args.jobTreeDir, 'comparativeAnnotator', gene_set.sourceGenome, gene_set.geneSet, 
                                    self.genome)
