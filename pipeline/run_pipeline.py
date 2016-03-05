#!/usr/bin/env python
import sys
import os
import luigi
import ete3
import argparse
# need to set environ also in order for it to be passed on to jobTree
# TODO: this should be in some sort of sourceme.bash file.
os.environ['PYTHONPATH'] = './:./submodules:./submodules/pycbio:./submodules/comparativeAnnotator'
sys.path.extend(['./', './submodules', './submodules/pycbio', './submodules/comparativeAnnotator'])
from pycbio.sys.fileOps import iterRows
from pycbio.sys.procOps import callProcLines
from pipeline import GenomeFiles, AnnotationFiles, ChainFiles, TransMap, ReferenceComparativeAnnotator,\
    ComparativeAnnotator, RunAugustus, TransMapAnalysis, GeneSet, GeneSetPlots
from config import PipelineConfiguration
from lib.parsing import HashableNamespace, NamespaceAction, FileArgumentParser
from jobTree.scriptTree.stack import Stack


class RunPipeline(luigi.WrapperTask):
    """
    Pipeline starts here.
    """
    params = luigi.Parameter()

    def requires(self):
        for gene_set in self.params.geneSets:
            # in cases where the user does not specifies a subset of target genomes, remove source
            cfg = PipelineConfiguration(self.params, gene_set)
            assert hash(cfg)
            yield AnnotationFiles(cfg.query_cfg)
            yield ReferenceComparativeAnnotator(cfg.query_cfg)
            for target_genome, query_target_cfg in cfg.query_target_cfgs.iteritems():
                yield GenomeFiles(query_target_cfg)
                yield ChainFiles(query_target_cfg)
                yield TransMap(query_target_cfg)
                yield ComparativeAnnotator(query_target_cfg)
                yield GeneSet(query_target_cfg, mode='transMap')
                if self.params.augustus is True and target_genome in args.augustusGenomes:
                    yield RunAugustus(cfg.augustus_cfgs[target_genome])
                    yield GeneSet(cfg.augustus_cfgs[target_genome], mode='augustus')
            yield TransMapAnalysis(cfg)
            yield GeneSetPlots(cfg, mode='transMap')
            if self.params.augustus is True:
                yield GeneSetPlots(cfg, mode='augustus')


