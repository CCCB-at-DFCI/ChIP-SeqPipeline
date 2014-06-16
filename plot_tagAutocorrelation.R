#parse the command line args:
args <- commandArgs(trailingOnly = TRUE)
folder <- args[1]
input.filename <- args[2]
output.img<-args[3]

data <- read.delim( paste(folder, input.filename, sep="/") )

png(filename=paste(folder,output.img, sep="/"), width=600, height=400, units="px")

plot(data[,1], data[,2], type='l', col="blue",
	xlab="Relative distance between reads(bp)",
	ylab="Total read pairs",
	main=basename(folder)
)
lines(data[,1], data[,3],col="red")

dev.off()
