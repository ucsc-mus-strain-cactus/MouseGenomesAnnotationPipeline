#!/usr/bin/env python
"""
Lifts a directory output by halTreeMutations to a given reference
genome. The final output will be a set of BED files on the reference,
one for each other leaf genome, in which each entry represents the
rearrangements that happened on the path to that leaf, and is labeled
by the branch it occurred on.

Requires sonLib and the hal tools to be installed in the PATH and
PYTHONPATH.
"""
import os
from itertools import groupby
from argparse import ArgumentParser
from sonLib.bioio import system, popenCatch
from sonLib.nxnewick import NXNewick

def getMRCA(tree, id1, id2):
    """Gets the ID of the most recent common ancestor of two nodes in an NXTree."""
    candidates = set() # Set of ancestors of id1, inclusive.
    candidates.add(id1)
    curNode = id1
    while tree.hasParent(curNode):
        curNode = tree.getParent(curNode)
        candidates.add(curNode)

    # Now check the ancestors of id2 and return the closest one that is also an ancestor of id1.
    curNode = id2
    while tree.hasParent(curNode):
        if curNode in candidates:
            break
        curNode = tree.getParent(curNode)
    if curNode not in candidates:
        raise ValueError("Attempt to find MRCA of candidates not in the same tree.")
    return curNode

def getPath(hal, ref, target):
    """Get the path along the species tree from the reference to the
    target genome."""
    halOutput = popenCatch("halStats --spanRoot %s,%s %s" % (ref, target, hal))
    return halOutput.split()

def getTreeID(tree, name):
    """Gets the ID for a node in an NXTree, given its name."""
    nameToID = dict((tree.getName(id), id) for id in tree.nxDg)
    return nameToID[name]

def convertMutationBedToRealBed(mutationsFilePath, destBedPath, reversePolarity=False):
    """Convert from the halBranchMutations BED format (which can't be
    lifted over as-is) to a BED4-compliant file."""
    with open(destBedPath, 'w') as destBed, open(mutationsFilePath) as mutationsFile:
        for line in mutationsFile:
            if len(line) == 0 or line[0] == '#':
                # Blank or comment line, no need to convert.
                continue
            fields = line.strip().split("\t")
            chr, start, stop, mutationID, parentGenome, childGenome = fields
            if reversePolarity:
                if mutationID == 'I':
                    mutationID = 'D'
                elif mutationID == 'GI':
                    mutationID = 'GD'
                elif mutationID == 'D':
                    mutationID = 'I'
                elif mutationID == 'GD':
                    mutationID = 'GI'
            combinedName = "%s|%s|%s" % (mutationID, parentGenome, childGenome)
            destBed.write("%s\t%s\t%s\t%s\n" % (chr, start, stop, combinedName))

def liftMutations(halTreeMutationsDir, hal, sourceGenome, targetGenome, targetBed, reversePolarity=False):
    """Lift a mutation BED onto the reference.
    
    If reversePolarity is true, the labeling of insertions/deletions will be swapped."""
    sourceMutations = os.path.join(halTreeMutationsDir, sourceGenome + ".bed")
    sourceBed = os.path.join(halTreeMutationsDir, sourceGenome + ".realBed.bed")
    convertMutationBedToRealBed(sourceMutations, sourceBed, reversePolarity=reversePolarity)
    system("halLiftover --append %s %s %s %s %s" % (hal, sourceGenome, sourceBed, targetGenome, targetBed))

def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('hal', help='hal file')
    parser.add_argument('refGenome', help='reference genome')
    parser.add_argument('halTreeMutationsDir', help='the directory output by halTreeMutations.py')
    parser.add_argument('--targets', help='target genomes (comma-separated), default: all leaves')
    parser.add_argument('outputDir', help='output directory for reference beds')
    opts = parser.parse_args()

    # Get the species tree from the hal file.
    newickTree = popenCatch('halStats --tree %s' % (opts.hal))
    tree = NXNewick().parseString(newickTree)

    # Set the target genomes to be all leaves (minus the reference) if not otherwise directed.
    leafGenomes = [tree.getName(x) for x in tree.getLeaves()]
    if opts.refGenome not in leafGenomes:
        raise ValueError("Reference genome %s is not a leaf genome." % opts.refGenome)
    if opts.targets is None:
        opts.targets = [x for x in leafGenomes if x != opts.refGenome]
    else:
        opts.targets = opts.targets.split(',')
        if not all([x in leafGenomes for x in opts.targets]):
            raise ValueError("Some target genomes are not leaves.")

    try:
        os.makedirs(opts.outputDir)
    except:
        if not os.path.isdir(opts.outputDir):
            raise

    for target in opts.targets:
        refID = getTreeID(tree, opts.refGenome)
        targetID = getTreeID(tree, target)
        mrca = getMRCA(tree, refID, targetID)
        pathToTarget = getPath(opts.hal, opts.refGenome, target)
        pathUp, pathDown = [list(v) for k,v in groupby(pathToTarget, lambda x: x == tree.getName(mrca)) if k != True]
        bedForTarget = os.path.join(opts.outputDir, target + '.bed')
        # First, walk up the tree to the MRCA.
        for curGenome in pathUp:
            liftMutations(opts.halTreeMutationsDir, opts.hal, curGenome, opts.refGenome, bedForTarget)
        # Next, walk down the tree to the target.
        for curGenome in pathDown:
            liftMutations(opts.halTreeMutationsDir, opts.hal, curGenome, opts.refGenome, bedForTarget, reversePolarity=True)

if __name__ == '__main__':
    main()
