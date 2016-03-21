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
    parser.add_argument('--filterChroms', nargs='+', default=None, help='Ignore these chromosomes.')
    parser.add_argument('--convertUCSCtoEnsembl', action='store_true', help='Convert UCSC chromosome names to ensembl.')
    return parser.parse_args()


def get_genes(database, gencode_version, gencode_set, name, out_dir, include_chroms, filter_chroms, convert_ucsc):
    if include_chroms is None and filter_chroms is None:
        cmd = ['hgsql', '-Ne', 'SELECT * FROM wgEncodeGencode{}{}'.format(gencode_set, gencode_version), database]
    else:
        l = 'SELECT * FROM wgEncodeGencode{}{} WHERE '.format(gencode_set, gencode_version)
        if include_chroms is not None:
            for c in include_chroms[:-1]:
                l += 'chrom = "{}" AND '.format(c)
            l += 'chrom = "{}"'.format(include_chroms[-1])
        if filter_chroms is not None:
            for c in filter_chroms[:-1]:
                l += 'chrom != "{}" AND '.format(c)
            l += 'chrom != "{}"'.format(filter_chroms[-1])
        cmd = ['hgsql', '-Ne', l, database]
    cmd = [cmd, ['cut', '-f', '2-']]  # strip bin name
    if convert_ucsc is True:
        cmd += ['bin/ucscToEnsemblChrom', '-v', 'chromCol=2', '/dev/stdin']
    with open(os.path.join(out_dir, name + '.gp'), 'w') as outf:
        runProc(cmd, stdout=outf)


def build_attributes(database, gencode_version, name, out_dir):
    header = '\t'.join(['GeneId', 'GeneName', 'GeneType', 'TranscriptId', 'TranscriptType']) + '\n'
    cmd = ['hgsql', '-Ne',
           'SELET geneId,geneName,geneType,transcriptId,transcriptType FROM '
           'wgEncodeGencodeAttrs{}'.format(gencode_version),
           database]
    with open(os.path.join(out_dir, name + '.tsv'), 'w', buffering=-1) as outf:
        outf.write(header)
        outf.flush()
        runProc(cmd, stdout=outf)


def main():
    args = parse_args()
    if args.name is None:
        args.name = args.database
    ensureDir(args.outDir)
    get_genes(args.database, args.gencodeVersion, args.gencodeSet, args.name, args.outDir, args.includeChroms,
              args.filterChroms, args.convertUCSCtoEnsembl)
    build_attributes(args.database, args.gencodeVersion, args.name, args.outDir)


if __name__ == '__main__':
    main()
