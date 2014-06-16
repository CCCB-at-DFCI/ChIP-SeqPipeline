args <- commandArgs(trailingOnly = TRUE)
folder <- args[1]
input.filename <- args[2]
output.img <- args[3]

tagLengthDistribution <- read.delim( paste(folder, input.filename, sep="/") )
# tagCountDistribution.1to10 <- tagCountDistribution[tagCountDistribution[,1]>=1 & tagCountDistribution[,1]<=10, ]

png(filename=paste(folder, output.img, sep="/"), width=600, height=400, units="px")

barplot(
	tagLengthDistribution[,2], 
	names.arg=tagLengthDistribution[,1], 
	ylim=c(0,1), 
	xlab="tagCountDistribution", 
	main=basename(folder),
)
dev.off() 
