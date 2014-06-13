# options(echo=TRUE) # if you want see commands in output file
args <- commandArgs(trailingOnly = TRUE)
# print(args)
# trailingOnly=TRUE means that only your arguments are returned, check:
# print(commandsArgs(trailingOnly=FALSE))

folder <- args[1]
filename <- args[2]

tagCountDistribution <- read.delim( paste(folder, "tagCountDistribution.txt", sep="/") )
tagCountDistribution.1to10 <- tagCountDistribution[tagCountDistribution[,1]>=1 & tagCountDistribution[,1]<=10, ]

png(filename=paste(folder,"tagCountDistribution.png", sep="/"), width=400, height=300, units="px")

barplot(
	tagCountDistribution.1to10[,2], 
	names.arg=tagCountDistribution.1to10[,1], 
	ylim=c(0,1), 
	xlab="tagCountDistribution", 
	main=folder,
)

dev.off()