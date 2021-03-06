"""
Script to make use of mySQL tables to build gene and attributes files
"""
import argparse
import sys
import os
sys.path.append('./submodules/pycbio')
from pycbio.sys.procOps import runProc, callProcLines
from pycbio.sys.fileOps import ensureDir


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('database', help='mySQL database to load ensembl genes from')
    parser.add_argument('--name', help='Name to use instead of database name', default=None)
    parser.add_argument('--outDir', help='location to place files. (default: %(default)s)', default='./genesets')
    parser.add_argument('--includeChroms', nargs='+', default=None, help='Limit to just these chromosomes.')
    parser.add_argument('--convertUCSCtoEnsembl', action='store_true', help='Convert UCSC chromosome names to ensembl.')
    return parser.parse_args()


def get_genes(database, name, out_dir, include_chroms, convert_ucsc):
    if include_chroms is None:
        cmd = ['hgsql', '-Ne', 'select * from ensGene', database]
    else:
        l = 'select * from ensGene where '
        for c in include_chroms[:-1]:
            l += 'chrom = "{}" and '.format(c)
        l += 'chrom = "{}"'.format(include_chroms[-1])
        cmd = ['hgsql', '-Ne', l, database]
    cmd = [cmd, ['cut', '-f', '2-']]  # strip bin name
    if convert_ucsc is True:
        cmd += ['bin/ucscToEnsemblChrom', '-v', 'chromCol=2', '/dev/stdin']
    with open(os.path.join(out_dir, name + '.gp'), 'w') as outf:
        runProc(cmd, stdout=outf)


def build_attributes(database, name, out_dir):
    header = '\t'.join(['GeneId', 'GeneName', 'GeneType', 'TranscriptId', 'TranscriptType']) + '\n'
    source_cmd = ['hgsql', '-Ne', 'select * from ensemblSource', database]
    source = dict(x.split() for x in callProcLines(source_cmd))
    genes_cmd = ['hgsql', '-Ne', 'select * from ensemblToGeneName', database]
    genes = dict(x.split() for x in callProcLines(genes_cmd))
    transcripts_cmd = ['hgsql', '-Ne', 'select transcript, gene from ensGtp', database]
    transcripts = dict(x.split() for x in callProcLines(transcripts_cmd))
    r = []
    for transcript_id, gene_id in transcripts.iteritems():
        gene_name = genes.get(transcript_id, 'NoName')
        biotype = source[transcript_id]
        r.append([gene_id, gene_name, biotype, transcript_id, biotype])
    with open(os.path.join(out_dir, name + '.tsv'), 'w') as outf:
        outf.write(header)
        for x in sorted(r, key=lambda x: x[0]):
            outf.write('\t'.join(x) + '\n')


def main():
    args = parse_args()
    if args.name is None:
        args.name = args.database
    ensureDir(args.outDir)
    get_genes(args.database, args.name, args.outDir, args.includeChroms, args.convertUCSCtoEnsembl)
    build_attributes(args.database, args.name, args.outDir)


if __name__ == '__main__':
    main()
