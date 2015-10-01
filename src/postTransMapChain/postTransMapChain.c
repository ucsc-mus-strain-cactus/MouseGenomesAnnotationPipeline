static char *usageMsg =
    "postTransMapChain [options] inPsl outPsl\n"
    "\n"
    "Post genomic TransMap chaining.  This takes transcripts\n"
    "that have been mapped via genomic chains adds back in\n"
    "blocks that didn't get include in genomic chains due\n"
    "to complex rearrangements or other issues.\n"
    ;

#include "common.h"
#include "linefile.h"
#include "options.h"
#include "hash.h"
#include "psl.h"
#include <string.h>

/* command line options and values */
static struct optionSpec optionSpecs[] = {
    {"h", OPTION_BOOLEAN},
    {"help", OPTION_BOOLEAN},
    {NULL, 0}
};

static int maxAdjacentDistance = 50*1000*1000;  // 50mb

/* special status used to in place of chain */
static const int CHAIN_NOT_HERE = -1;
static const int CHAIN_CAN_NOT = -2;

/* load PSLs in to hash by qName.  Make sure target strand is positive
 * to make process easier later. */
static struct hash* loadPslByQname(char* inPslFile) {
    struct hash* pslsByQName = hashNew(0);
    struct psl *psls = pslLoadAll(inPslFile);
    struct psl *psl;
    while ((psl = slPopHead(&psls)) != NULL) {
        if (pslTStrand(psl) != '+') {
            pslRc(psl);
        }
        struct hashEl *hel = hashStore(pslsByQName, psl->qName);
        struct psl** queryPsls = (struct psl**)&hel->val;
        slAddHead(queryPsls, psl);
    }
    return pslsByQName;
}

/* get target span */
static int pslTSpan(const struct psl* psl) {
    return psl->tEnd - psl->tStart;
}

/* Compare to sort based on target, strand,  tStart, and then span */
static int pslCmpTargetAndStrandSpan(const void *va, const void *vb) {
    const struct psl *a = *((struct psl **)va);
    const struct psl *b = *((struct psl **)vb);
    int dif;
    dif = strcmp(a->tName, b->tName);
    if (dif == 0)
        dif = strcmp(a->strand, b->strand);
    if (dif == 0)
        dif = -(pslTSpan(a) - pslTSpan(b));
    return dif;
}

/* return strand as stored in psl, converting implicit `\0' to `+' */
static char normStrand(char strand) {
    return (strand == '\0') ? '+' : strand;
}

/* return query start for the given block, mapped to specified strand,
 * which can be `\0' for `+' */
static unsigned pslQStartStrand(struct psl *psl, int blkIdx, char strand) {
    if (psl->strand[0] == normStrand(strand)) {
        return psl->qStarts[blkIdx];
    } else {
        return psl->qSize - pslQEnd(psl, blkIdx);
    }
}

/* return query end for the given block, mapped to specified strand,
 * which can be `\0' for `+' */
static unsigned pslQEndStrand(struct psl *psl, int blkIdx, char strand) {
    if (psl->strand[0] == normStrand(strand)) {
        return pslQEnd(psl, blkIdx);
    } else {
        return psl->qSize - pslQStart(psl, blkIdx);
    }
}

/* return target start for the given block, mapped to specified strand,
 * which can be `\0' for `+' */
static unsigned pslTStartStrand(struct psl *psl, int blkIdx, char strand) {
    if (normStrand(psl->strand[1]) == normStrand(strand)) {
        return psl->tStarts[blkIdx];
    } else {
        return psl->tSize - pslTEnd(psl, blkIdx);
    }
}

/* return target end for the given block, mapped to specified strand,
 * which can be `\0' for `+' */
static unsigned pslTEndStrand(struct psl *psl, int blkIdx, char strand) {
    if (normStrand(psl->strand[1]) == normStrand(strand)) {
        return pslTEnd(psl, blkIdx);
    } else {
        return psl->tSize - pslTStart(psl, blkIdx);
    }
}

/*
 * findChainPoint upstream check.
 */
