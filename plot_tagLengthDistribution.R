# options(echo=TRUE) # if you want see commands in output file
args <- commandArgs(trailingOnly = TRUE)
# print(args)
# trailingOnly=TRUE means that only your arguments are returned, check:
# print(commandsArgs(trailingOnly=FALSE))

folder <- args[1]

tagLengthDistribution <- read.delim( paste(folder, "tagLengthDistribution.txt", sep="/") )
# tagCountDistribution.1to10 <- tagCountDistribution[tagCountDistribution[,1]>=1 & tagCountDistribution[,1]<=10, ]

png(filename=paste(folder,"tagLengthDistribution.png", sep="/"), width=400, height=300, units="px")

barplot(
	tagLengthDistribution[,2], 
	names.arg=tagLengthDistribution[,1], 
	ylim=c(0,1), 
	xlab="tagCountDistribution", 
	main=folder,
)

dev.off() 