MouseGenomesAnnotationPipeline
========

This pipeline was used to comparatively annotate the mouse strains for the Mouse Genomes Project.

#Methodology

The progressiveCactus whole genome alignments were used to project annotations from GENCODE VM8 [26187010] on to each of the strain specific assemblies using transMap [18218656]. These projection transcripts were evaluated by a series of binary classifiers that attempt to diagnose differences between the parent and target genome. These classifiers include evaluating if a transcript maps multiple times, the proportion of unknown bases, splice site validity, both frameshifting and non-frameshifting indels, small alignment gaps, These comparative transcripts were given to the gene-finding tool AUGUSTUS [16469098] as strong hints in conjunction with weaker hints derived from all available RNA-seq data for the given strain. These transcripts were classified by further binary classifiers that evaluate whether AUGUSTUS introduced new exons, removed mapped exons, or shifted splice junction boundaries in transcript coordinates more than would be expected.

The transcripts resulting from both transMap as well as AUGUSTUS were evaluated by a consensus finding algorithm. First, transcripts are evaluated as being excellent, passing or failing based on queries against the binary classification database. [Excellent coding transcripts](https://github.com/ucsc-mus-strain-cactus/comparativeAnnotator/blob/luigi_v2/database_queries.py#L91-L123) are those that have at least 99% alignment coverage and fewer than 1% unknown bases. In addition, each transMap transcript must pass binary classifiers that test if the original start/stop positions are faithfully mapped over, any in frame stops are introduced, or if any splice sites are not in the set of known splices. Passing requirements for coding transcripts relax the coverage and unknown base requirements slightly, as well as allowing any of the above binary classifiers to fail. Both excellent and passing transcripts must pass the [intron inequality](https://github.com/ucsc-mus-strain-cactus/comparativeAnnotator/blob/luigi_v2/database_queries.py#L101-L103), which measures the possibility of the projection transcript being a retroposed copy by looking at how many new introns are introduced in transcript coordinate space. Any transcript that does not meet the passing requirements is labelled as failing.

Once transcripts have been assigned to bins, they are evaluated on a per-gene basis. If any transcript for a gene is at least passing, then the transMap and AUGUSTUS version are chosen between based on a [weighted average](https://github.com/ucsc-mus-strain-cactus/comparativeAnnotator/blob/luigi_v2/generate_gene_set.py#L114-L156) of coverage, identity and percent of introns supported by RNA-seq. If all transcripts for a gene are marked as failing, or all transcripts for a gene are less than half of the original genomic size, then isoforms are collapsed and one [longest transcript](https://github.com/ucsc-mus-strain-cactus/comparativeAnnotator/blob/luigi_v2/generate_gene_set.py#L267-L296) is picked to represent the locus.

Subsequent to this, transcripts produced by Stefanie using the new mode of AUGUSTUS called AugustusCGP were incorporated. The AugustusCGP transcripts were incorporated into the consensus gene set through a subsequent round of consensus finding. Based on coordinate intersections, each transcript was assigned a putative parent gene, if possible. If multiple assignments were created, they were attempted to be [resolved](https://github.com/ucsc-mus-strain-cactus/comparativeAnnotator/blob/luigi_v2/scripts/find_cgp_jaccard.py) by finding if any gene had a Jaccard distance 0.2 greater than any other; otherwise, they were discarded. After parent assignment, they were aligned with BLAT [11932250] to each coding transcript associated with the parent gene. Additionally, each consensus transcript had its CDS aligned. This is because AugustusCGP does not create UTR records, and it would be an unfair comparison otherwise as UTR sequence is generally more incomplete and harder to align.

For each AugustusCGP transcript, if it had a [better match to the CDS](https://github.com/ucsc-mus-strain-cactus/comparativeAnnotator/blob/luigi_v2/scripts/cgp_consensus.py#L188-L215) of any of the assigned transcripts than the current consensus transcript, it was replaced. If the AugustusCGP transcript introduced [new intron](https://github.com/ucsc-mus-strain-cactus/comparativeAnnotator/blob/luigi_v2/scripts/cgp_consensus.py#L109-L119) junctions supported by RNAseq, then it was incorporated as a new isoform of that gene. If the AugustusCGP transcript was [not assigned to any gene](https://github.com/ucsc-mus-strain-cactus/comparativeAnnotator/blob/luigi_v2/scripts/cgp_consensus.py#L134-L143), it was incorporated as a putative novel gene. Finally, if the AugustusCGP transcript was [associated with a gene not in the consensus gene set](https://github.com/ucsc-mus-strain-cactus/comparativeAnnotator/blob/luigi_v2/scripts/cgp_consensus.py#L146-L168), it was included. This process allows for the rescue of genes lost in the first round of filtering and consensus finding, as well as the discovery of polymorphic pseudogenes in the laboratory mouse lineage.

For the strains CAST/EiJ, PWK/PhJ and SPRET/EiJ, PacBio RNAseq data were also generated. These were used as hints to AUGUSTUS to generate another gene set. These were combined with the AugustusCGP transcripts and consensus finding was performed. See the [luigi_pacbio](https://github.com/ucsc-mus-strain-cactus/comparativeAnnotator/tree/luigi_pacbio) branch for the small changes to the code for this process.

The final consensus gene sets were split into two groups -- basic and comprehensive. This is similar to the [Ensembl/GENCODE](https://github.com/Ensembl/ensembl-analysis/blob/master/scripts/Merge/label_gencode_basic_transcripts.pl) methodology. Briefly, coding transcripts were retained if they were marked as having complete end information. If no complete transcripts are present, one longest CDS is picked for the gene. For noncoding transcripts, the fewest number of transcripts to keep at least 80% of present non-coding splice junctions were retained. [Script](https://github.com/ucsc-mus-strain-cactus/comparativeAnnotator/blob/luigi_v2/scripts/generate_basic_comprehensive.py).

Finally, [unique strain-specific identifiers](https://github.com/ucsc-mus-strain-cactus/comparativeAnnotator/blob/luigi_v2/scripts/generate_unique_ids.py) were assigned to each gene and transcript.

#Installation

To run this pipeline, you will need the following requirements:

1. The [Kent](https://github.com/ucscGenomeBrowser/kent) code base installed as on your path 
2. Python 2.7 on your path with the following packages installed: pyfasta, numpy, pandas, matplotlib, seaborn, peewee, sqlalchemy
3. You will need to compile the program postTransMapChain present in this repo and place it on your path.

If you are planning to run the AUGUSTUS portion of the pipeline, it is strongly recommended that you use a cluster. Supported cluster systems include parasol, gridEngine and LSF. You will need to generate a hints database from pre-aligned BAM files. Use [this script](https://github.com/ucsc-mus-strain-cactus/MouseGenomesAnnotationPipeline/blob/master/scripts/generate_hints_db.py) to generate the hints database. AUGUSTUS can be run without a hints database (AugustusTM), but this is not recommended.

Once you have the database prepared, you need the input files. The 3 input files to the pipeline are 1) A progressiveCactus alignment (HAL) file, 2) a reference gene set in genePred format, and 3) a tab separated file with the following columns:

1. GeneId
2. GeneName
3. GeneType
4. TranscriptId
5. TranscriptType

This file can be generated by the following query against the UCSC database:

`hgsql -e 'select geneId,geneName,geneType,transcriptId,transcriptType from ${srcGencodeAttrs}' ${srcOrgHgDb}`

Where `${srcGencodeAttrs}` is the database table, such as `wgEncodeGencodeAttrsVM8` for the version used in this paper.

With these inputs, you can launch the [main pipeline](https://github.com/ucsc-mus-strain-cactus/MouseGenomesAnnotationPipeline/blob/master/pipeline/run_pipeline.py). The invocation used for the publication version of the gene set was:

`python pipeline/run_pipeline.py --geneSets geneSet=GencodeCompVM8 sourceGenome=C57B6J genePred=gencode_vm8/C57B6J_with_pseudogenes.gp attributesTsv=gencode_vm8/C57B6J.tsv --workDir mouse_work_v5 --outputDir mouse_output_v5 --hal ~/mus_strain_data/pipeline_data/comparative/1509/cactus/1509.hal --batchSystem parasol --localCores 10 --maxThreads 25 --augustusHints mouse_v3.db  --norestart --jobTreeDir v5_jobTrees  --augustus`

