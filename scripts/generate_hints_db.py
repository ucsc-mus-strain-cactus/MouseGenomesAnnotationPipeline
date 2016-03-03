"""
Wrapper for comparativeAnnotator's build_hints_db.py, which will do so per-genome.
"""
import sys
import os
import argparse
import luigi
from frozendict import frozendict
os.environ['PYTHONPATH'] = './:./submodules:./submodules/pycbio:./submodules/comparativeAnnotator'
sys.path.extend(['./', './submodules', './submodules/pycbio', './submodules/comparativeAnnotator'])
from pycbio.sys.fileOps import ensureDir
from pycbio.sys.procOps import runProc
from jobTree.scriptTree.stack import Stack
from lib.parsing import HashableNamespace, NamespaceAction, FileArgumentParser
from comparativeAnnotator.augustus.build_hints_db import external_main
from pipeline.abstract_classes import AbstractJobTreeTask


class BuildHints(luigi.WrapperTask):
    """
    Pipeline starts here.
    """
    params = luigi.Parameter()

    def create_args(self, genome):
        args = HashableNamespace()
        args.__dict__.update(vars(self.params.jobTreeOptions))
        args.genome = genome
        args.jobTree = os.path.join(self.params.workDir, 'jobTrees', genome)
        args.fasta = self.params.fasta_map[genome]
        args.database = self.params.database
        args.bams = self.params.bam_map[genome]
        args.norestart = self.params.norestart
        args.hintsDir = os.path.join(self.params.workDir, 'reduced_hints')
        args.hintsFile = os.path.join(args.hintsDir, genome + '.reduced_hints.gff')
        return args

    def requires(self):
        arg_holder = []
        for genome in self.params.genomes:
            args = self.create_args(genome)
            ensureDir(os.path.dirname(args.jobTree))
            arg_holder.append(args)
            yield GenerateHints(args)
        yield FinishDb(self.params, arg_holder)


class GenerateHints(AbstractJobTreeTask):
    def output(self):
        # TODO; this doesn't check if db gets loaded too
        #return luigi.LocalTarget(self.cfg.hintsFile)
        return

    def run(self):
        self.start_jobtree(self.cfg, external_main, self.cfg.norestart)


class FinishDb(luigi.Task):
    args = luigi.Parameter()
    arg_holder = luigi.Parameter()

    def requires(self):
        return [GenerateHints(x) for x in self.arg_holder]

    def output(self):
        return

    def run(self):
        cmd = ['load2sqlitedb', '--makeIdx', '--dbaccess', self.args.database]
        runProc(cmd)


def parse_args():
    """
    Build argparse object, parse arguments. See the parsing library for a lot of the features used here.
    """
    parser = FileArgumentParser(description=__doc__)
    parser.add_argument('--bamFiles', action=NamespaceAction, nargs='+', mode='defaultdict', required=True,
                        metavar='KEY=VALUE',
                        help='for each key:value pair, give a genome and a bamfile or a bam fofn.')
    parser.add_argument('--genomeFastas', action=NamespaceAction, nargs='+', mode='dict',
                        required=True, metavar='KEY=VALUE',
                        help='for each key:value pair, give a genome and a fasta.')
    parser.add_argument("--database", required=True, metavar='FILE', help='path to write database to.')
    parser.add_argument_with_mkdir_p('--workDir', default='hints_work', metavar='DIR',
                                     help='Work directory. Will contain intermediate files that may be useful.')
    parser.add_argument('--norestart', action='store_true', default=False,
                        help='Set to force jobtree pipeline components to start from the beginning instead of '
                             'attempting a restart.')
    parser.add_argument('--localCores', default=12, metavar='INT',
                        help='Number of local cores to use. (default: %(default)d)')
    jobtree = parser.add_argument_group('jobTree options. Read the jobTree documentation for other options not shown')
    jobtree.add_argument('--batchSystem', default='parasol', help='jobTree batch system.')
    jobtree.add_argument('--parasolCommand', default='./bin/remparasol',
                         help='Parasol command used by jobTree. Used to remap to host node.')
    jobtree.add_argument('--maxThreads', default=4,
                         help='maxThreads for jobTree. If not using a cluster, this should be --localCores/# genomes')
    jobtree_parser = argparse.ArgumentParser(add_help=False)
    Stack.addJobTreeOptions(jobtree_parser)
    args = parser.parse_args(namespace=HashableNamespace())
    args.jobTreeOptions = jobtree_parser.parse_known_args(namespace=HashableNamespace())[0]
    args.jobTreeOptions.jobTree = None
    args.jobTreeOptions.__dict__.update({x: y for x, y in vars(args).iteritems() if x in args.jobTreeOptions})
    # munge parsed args, verify, make hashable
    args.genomes = frozenset([vars(namespace).keys()[0] for namespace in args.genomeFastas])
    fasta_map = {}
    for namespace in args.genomeFastas:
        genome = vars(namespace).keys()[0]
        fasta_map[genome] = vars(namespace).values()[0]
        assert os.path.exists(fasta_map[genome])
    args.fasta_map = frozendict(fasta_map)
    bam_map = {}
    for namespace in args.bamFiles:
        genome = vars(namespace).keys()[0]
        assert genome in args.genomes
        bam_map[genome] = tuple([x[0] for x in vars(namespace).values()])
        assert all([os.path.exists(x) for x in bam_map[genome]])
    args.bam_map = frozendict(bam_map)
    del args.bamFiles
    del args.genomeFastas
    p = os.path.dirname(args.database)
    if p != '':
        ensureDir(p)
    return args


if __name__ == '__main__':
    args = parse_args()
    luigi.build([BuildHints(args)], local_scheduler=True, workers=args.localCores)
