library(lattice)
library(reshape)
library(directlabels)

args <- commandArgs(trailingOnly = TRUE)
folder <- args[1]
input.filename <- args[2]
gc.content.file <-args[3]
output.img <- args[4]


data.tag <- read.delim( paste(folder, input.filename, sep="/") )
data.genome <- read.delim( paste(folder, gc.content.file, sep="/") )

data <- 
rbind(
	cbind( data.genome, data.frame(name="Genome") ),
	cbind( data.tag, data.frame(name="ChIP-fragment") )
)


png(filename=paste(folder, output.img, sep="/"), width=600, height=400, units="px")

direct.label(
	xyplot(Normalized.Fraction.PDF.~GC., data=data, groups=name, 
		type="l", lwd=2, 
		main=basename(folder), xlab="GC-content of fragments", ylab="Normalized fraction"
	)
)
dev.off()