static int findChainPointUpstream(struct psl* chainedPsl,
                                  struct psl* nextPsl) {
    // check next being query upstream of chain
    if ((pslQEnd(nextPsl, nextPsl->blockCount-1) <= pslQStart(chainedPsl, 0))
        && (pslTEnd(nextPsl, nextPsl->blockCount-1) <= pslTStart(chainedPsl, 0))) {
        if ((pslTStart(chainedPsl, 0) - pslTEnd(nextPsl, nextPsl->blockCount-1)) > maxAdjacentDistance) {
            return CHAIN_CAN_NOT;  // too far before
        } else {
            return 0;
        }
    } else {
        return CHAIN_NOT_HERE;
    }
}

/*
 * findChainPoint downstream check.
 */
static int findChainPointDownstream(struct psl* chainedPsl,
                                    struct psl* nextPsl) {
    if ((pslQStart(nextPsl, 0) >= pslQEnd(chainedPsl, chainedPsl->blockCount-1))
        && (pslTStart(nextPsl, 0) >= pslTEnd(chainedPsl, chainedPsl->blockCount-1))) {
        if ((pslTStart(nextPsl, 0) - pslTEnd(chainedPsl, chainedPsl->blockCount-1)) > maxAdjacentDistance) {
            return CHAIN_CAN_NOT;  // too far after
        } else {
            return chainedPsl->blockCount;
        }
    } else {
        return CHAIN_NOT_HERE; 
    }
}

/* does next fit between two chained PSL blocks */
static int isBetweenBlocks(struct psl* chainedPsl,
                           struct psl* nextPsl,
                           int insertIdx) {
    return (pslQEnd(chainedPsl, insertIdx-1) <= pslQStart(nextPsl, 0))
        && (pslTEnd(chainedPsl, insertIdx-1) <= pslTStart(nextPsl, 0))
        && (pslQEnd(nextPsl, nextPsl->blockCount-1) <= pslQStart(chainedPsl, insertIdx))
        && (pslTEnd(nextPsl, nextPsl->blockCount-1) <= pslTStart(chainedPsl, insertIdx));
}

/*
 * find internal insertion point between block of chainedPsl.
 */
static int findChainPointInternal(struct psl* chainedPsl,
                                  struct psl* nextPsl) {
    for (int insertIdx = 1; insertIdx < chainedPsl->blockCount; insertIdx++) {
        if (isBetweenBlocks(chainedPsl, nextPsl, insertIdx)) {
            return insertIdx;
        }
    }
    return CHAIN_CAN_NOT;
}

/* 
 * return the position in the chained PSL where a PSL can be added.  This
 * returns the block-index of where to insert the PSL, blockCount if to added
 * after, or one of the negative constants if it should not be chained.
 * assumes it chainedPsl has longest target span so we only look for insert
 * in chainPsl and not the other way around. */
static int findChainPoint(struct psl* chainedPsl,
                          struct psl* nextPsl) {
    if (!(sameString(chainedPsl->tName, nextPsl->tName)
          && sameString(chainedPsl->strand, nextPsl->strand))) {
        return CHAIN_CAN_NOT;  // not on same seq/strand
    }
    int insertIdx = findChainPointUpstream(chainedPsl, nextPsl);
    if (insertIdx != CHAIN_NOT_HERE) {
        return insertIdx;
    }    
    insertIdx = findChainPointDownstream(chainedPsl, nextPsl);
    if (insertIdx != CHAIN_NOT_HERE) {
        return insertIdx;
    }
    insertIdx = findChainPointInternal(chainedPsl, nextPsl);
    return insertIdx;
}

/* Grow one of the psl arrays and move contents down
 * to make room, and copy new entries */
static void pslArrayInsert(unsigned **destArray,
                           int numDestBlocks,
                           unsigned *srcArray,
                           int numSrcBlocks,
                           int insertIdx) {
    *destArray = needMoreMem(*destArray, numDestBlocks*sizeof(unsigned), (numDestBlocks+numSrcBlocks)*sizeof(unsigned));
    for (int iBlk = numDestBlocks-1; iBlk >= insertIdx; iBlk--) {
        assert(iBlk+numSrcBlocks < numDestBlocks+numSrcBlocks);
        (*destArray)[iBlk+numSrcBlocks] = (*destArray)[iBlk];
    }
    for (int iBlk = 0; iBlk < numSrcBlocks; iBlk++) {
        assert(iBlk+insertIdx < numDestBlocks+numSrcBlocks);
        (*destArray)[iBlk+insertIdx] = srcArray[iBlk];
    }
}

