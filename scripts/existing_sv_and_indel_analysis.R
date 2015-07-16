#!/usr/bin/env Rscript
if (!require(pacman)) {
    install.packages("pacman", repos=c("https://cran.rstudio.com/",
                                       "http://cran.rstudio.com/",
                                       "http://cran.r-project.org/"))
}
pacman::p_load(ggplot2, argparse)

parser <- ArgumentParser()
parser$add_argument("sdpBed", help="bed file generated from sdp file by parseSDP.py")
parser$add_argument("outputDir", help="output directory")

args <- parser$parse_args()

if (system(paste("mkdir -p", args$outputDir))) {
    write("Invalid output directory\n", stderr())
    stop()
}

sdp <- read.table(args$sdpBed)
sdp$size <- sdp$V3 - sdp$V2
# Get a field with the inversion type--this is in the bed field separated from the
# species by a "\"
sdp$type <- sapply(sdp$V4, function(x) { strsplit(as.character(x), "\\\\")[[1]][[2]] })
# Likewise, the species is just the first "\"-separated field in the name
sdp$species <- sapply(sdp$V4, function(x) { strsplit(as.character(x), "\\\\")[[1]][[1]] })
# sdp_size_vs_type.pdf: plot the size of an SV vs its type in the sdp file
pdf(paste(args$outputDir, "sdp_size_vs_type.pdf", sep="/"), width=12.6, height=7.87)
print(ggplot(sdp, aes(x=size))
      + facet_wrap(~ type, scales="free_y")
      + geom_density()
      + scale_x_log10()
      + theme_bw())
dev.off()