def parse_args():
    """
    Build argparse object, parse arguments. See the parsing library for a lot of the features used here.
    """
    parser = FileArgumentParser(description=__doc__)
    parser.add_argument('--geneSets', action=NamespaceAction, nargs=4, required=True, metavar='KEY=VALUE',
                        help='Input gene sets. Expects groups of four key-value pairs in the format --geneSets '
                             'geneSet=Ensembl sourceGenome=C_elegans genePred=testdata/c_elegans.transcripts.gp '
                             'attributesTsv=testdata/ce11.ensembl.attributes.tsv. '
                             'At this point geneSet should only equal Ensembl or Gencode.')
    parser.add_argument('--targetGenomes', default=None, nargs='+', metavar='NAMES',
                        help='Space-separated list of genomes you wish to annotate. '
                             'If not set, all non-reference genomes will be annotated.')
    parser.add_argument_with_mkdir_p('--workDir', default='work', metavar='DIR',
                                     help='Work directory. Will contain intermediate files that may be useful.')
    parser.add_argument_with_mkdir_p('--jobTreeDir', default='jobTrees', metavar='DIR',
                                     help='Directory where jobTrees will be run. Should be visible to cluster nodes.')
    parser.add_argument_with_mkdir_p('--outputDir', default='output', metavar='DIR', help='Output directory.')
    parser.add_argument_with_check('--hal', required=True, metavar='FILE',
                                   help='HAL alignment file produced by progressiveCactus')
    parser.add_argument('--localCores', default=12, metavar='INT',
                        help='Number of local cores to use. (default: %(default)d)')
    parser.add_argument_with_check('--augustusHints', default=None, metavar='FILE',
                                   help='Augustus hints DB. If not set, and --augusuts is set, no RNAseq will be used.')
    parser.add_argument('--augustus', action='store_true',
                        help='Should we run AugustusTM(R) on this analysis? If set, and --augustusHints is not set,'
                             ' then TM mode will be executed. Both modes are highly computationally intensive.')
    parser.add_argument('--augustusGenomes', default=None, nargs='+', metavar='NAMES',
                        help='Space-separated list of genomes you wish to run AugustusTM(R) on.')
    jobtree = parser.add_argument_group('jobTree options. Read the jobTree documentation for other options not shown')
    jobtree.add_argument('--batchSystem', default='parasol', help='jobTree batch system.')
    jobtree.add_argument('--parasolCommand', default='./bin/remparasol',
                         help='Parasol command used by jobTree. Used to remap to host node.')
    jobtree.add_argument('--maxThreads', default=4,
                         help='maxThreads for jobTree. If not using a cluster, this should be --localCores/# genomes')
    jobtree_parser = argparse.ArgumentParser(add_help=False)
    options = parser.add_argument_group('Optional arguments')
    options.add_argument('--filterChroms', nargs='+', default=('Y', 'chrY'),
                         help='Chromosomes to ignore when generating plots. Useful to not skew stats in females, '
                              'for example. List as many as you want, space separated.')
    options.add_argument('--norestart', action='store_true', default=False,
                         help='Set to force jobtree pipeline components to start from the beginning instead of '
                              'attempting a restart.')
    Stack.addJobTreeOptions(jobtree_parser)
    args = parser.parse_args(namespace=HashableNamespace())
    args.jobTreeOptions = jobtree_parser.parse_known_args(namespace=HashableNamespace())[0]
    # modify args to have newick string and list of all genomes
    newick_str, genomes = extract_newick_genomes_cactus(args.hal)
    args.genomes = genomes
    if args.targetGenomes is None:
        args.targetGenomes = genomes
    else:
        args.targetGenomes = tuple(args.targetGenomes)
    args.tree = newick_str
    # make hashable
    args.geneSets = tuple(args.geneSets)
    # add genome order to each source gene set as well as biotypes that exist
    for gene_set in args.geneSets:
        gene_set.orderedTargetGenomes = build_genome_order(newick_str, gene_set.sourceGenome)
        gene_set.biotypes = get_biotypes_from_attrs(gene_set.attributesTsv)
    # if batchSystem/parasolCommand are not supplied on the command line, they will be the jobTree defaults. Fix this.
    args.jobTreeOptions.__dict__.update({x: y for x, y in vars(args).iteritems() if x in args.jobTreeOptions})
    # make the default jobTree dir None so that it crashes if I am stupid
    args.jobTreeOptions.jobTree = None
    # Validate arguments - manually check that all geneSet files exist because my fancy FileArgumentParser can't do this
    for geneSet in args.geneSets:
        assert all([x in geneSet for x in ['geneSet', 'sourceGenome', 'genePred', 'attributesTsv']])
        assert any([geneSet.geneSet.lower().find(x) != -1 for x in ['ensembl', 'gencode']])
        assert os.path.exists(geneSet.genePred), 'Error: genePred file {} missing.'.format(geneSet.genePred)
        assert os.path.exists(geneSet.attributesTsv), 'Error: attributes file {} missing.'.format(geneSet.attributesTsv)
    if args.augustusGenomes is None:
        args.augustusGenomes = args.targetGenomes
    else:
        args.augustusGenomes = tuple(args.augustusGenomes)
    return args


def get_biotypes_from_attrs(attrs_tsv):
    """
    Produces a set of biotypes from the biotype column of the attributes file.
    This is the GeneType column, the 3rd column.
    """
    # skip header line
    return tuple(set(x[2] for x in iterRows(attrs_tsv, skipLines=1)))


def build_genome_order(newick_str, ref_genome):
    """
    Takes a newick format string and a single genome and reports the genetic distance of each genome in the tree
    from the reference genome. Used to order plots from closest to furthest from the source genome.
    """
    t = ete3.Tree(newick_str, format=1)
    distances = [[t.get_distance(ref_genome, x), x.name] for x in t if x.name != ref_genome]
    ordered = sorted(distances, key=lambda (dist, name): dist)
    distances, ordered_names = zip(*ordered)
    return ordered_names


def extract_newick_genomes_cactus(hal):
    """
    Parse the cactus config file, extracting just the newick tree
    """
    cmd = ['halStats', '--tree', hal]
    newick = callProcLines(cmd)[0]
    t = ete3.Tree(newick, format=1)
    genomes = tuple(t.get_leaf_names())
    return newick, genomes


if __name__ == '__main__':
    args = parse_args()
    luigi.build([RunPipeline(args)], local_scheduler=True, workers=args.localCores)
