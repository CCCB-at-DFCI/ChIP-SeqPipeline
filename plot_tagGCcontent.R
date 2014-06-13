library(lattice)
library(reshape)
library(directlabels)

# options(echo=TRUE) # if you want see commands in output file
args <- commandArgs(trailingOnly = TRUE)
# print(args)
# trailingOnly=TRUE means that only your arguments are returned, check:
# print(commandsArgs(trailingOnly=FALSE))

folder <- args[1]


data.tag <- read.delim( paste(folder, "tagGCcontent.txt", sep="/") )
data.genome <- read.delim( paste(folder, "genomeGCcontent.txt", sep="/") )

data <- 
rbind(
	cbind( data.genome, data.frame(name="Genome") ),
	cbind( data.tag, data.frame(name="ChIP-fragment") )
)


png(filename=paste(folder,"tagGCcontent.png", sep="/"), width=400, height=300, units="px")

direct.label(
	xyplot(Normalized.Fraction.PDF.~GC., data=data, groups=name, 
		type="l", lwd=2, 
		main=folder, xlab="GC-content of fragments", ylab="Normalized fraction"
	)
)

dev.off()