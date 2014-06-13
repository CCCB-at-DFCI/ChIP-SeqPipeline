# options(echo=TRUE) # if you want see commands in output file
args <- commandArgs(trailingOnly = TRUE)
# print(args)
# trailingOnly=TRUE means that only your arguments are returned, check:
# print(commandsArgs(trailingOnly=FALSE))

folder <- args[1]
filename <- args[2]

data <- read.delim( paste(folder, "tagAutocorrelation.txt", sep="/") )
data.1to10 <- data[data[,1]>=1 & data[,1]<=10, ]

png(filename=paste(folder,"tagAutocorrelation.png", sep="/"), width=600, height=400, units="px")

plot(data[,1], data[,2], type='l', col="blue",
	xlab="Relative distance between reads(bp)",
	ylab="Total read pairs",
	main=folder
)
lines(data[,1], data[,3],col="red")

dev.off()