# Checks for the necessary R packages:

is.installed <- function(lib) is.element(lib, installed.packages()[,1]) 

tryCatch(
		{
			if(!is.installed("lattice")){install.packages("lattice")}
			if(!is.installed("reshape")){install.packages("reshape")}
			if(!is.installed("directlabels")){install.packages("directlabels")}
		},
		error = function()
		{
			stop("There was an error checking and installing R dependencies.  Please read the documentation and manually install the required packages.")
		}
)
