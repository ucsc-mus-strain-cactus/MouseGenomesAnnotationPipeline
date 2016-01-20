import sys
import os
import luigi
import argparse
import ete2
from configobj import ConfigObj
sys.path.append('src')
from genome_files import RunGenomeFiles


class RunPipeline(luigi.WrapperTask):
    params = luigi.Parameter()

    def requires(self):
        for genome in self.params['genomes']:
            RunGenomeFiles(self.params)


def parse_args():
    """
    Build argparse object
    """
    parser = argparse.ArgumentParser()
    parser.add_argument('config', help='Config file', required=True)
    return parser.parse_args()


def build_genome_order(newick_str, ref_genome):
    """
    Takes a newick format string and a single genome and reports the genetic distance of each genome in the tree
    from the reference genome. Used to order plots from closest to furthest from the source genome.
    """
    t = ete2.Tree(newick_str)
    distances = [[t.get_distance(ref_genome, x), x.name] for x in t if x.name != ref_genome]
    ordered = sorted(distances, key=lambda (dist, name): dist)
    distances, ordered_names = zip(*ordered)
    return ordered_names


def validate_config_paths(config):
    """
    Validate that all required paths are in the config file and exist
    """
    required_fields = ['Cactus', 'Directories', 'SourceGeneSets', 'AugustusGenomes']
    assert all([x in config for x in required_fields])
    for sub_cat in ['hal', 'config']:
        assert all([sub_cat in config['Cactus'] and os.path.exists(config['Cactus'][sub_cat])])
    for sub_cat in ['work', 'output']:
        assert os.path.exists(os.path.dirname(config['Directories'][sub_cat]))


def extract_newick_genomes_cactus(cactus_config):
    """
    Parse the cactus config file, extracting just the newick tree
    """
    f_h = open(cactus_config)
    newick = f_h.next().rstrip()
    genomes = [x.split()[0] for x in f_h]
    return newick, genomes


def validate_gene_sets(config):
    """
    Validate that each source gene set has its associated files and is present in the alignment
    """
    assert len(config['SourceGeneSets']) > 0
    genomes = config['genomes']
    assert len(genomes) > 2
    for genome, paths in config['SourceGeneSets'].iteritems():
        assert genome in genomes
        assert all([os.path.exists(p) for p in paths.itervalues()])
        config['SourceGeneSets'][genome]['order'] = build_genome_order(config['newick'], genome)


def parse_config(cfg_file):
    """
    Parsers the main configuration file, returning a namedtuple with all the information luigi needs.
    """
    config = ConfigObj(cfg_file)
    validate_config_paths(config)
    newick, genomes = extract_newick_genomes_cactus(config['Cactus']['config'])
    config['newick'] = newick
    config['genomes'] = genomes
    validate_gene_sets(config)
    return config


if __name__ == '__main__':
    args = parse_args()
    config = parse_config(args.config)
    luigi.run(main_task_cls=RunPipeline(config))