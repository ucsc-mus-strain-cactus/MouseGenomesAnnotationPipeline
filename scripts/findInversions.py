#!/usr/bin/env python
"""Hacky script to find small inversions given a set of
singly-mapping transcripts.

Filters using a loose definition of contiguity, namely that all
transcript "parts" (exons, introns, promoter) line up in the right way
without rearrangement (except possibly within a "part").
"""
import sys
import re
import subprocess
from argparse import ArgumentParser

def popenCatch(command, stdinString=None):
    """Runs a command and return standard out.
    Copied from sonLib.bioio
    """
    if stdinString != None:
        process = subprocess.Popen(command, shell=True,
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=sys.stderr, bufsize=-1)
        output, nothing = process.communicate(stdinString)
    else:
        process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=sys.stderr, bufsize=-1)
        output, nothing = process.communicate() #process.stdout.read().strip()
    sts = process.wait()
    if sts != 0:
        raise RuntimeError("Command: %s with stdin string '%s' exited with non-zero status %i" % (command, stdinString, sts))
    return output #process.stdout.read().strip()

def liftover(hal, srcGenome, srcBedLine, tgtGenome, psl=False):
    """Run halLiftover on a src bed and returns the PSL or bed line(s) to
    the target.
    """
    return popenCatch("halLiftover %s %s %s stdin %s stdout" % \
                      ('--outPSL' if psl else '', hal, srcGenome, tgtGenome),
                      srcBedLine)

def bedStrand(bedLine):
    assert len(bedLine) > 0
    fields = bedLine.split()
    if len(fields) < 6:
        raise RuntimeError("Transcript file must be BED6 or greater")
    return fields[5]

def getIdToBedLineMap(bedPath):
    """Get a map from transcript ID to bed line."""
    ret = {}
    for line in open(bedPath):
        line = line.strip()
        fields = line.split()
        if len(fields) < 4:
            raise RuntimeError("Bed must be >=BED4")
        ret[fields[3]] = line
    return ret

def labelTranscriptParts(bedLine):
    """Return a string containing several bedLines labeling the different
    parts (promoter, exon, intron) of the BED12 transcript."""
    bedLine = bedLine.split()
    chr = bedLine[0]
    start = int(bedLine[1])
    end = int(bedLine[2])
    name = bedLine[3]
    strand = bedLine[5]
    blockCount = int(bedLine[9])
    blockStarts = map(int, filter(lambda x: x != '', bedLine[10].split(',')))
    blockSizes = map(int, filter(lambda x: x != '', bedLine[11].split(',')))
    assert len(blockStarts) == len(blockSizes)
    assert len(blockStarts) == blockCount
    exons = reduce(lambda a, e: a + [(e[0] + start, e[0] + start + e[1])],
                   zip(blockSizes, blockStarts),
                   [])

    introns = []
    prevExon = None
    for exon in exons:
        if prevExon is not None:
            introns.append((prevExon[1], exon[0]))
        prevExon = exon

    if strand == '-':
        exons.reverse()
        introns.reverse()

    promoter = None
    if strand == '+':
        promoter = (start - 5000, start)
    else:
        promoter = (end, end + 5000)

    lines = []
    for i, exon in enumerate(exons):
        lines.append("%s\t%d\t%d\t%s-exon%d\t0\t%s" % (chr, exon[0], exon[1], name, i, strand))
    for i, intron in enumerate(introns):
        lines.append("%s\t%d\t%d\t%s-intron%d\t0\t%s" % (chr, intron[0], intron[1], name, i, strand))
    lines.append("%s\t%d\t%d\t%s-promoter\t0\t%s" % (chr, promoter[0], promoter[1], name, strand))
    return "\n".join(lines)

def contiguityFilter(transcriptParts, tgtStrand):
    """Ensure that all transcript parts land on one target chromosome, and
    that the intron and exon numbers are monotonically increasing or
    decreasing."""
    transcriptPartsSplit = map(lambda x: x.split(), transcriptParts)
    chrs = set(map(lambda x: x[0], transcriptPartsSplit))
    if len(chrs) > 1:
        return False

    transcriptPartsSplit.sort(key=lambda x: int(x[1]))
    if tgtStrand == '-':
        transcriptPartsSplit.reverse()

    prevExonNum = None
    prevIntronNum = None
    for splitBed in transcriptPartsSplit:
        name = splitBed[3]
        m = re.search(r'(exon|intron|promoter)([0-9]*)$', name)
        assert m is not None
        type = m.group(1)
        if type == 'exon':
            num = int(m.group(2))
            if prevExonNum > num:
                return False
            if prevIntronNum >= num:
                return False
            prevExonNum = num
        elif type == 'intron':
            num = int(m.group(2))
            if prevIntronNum > num:
                return False
            if prevExonNum > num:
                return False
            prevIntronNum = num
        else:
            assert type == 'promoter'
            if prevExonNum is not None or prevIntronNum is not None:
                return False
    return True

def main(args):
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('hal', help="alignment file")
    parser.add_argument('srcGenome', help="reference genome")
    parser.add_argument('tgtGenome', help="target genome")
    parser.add_argument('tgtTranscriptIds',
                        help="file with list of source transcript IDs")
    parser.add_argument('srcTranscriptsBed', help="source transcripts")
    parser.add_argument('tgtTranscriptsBed', help="target transcripts")
    opts = parser.parse_args(sys.argv[1:])

    srcBedLines = getIdToBedLineMap(opts.srcTranscriptsBed)
    tgtBedLines = getIdToBedLineMap(opts.tgtTranscriptsBed)
    tgtStrands = dict((k, bedStrand(v)) for k, v in tgtBedLines.items())
    for line in open(opts.tgtTranscriptIds):
        tgtTranscriptId = line.strip()
        # strip alignment ID from transcript ID
        srcTranscriptId = re.sub(r'-1$', '', tgtTranscriptId)
        tgtBedLine = tgtBedLines[tgtTranscriptId]
        srcBedLine = srcBedLines[srcTranscriptId]
        srcTranscriptParts = labelTranscriptParts(srcBedLine)
        tgtTranscriptParts = filter(
            lambda x: x != '', liftover(opts.hal, opts.srcGenome,
                                        srcTranscriptParts, opts.tgtGenome).split("\n"))

        overallTgtStrand = tgtStrands[tgtTranscriptId]
        if not contiguityFilter(tgtTranscriptParts, overallTgtStrand):
            continue

        # filter for regions where the target strand is not equal to the target strand of the overall transcript
        for bedLine in filter(lambda x: bedStrand(x) != overallTgtStrand, tgtTranscriptParts):
            print bedLine

if __name__ == '__main__':
    main(sys.argv)
