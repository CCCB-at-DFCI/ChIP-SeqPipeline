library(lattice)
library(reshape)
library(directlabels)

# options(echo=TRUE) # if you want see commands in output file
args <- commandArgs(trailingOnly = TRUE)
# print(args)
# trailingOnly=TRUE means that only your arguments are returned, check:
# print(commandsArgs(trailingOnly=FALSE))

folder <- args[1]
filename <- args[2]

data <- read.delim( paste(folder, "tagFreqUniq.txt", sep="/") )
data.stacked <- melt(data[,c("Offset","A","C","G","T")], id="Offset")


png(filename=paste(folder,"tagFreqUniq.png", sep="/"), width=600, height=300, units="px")

direct.label(xyplot(value~Offset, data=data.stacked, type="l", lwd=2, groups=variable, main=folder, xlab="Distance from 5' end of Reads", ylab="Nucleotide Frequency (Unique Tags)"))

dev.off()