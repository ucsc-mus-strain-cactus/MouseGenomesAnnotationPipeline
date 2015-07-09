#!/usr/bin/env python
"""Parses the SVs contained in a .sdp.tab file."""
import sys

class SV:
    """Represents a SDP structural variant."""
    def __init__(self, rowDict):
        """Create a SV from a map of (SDP column name) -> (row value)"""
        essentialFields = set(['CHROM', 'START', 'END', 'FORMAT'])
        # all essential fields must be in the rowDict
        assert essentialFields < set(rowDict.keys())

        self.rowDict = rowDict

        self.chrom = rowDict['CHROM']
        self.start = int(rowDict['START'])
        self.end = int(rowDict['END'])

        # because I'm lazy and we don't need this to be general
        assert rowDict['FORMAT'] == 'POS:CL:BP:TY'

        self.samples = set(rowDict.keys()) - essentialFields

    def samples_affected(self):
        """List of the samples that actually have this SV."""
        return filter(lambda x: self.rowDict[x] not in '0.', self.samples)

    def breakpoints(self, sample):
        """The breakpoints for this SV in a particular sample.

        Might not be the same as the "overall" breakpoint for the SV
        as a whole.
        """
        if sample not in self.samples_affected():
            return RuntimeError("No information for sample %s" % sample)
        posString = self.rowDict[sample].split(";")[0]
        chrom = posString.split(":")[0]
        start = int(posString.split(":")[1].split("-")[0])
        stop = int(posString.split(":")[1].split("-")[1])
        return (chrom, start, stop)

    def svClass(self, sample):
        """The class of this sample, e.g. "INS", "DEL"

        Possible values:
        INS - insertion
        DEL - deletion
        INV - inversion
        DELLINKEDINS
        INSLINKEDINS
        INVDEL
        DELLINKED
        DELINS
        INSLINKED(INV)INS
        TANDEMLOWDUP
        TANDEMDUPINV
        TANDEMLOWDUPINV
        GAIN
        INSLINKED(INV)
        INVDELINS
        INSnternal
        INSLINKED(INV)DEL
        INVINS
        INSLINKED
        TANDEMDUP
        """
        if sample not in self.samples_affected():
            return RuntimeError("No information for sample %s" % sample)
        classString = self.rowDict[sample].split(";")[1]
        if '|' in classString:
            classString = classString.split("|")[0]
        return classString

    def svClassDetail(self, sample):
        """Extra information on the SV, e.g. repeat class."""
        if sample not in self.samples_affected():
            return RuntimeError("No information for sample %s" % sample)
        classString = self.rowDict[sample].split(";")[1]
        if '|' not in classString:
            return ""
        return classString.split("|")[1]

    def refined(self, sample):
        """Are the breakpoints for this sample refined by local assembly?"""
        if sample not in self.samples_affected():
            return RuntimeError("No information for sample %s" % sample)
        breakpointString = self.rowDict[sample].split(";")[2]
        if breakpointString == "REF":
            return True
        else:
            return False

    def type(self, sample):
        """The PEM pattern of this SV."""
        if sample not in self.samples_affected():
            return RuntimeError("No information for sample %s" % sample)
        return self.rowDict[sample].split(";")[3]

def parse_SDP(sdpFile):
    """Takes a file-like object for an SDP and generates SVs."""
    headers = None
    for linenum, line in enumerate(sdpFile):
        line = line.strip()
        if len(line) == 0:
            continue
        if line.startswith("#CHROM"):
            # header line: needed to explain the names of samples
            headers = line[1:].split("\t")
            continue
        elif line.startswith("#"):
            # random comment
            continue
        if headers is None:
            raise RuntimeError("SDP file invalid. There was a data line "
                               "before any header line")
        fields = line.split("\t")
        if len(fields) != len(headers):
            raise RuntimeError("Line %d invalid--got %d fields, was "
                               "expecting %d." % (linenum, len(fields),
                                                  len(headers)))
        # Make a nice map from column header to value
        row = dict(zip(headers, fields))
        yield SV(row)

if __name__ == '__main__':
    classes = set()
    for sv in parse_SDP(open(sys.argv[1])):
        for sample in sv.samples_affected():
            classes.add(sv.svClass(sample))
    print classes
