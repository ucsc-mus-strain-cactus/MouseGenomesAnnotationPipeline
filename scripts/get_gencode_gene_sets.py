"""
Script to make use of mySQL tables to build gene and attributes files
"""
import argparse
import sys
import os
sys.path.append('./submodules/pycbio')
from pycbio.sys.procOps import runProc
from pycbio.sys.fileOps import ensureDir


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('database', help='mySQL database to load ensembl genes from')
    parser.add_argument('gencodeSet', help='Gencode set (Comp, Basic, PseudoGene). Caps matter.')
    parser.add_argument('gencodeVersion', help='Gencode version to extract. (VM8, V24)')
    parser.add_argument('--name', help='Name to use instead of database name', default=None)
    parser.add_argument('--outDir', help='location to place files. (default: %(default)s)', default='./genesets')
    parser.add_argument('--includeChroms', nargs='+', default=None, help='Limit to just these chromosomes.')
    return parser.parse_args()


def get_genes(database, gencode_version, gencode_set, name, out_dir, include_chroms):
    if include_chroms is None:
        cmd = ['hgsql', '-Ne', 'select * from wgEncodeGencode{}{}'.format(gencode_set, gencode_version), database]
    else:
        l = 'select * from {} where '.format(gencode_version)
        for c in include_chroms[:-1]:
            l += 'chrom = "{}" and '.format(c)
        l += 'chrom = "{}"'.format(include_chroms[-1])
        cmd = ['hgsql', '-Ne', l, database]
    cmd = [cmd, ['cut', '-f', '2-']]  # strip bin name
    with open(os.path.join(out_dir, name + '.gp'), 'w') as outf:
        runProc(cmd, stdout=outf)


def build_attributes(database, gencode_version, name, out_dir):
    header = '\t'.join(['GeneId', 'GeneName', 'GeneType', 'TranscriptId', 'TranscriptType']) + '\n'
    cmd = ['hgsql', '-Ne',
           'select geneId,geneName,geneType,transcriptId,transcriptType from '
           'wgEncodeGencodeAttrs{}'.format(gencode_version),
           database]
    with open(os.path.join(out_dir, name + '.tsv'), 'w') as outf:
        outf.write(header)
        runProc(cmd, stdout=outf)


def main():
    args = parse_args()
    if args.name is None:
        args.name = args.database
    ensureDir(args.outDir)
    get_genes(args.database, args.gencodeVersion, args.gencodeSet, args.name, args.outDir, args.includeChroms)
    build_attributes(args.database, args.gencodeVersion, args.name, args.outDir)


if __name__ == '__main__':
    main()
