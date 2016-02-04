""""
jobTree program to generate UCSC chains and nets between two genomes in a HAL file.
In a library until import issue is fixed in toil.
This avoids running targets if file exists (FIXME: doesn't check date).
"""
import os
from hal import *
from pycbio.sys import fileOps
from pycbio.sys import procOps
from jobTree.scriptTree.target import Target
from jobTree.scriptTree.stack import Stack

def getLocalTempPath(target, *parts):
    "get path for temporary local file, last part is extension"
    return os.path.join(target.getLocalTempDir(), "_".join(parts[0:-1])+ "."+parts[-1])

def getGlobalTempPath(target, *parts):
    "get path for temporary global file, last part is extension"
    return os.path.join(target.getGlobalTempDir(), "_".join(parts[0:-1])+ "."+parts[-1])

def makeChromBedTmp(target, hal, chrom, chromSize):
    "create a BED file in local tmp covering one chromosome"
    bedFile = getLocalTempPath(target, chrom, "bed")
    with open(bedFile, "w") as fh:
        fileOps.prRowv(fh, chrom, 0, chromSize)
    return bedFile

def makeChromSizeTmp(target, prefix, twoBit):
    "create a tmp chrom sizes file from a twobit"
    chromSizeFile = getLocalTempPath(target, prefix, "size")
    procOps.callProc(["twoBitInfo", twoBit, chromSizeFile])
    return chromSizeFile

def getCompressCmd(path):
    compressCmd = fileOps.compressCmd(path)
    if compressCmd == None:
        return "cat"
    else:
        return compressCmd

def pipelineCompress(cmds, outFile):
    """execute the pipeline commands, which must write to stdout, optionally
    compressing based on extension of outFile.  cmds can be a single command
    as a list or a list of lists". Create outFile atomically"""
    if isinstance(cmds[0], str):
        cmds = [cmds]
    outFileTmp = fileOps.atomicTmpFile(outFile)
    fileOps.ensureFileDir(outFileTmp)
    procOps.runProc(cmds + [[getCompressCmd(outFile)]], stdout=outFileTmp)
    fileOps.atomicInstall(outFileTmp, outFile)
        
def chainChromTarget(target, hal, queryGenome, queryChromSize, queryTwoBit, queryChrom, targetGenome, targetTwoBit, chainFile):
    "target to chain one chromosome"
    queryBed = makeChromBedTmp(target, hal, queryChrom, queryChromSize)
    #  --inMemory caused out of memory in with some alignments with 31G allocated
    procOps.callProc([["halLiftover", "--outPSL", hal, queryGenome, queryBed, targetGenome, "/dev/stdout"],
                      ["pslPosTarget", "/dev/stdin", "/dev/stdout"],
                      ["axtChain", "-psl", "-verbose=0", "-linearGap=medium", "/dev/stdin", targetTwoBit, queryTwoBit, chainFile]])

def chainChromMakeChildren(target, hal, queryGenome, queryTwoBit, targetGenome, targetTwoBit):
    "create child jobs to do per-chrom chaining"
    queryChromSizes = halGetChromSizes(hal, queryGenome)
    chromChainFiles = []
    for queryChrom in queryChromSizes.iterkeys():
        chromChain = getGlobalTempPath(target, queryGenome, queryChrom, targetGenome, "chain")
        chromChainFiles.append(chromChain)
        target.addChildTargetFn(chainChromTarget, (hal, queryGenome, queryChromSizes[queryChrom], queryTwoBit, queryChrom, targetGenome, targetTwoBit, chromChain),
                                memory=16 * 1024 ** 3)
    return chromChainFiles
    
def chainConcatTarget(target, chromChainFiles, chainFile):
    "concatenate per-chrom chain files, create chainFile atomically"
    chromChainList = getLocalTempPath(target, "inChains", "lst")
    with open(chromChainList, "w") as fh:
        fh.write('\n'.join(chromChainFiles) + '\n')
    pipelineCompress(["chainMergeSort", "-inputList="+chromChainList, "-tempDir="+target.getLocalTempDir()+"/"],
                     chainFile)

def chainTarget(target, hal, queryGenome, queryTwoBit, targetGenome, targetTwoBit, chainFile):
    "chain, splitting into sub-chromosome jobs"
    chromChainFiles = chainChromMakeChildren(target, hal, queryGenome, queryTwoBit, targetGenome, targetTwoBit)
    target.setFollowOnTargetFn(chainConcatTarget, (chromChainFiles, chainFile))

def netTarget(target, queryTwoBit, targetTwoBit, chainFile, netFile):
    "run netting process on chains, net is created atomically"
    queryChromSizesFile = makeChromSizeTmp(target, "query", queryTwoBit)
    targetChromSizesFile = makeChromSizeTmp(target, "target", targetTwoBit)
    pipelineCompress([["chainAntiRepeat", targetTwoBit, queryTwoBit, chainFile, "/dev/stdout"],
                     ["chainNet", "-minSpace=1", "/dev/stdin", targetChromSizesFile, queryChromSizesFile, "/dev/stdout", "/dev/null"],
                     ["netSyntenic", "/dev/stdin", "/dev/stdout"]],
                     netFile)
    
def netsTarget(target, queryTwoBit, targetTwoBit, chainFile, netFile):
    "make nets"
    if not os.path.exists(netFile):
        target.addChildTargetFn(netTarget, (queryTwoBit, targetTwoBit, chainFile, netFile), memory=16 * 1024 ** 3)
    
def chainNetTarget(target, hal, queryGenome, queryTwoBit, targetGenome, targetTwoBit, chainFile, netFile):
    "main entry point that does chain and then netting"
    if not os.path.exists(chainFile):
        target.addChildTargetFn(chainTarget, (hal, queryGenome, queryTwoBit, targetGenome, targetTwoBit, chainFile))
    target.setFollowOnTargetFn(netsTarget, (queryTwoBit, targetTwoBit, chainFile, netFile))

def chainNetStartup(opts):
    "entry to start jobtree"
    # FIXME: should generate an exception
    target = Target.makeTargetFn(chainNetTarget, (opts.hal, opts.queryGenome, opts.queryTwoBit, opts.targetGenome, 
                                                  opts.targetTwoBit, opts.chainFile, opts.netFile))
    failures = Stack(target).startJobTree(opts)
    if failures != 0:
        raise Exception("Error: " + str(failures) + " jobs failed")
    
