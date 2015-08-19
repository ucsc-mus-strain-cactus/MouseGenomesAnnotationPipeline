"""
Quick and dirty functions for accessing data from HAL files.  This
can be a prototype for a real python HAL library.
"""

from pycbio.sys import procOps

def halStats(args):
    "Call halStats with the specified arguments, returns output as a list of lines"
    return list(procOps.callProcLines(["halStats"] + args))

def halGetGenomes(halfile):
    "return list of genomes in file"
    # one line of space-separate genomes
    return halStats(["--genomes", halfile])[0].split(" ")

def halGetChromSizes(halfile, genome):
    "return list of genomes in file"
    return dict(line.split("\t") for line in halStats(["--chromSizes", genome, halfile]))

