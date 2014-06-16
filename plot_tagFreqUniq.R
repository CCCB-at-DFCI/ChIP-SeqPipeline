library(lattice)
library(reshape)
library(directlabels)

args <- commandArgs(trailingOnly = TRUE)
folder <- args[1]
input.filename <- args[2]
output.img <- args[3]

data <- read.delim( paste(folder, input.filename, sep="/") )
data.stacked <- melt(data[,c("Offset","A","C","G","T")], id="Offset")


png(filename=paste(folder, output.img, sep="/"), width=600, height=300, units="px")

direct.label(xyplot(value~Offset, 
		data=data.stacked, 
		type="l", 
		lwd=2, 
		groups=variable, 
		main=basename(folder), 
		xlab="Distance from 5' end of Reads", 
		ylab="Nucleotide Frequency (Unique Tags)"
		)
	)
dev.off()