/* add blocks form a psl to the chained psl at the given point */
static void addPslToChained(struct psl* chainedPsl,
                            struct psl* nextPsl,
                            int insertIdx) {
    assert(insertIdx <= chainedPsl->blockCount);
    // expand arrays and copy in entries
    pslArrayInsert(&chainedPsl->blockSizes, chainedPsl->blockCount, nextPsl->blockSizes, nextPsl->blockCount, insertIdx);
    pslArrayInsert(&chainedPsl->qStarts, chainedPsl->blockCount, nextPsl->qStarts, nextPsl->blockCount, insertIdx);
    pslArrayInsert(&chainedPsl->tStarts, chainedPsl->blockCount, nextPsl->tStarts, nextPsl->blockCount, insertIdx);
    chainedPsl->blockCount += nextPsl->blockCount;

    // update bounds if needed
    if (pslQStrand(chainedPsl) == '+') {
        chainedPsl->qStart = pslQStartStrand(chainedPsl, 0, '+');
        chainedPsl->qEnd = pslQEndStrand(chainedPsl, chainedPsl->blockCount-1, '+');
    } else {
        chainedPsl->qStart = pslQStartStrand(chainedPsl, chainedPsl->blockCount-1, '+');
        chainedPsl->qEnd = pslQEndStrand(chainedPsl, 0, '+');
    }
    assert(pslTStrand(chainedPsl) == '+');
    chainedPsl->tStart = pslTStartStrand(chainedPsl, 0, '+');
    chainedPsl->tEnd = pslTEndStrand(chainedPsl, chainedPsl->blockCount-1, '+');
    
    // update counts
    chainedPsl->match += nextPsl->match;
    chainedPsl->misMatch += nextPsl->misMatch;
    chainedPsl->repMatch += nextPsl->repMatch;
    chainedPsl->nCount += nextPsl->nCount;
}

/* pull off one or more psls from the list and chain them */
static void chainToLongest(struct psl** queryPsls,
                           FILE* outPslFh) {
    struct psl* chainedPsl = slPopHead(queryPsls);
    struct psl* unchainedPsls = NULL;  // ones not included
    struct psl* nextPsl;
    while ((nextPsl = slPopHead(queryPsls)) != NULL) {
        int insertIdx = findChainPoint(chainedPsl, nextPsl);
        if (insertIdx >= 0) {
            addPslToChained(chainedPsl, nextPsl, insertIdx);
            pslFree(&nextPsl);
        } else {
            slAddHead(&unchainedPsls, nextPsl);
        }
    }
    pslComputeInsertCounts(chainedPsl);
    pslTabOut(chainedPsl, outPslFh);
    pslFree(&chainedPsl);
    slReverse(&unchainedPsls); // preserve longest to shortest order
    *queryPsls = unchainedPsls;
}

/* make chains for a single query. Takes over ownership
 * of PSLs */
static void chainQuery(struct psl** queryPsls,
                       FILE* outPslFh) {
    // sort by genomic location, then pull of a group to
    // to chain
    slSort(queryPsls, pslCmpTargetAndStrandSpan);
    while (*queryPsls != NULL) {
        chainToLongest(queryPsls, outPslFh);
    }
}

/* do chaining */
static void postTransMapChain(char* inPslFile,
                              char* outPslFile) {
    struct hash* pslsByQName = loadPslByQname(inPslFile);
    FILE* outPslFh = mustOpen(outPslFile, "w");
    struct hashEl *hel;
    struct hashCookie cookie = hashFirst(pslsByQName);
    while ((hel = hashNext(&cookie)) != NULL) {
        struct psl** queryPsls = (struct psl**)&hel->val;
        chainQuery(queryPsls, outPslFh);
    }
    carefulClose(&outPslFh);
}

/* entry */
int main(int argc, char **argv) {
    optionInit(&argc, argv, optionSpecs);
    if (optionExists("h") || optionExists("help"))
        errAbort("usage: %s", usageMsg);
    if (argc != 3) {
        errAbort("wrong # of args: %s", usageMsg);
    }
    postTransMapChain(argv[1], argv[2]);
    return 0;
}


