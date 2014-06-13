#!/bin/bash


##########################################################

# initialize some variables:

echo "Checking dependencies..."

#check for java
if ! which java ; then
	echo "Could not find java in current directory or in PATH"
	exit 1
fi

#check for Rscript
if ! which Rscript ; then
	echo "Could not locate the Rscript engine in current directory or PATH"
	exit 1
fi

PYTHON='/cccbstore-rc/projects/cccb/apps/bin/python2.7'
#check for python- for regex syntax need 2.7 or greater!
if ! which $PYTHON ; then
	echo "Could not access python located at $PYTHON.  Require version 2.7 or greater"
	exit 1
fi

# add samtools to PATH
export PATH=/cccbstore-rc/projects/cccb/apps/samtools-0.1.19/:$PATH
if ! which samtools ; then
	echo "Could not locate samtools in current directory or PATH: "$PATH 
	exit 1
fi

######################################################################################


#  a function that prints the proper usage syntax
function usage
{
	echo "**************************************************************************************************"
	echo "usage: 
		-d | --dir sample_directory
		-config (configuration file) 
		-s | --samples samples_file 
		-c | --contrasts contrast_file (optional) 
		-g | --genome
		-peakMode (optional, default is 'factor' for TFBS.  set to 'histone' for histone marks)
                -noalign (optional, default behavior is to align) 
                -paired (optional, default= single-end) 
		-test (optional, for simple test)"
	echo "**************************************************************************************************"
}


#  expects the following args:
#  $1: a file containing the chIP sample and input sample (tab-separated) (one per line)
function print_sample_report
{
	if [ -e $1 ]; then
		echo ""
		printf "%s\t%s\n" ChIP-sample Input-Sample
		 while read line; do
			printf "%s\t%s\n" $(echo $line | awk '{print $1}') $(echo $line | awk '{print $2}')
		done < $1
		echo ""
		echo ""
	else
		echo "Sample file ("$1") was not found."
	fi
}


#  expects the following args:
#  $1: a file containing the base/control and experimental/case condition for comparison (tab-separated) (one per line)
function print_contrast_report
{
	if [ -e $1 ]; then
		echo ""
		printf "%s\t%s\n" Base/Control Case/Condition
	        while read line; do
			printf "%s\t%s\n" $(echo $line | awk '{print $1}') $(echo $line | awk '{print $2}')
		done < $1
		echo ""
		echo ""
	else
		echo "Contrast file ("$1") was not found.  Contrasts will be performed between all ChIP samples."
	fi
}



##########################################################

#read input from commandline:
while [ "$1" != "" ]; do
	case $1 in
		-c | --contrasts )
			shift
			CONTRAST_FILE=$1
			;;
		-d | --dir )
			shift
			PROJECT_DIR=$1
			;;
		-g | --genome )
			shift
			ASSEMBLY=$1
			;;
		-config )
			shift
			CONFIG=$1
			;;
		-peakMode )
			shift
			PEAKMODE=$1
			;;
		-s | --samples )
			shift
			SAMPLES_FILE=$1
			;;
		-noalign )
			ALN=0
			;;
		-paired )
			PAIRED_READS=1
			;;
		-h | --help )
			usage
			exit
			;;
		-test )
			TEST=1
			;;
		* )
			usage
			exit 1
	esac
	shift
done

############################################################


############################################################

#check that we have all the required input:

if [ "$PROJECT_DIR" == "" ]; then
    echo ""
    echo "ERROR: Missing the project directory.  Please try again."
    usage
    exit 1
fi

if [ "$SAMPLES_FILE" == "" ]; then
    echo ""
    echo "ERROR: Missing the samples file.  Please try again."
    usage
    exit 1
fi

if [ "$ASSEMBLY" == "" ]; then
    echo ""
    echo "ERROR: Missing the genome.  Please try again."
    usage
    exit 1
fi

# Set some default parameters if they were not explicitly set in the input args:

#if ALN was not set, then -noalign flag was NOT invoked, meaning we DO align
if [ "$ALN" == "" ]; then
    ALN=1	
fi

#if PAIRED_READS was not set, then default to single-end
if [ "$PAIRED_READS" == "" ]; then
    PAIRED_READS=0
fi

#if TEST was not set, then do NOT test
if [ "$TEST" == "" ]; then
    TEST=0
fi

if [ "$CONFIG" == "" ]; then
    CONFIG=/cccbstore-rc/projects/cccb/pipelines/ChIP_Seq_pipeline/config.txt
    echo ""
    echo "Using the default configuration file located at: "$CONFIG
fi



# After inputs have been read, proceed with setting up parameters based on these inputs:

#read-in the non-dynamic configuration parameters (and export via set to have these as environment variables):
if [[ ! -f "$CONFIG" ]]; then
    echo "Could not locate a configuration file at "$CONFIG
    exit 1
fi 


# !!! important-- import the configuration file !!!
set -a
source $CONFIG
set +a


if [ "$PEAKMODE" == "$HISTONE" ]; then 
	echo "Searching for histone marks and setting the motif detection region size to "$MOTIF_HISTONE_REGION_SIZE
	echo "Can change this in the configuration file, if desired.(see HOMER documentation)"
	MOTIF_REGION_SIZE=$MOTIF_HISTONE_REGION_SIZE
	PEAKFILE_NAME=$HISTONE_PEAKFILE_NAME
else
	PEAKMODE=$FACTOR
	MOTIF_REGION_SIZE=$MOTIF_TF_REGION_SIZE
	echo ""
	echo "Searching for transcription factor binding sites, and setting the motif region size to $MOTIF_TF_REGION_SIZE.
	echo "Can change this in the configuration file, if desired.(see HOMER documentation)"
	PEAKFILE_NAME=$TF_PEAKFILE_NAME
fi


#export some variables to environment variables so they can be read by the other scripts
export PROJECT_DIR
export SAMPLES_FILE
export ASSEMBLY
export PAIRED_READS
export VALID_SAMPLE_FILE=$PROJECT_DIR'/'$VALID_SAMPLE_FILE
export PEAKFILE_NAME
#############################################################

#identify the correct genome files to use
if [[ "$ASSEMBLY" == hg19 ]]; then

    GENOME_INDEX=/cccbstore-rc/projects/cccb/indecis/Homo_sapiens/UCSC/hg19/Sequence/BWAIndex/genome.fa
    GTF=/cccbstore-rc/projects/db/genomes/Human/GRCh37.75/GTF/Homo_sapiens.GRCh37.75.gtf
    GENOMEFASTA=/cccbstore-rc/projects/db/genomes/Human/GRCh37.75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa
elif [[ "$ASSEMBLY" == mm10 ]]; then
    GTF=/cccbstore-rc/projects/db/genomes/Mm/build38/Mus_musculus.GRCm38.75.chr_trimmed.gtf
    GENOMEFASTA=/cccbstore-rc/projects/db/genomes/Mm/build38/mm10.fa
    GENOME_INDEX= #TODO
else
    echo "Unknown or un-indexed genome."
    exit 1
fi

export GENOME_INDEX
export GTF

#############################################################


############################################################

#print out the parameters for logging:

echo ""
echo "Will attempt to perform analysis on samples (from "$SAMPLES_FILE"):"
print_sample_report $SAMPLES_FILE
echo ""
if [ "$CONTRAST_FILE" == "" ]; then
	echo "Will perform all-vs-all differential peak analysis since no contrast file was supplied."
else
	echo "Will attempt to perform the following contrasts (from "$CONTRAST_FILE"):"
	print_contrast_report $CONTRAST_FILE
fi
echo ""
echo "Project home directory: "$PROJECT_DIR
if [ $ALN -eq $NUM1 ]; then
	echo "Alignment will be performed against: "$ASSEMBLY
fi
echo ""
echo ""

############################################################


#function to call the alignment script
#first argument is the alignment script (absolute path)
function do_align
{
	echo "Run alignment with script at: "
	echo $PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$sample'/'$sample$FORMATTED_ALIGN_SCRIPT_NAMETAG   
	date
	echo ""
        chmod a+x $1
	$1
	echo "Completed alignment at: "
	date
}

############################################################
#check if alignment is needed
# if yes, perform alignment

if [ $ALN -eq $NUM1 ]; then

    #call a python script that scans the sample directory, checks for the correct files,
    # and injects the proper parameters into the alignment shell script

    $PYTHON $PREPARE_ALIGN_SCRIPT || { echo "Something went wrong in preparing the alignment scripts.  Exiting."; exit 1; }

    echo "After examining project structure, will attempt to align on the following samples:"
    print_sample_report $VALID_SAMPLE_FILE

    #given the valid samples (determined by the python script), run the alignments
    # note that the number of parallel alignments is determined by a configuration parameter

    num_tasks=0
    while read SAMPLE; do
        
	SCRIPT=$PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$SAMPLE'/'$SAMPLE$FORMATTED_ALIGN_SCRIPT_NAMETAG                
        #if we can fit another job
        if [ $num_tasks -lt $CONCURRENT_ALIGNMENT_PROCESSES ]; then
                do_align $SCRIPT &
                let num_tasks=num_tasks+1

	#otherwise, wait for all the current processes to finish
        else
                wait
                do_align $SCRIPT &
                num_tasks=1
        fi

    done < $VALID_SAMPLE_LIST

    # !!! important!  have to wait for ALL of the alignments to finish !!!
    wait

else

    echo "Skipping alignment based on input parameters (-noalign).  Locating BAM files..."
   
    #given bam files contained anywhere in PROJECT_HOME, construct the assumed project
    #hierarchy and create symbolic links to the bam files

    for BAM_FILE in $( find -L . -type f -name *bam ); do
        s=$( basename $BAM_FILE )
        SAMPLE=${s%.bam}
	SAMPLE_ALN_DIR=$PROJECT_DIR'/'$SAMPLE_DIR_PREFIX$SAMPLE'/'$ALN_DIR_NAME
	mkdir -p $SAMPLE_ALN_DIR
	ln -s $BAM_FILE $SAMPLE_ALN_DIR'/'$SAMPLE$BAM_EXTENSION
	echo $SAMPLE >> $VALID_SAMPLE_LIST
    done

    echo "Found BAM files for the following samples:"
    cat $VALID_SAMPLE_LIST
    
fi


############################################################

# check for the appropriate bam files and update the valid sample file accordingly:
$PYTHON $CHECK_BAM_SCRIPT

############################################################


############################################################

#create the analysis directory for the HOMER output:
HOMER_DIR=$PROJECT_DIR'/'HOMER_DIR
mkdir $HOMER_DIR

#create a report directory to hold the report and the output analysis:
REPORT_DIR=$PROJECT_DIR'/'$REPORT_DIR
mkdir $REPORT_DIR

if [ ! -d "$HOMER_DIR" ]; then
	echo "The output directory for the HOMER analysis does not exist.  Exiting"
	exit 1
fi

############################################################

############################################################
# HOMER analysis section:

while read PAIRING; do
	SAMPLENAME=$(echo $PAIRING | awk '{print $1}')
        SAMPLENAME_INPUT=$(echo $PAIRING | awk '{print $2}')

	BAMFILE=$PROJECT_DIR'/'$SAMPLE_DIR_PREFIX'/'$SAMPLENAME'/'$ALN_DIR_NAME'/'SAMPLENAME$BAM_EXTENSION
	BAMFILE_INPUT=$PROJECT_DIR'/'$SAMPLE_DIR_PREFIX'/'$SAMPLENAME_INPUT'/'$ALN_DIR_NAME'/'SAMPLENAME_INPUT$BAM_EXTENSION

	SAMFILE=$(echo $BAMFILE | sed -e 's/\.bam/\.sam/')
	SAMFILE_INPUT=$(echo $BAMFILE_INPUT | sed -e 's/\.bam/\.sam/')

	echo "Peak analysis for: $SAMPLENAME vs $SAMPLENAME_INPUT"


	echo "Making Tag Directory: $SAMPLENAME"
	samtools view -h -o $SAMFILE $BAMFILE || { echo 'BAM to SAM fell over!' >&2; exit 1; }
	makeTagDirectory $HOMER_DIR'/'$SAMPLENAME $SAMFILE > $HOMER_DIR'/'$SAMPLENAME.makeTagDirectory.log 2>&1 || { echo 'makeTagDirectory fell over' >&2; exit 1; }

	echo "Making Tag Directory: $SAMPLENAME_INPUT"
	samtools view -h -o $SAMFILE_INPUT $BAMFILE_INPUT || { echo 'BAM to SAM fell over!' >&2; exit 1; }
	makeTagDirectory $HOMER_DIR'/'$SAMPLENAME_INPUT $SAMFILE_INPUT > $HOMER_DIR'/'$SAMPLENAME_INPUT.makeTagDirectory.log 2>&1 || { echo 'makeTagDirectory fell over' >&2; exit 1; }

	echo "Running ChIPseq Analysis"
	analyzeChIP-Seq.pl $HOMER_DIR'/'$SAMPLENAME $ASSEMBLY -i $HOMER_DIR'/'$SAMPLENAME_INPUT \
	    -B -style $PEAKMODE -o auto \
	    -C -size $MOTIF_REGION_SIZE > $HOMER_DIR'/'$SAMPLENAME.analyzeChIP-Seq.log 2>&1 || { echo 'analyzeChIP-Seq fell over!' >&2; exit 1; }

	echo "Updating Tag Directories"
	makeTagDirectory $HOMER_DIR'/'$SAMPLENAME -update -genome $ASSEMBLY -checkGC > $HOMER_DIR'/'$SAMPLENAME.checkGC.log 2>&1 || { echo 'makeTagDirectory, checkGC fell over!' >&2; exit 1; }
	makeUCSCfile $HOMER_DIR'/'$SAMPLENAME -o auto -i $HOMER_DIR'/'$SAMPLENAME_INPUT > $HOMER_DIR'/'$SAMPLENAME.makeUCSCfile.log 2>&1 || { echo 'makeUCSCfile fell over!' >&2; exit 1; }

	Rscript $PLOT_TAG_AUTOCORRELATION_SCRIPT $HOMER_DIR'/'$SAMPLENAME || { echo $PLOT_TAG_AUTOCORRELATION_SCRIPT' fell over!' >&2; exit 1; }
	Rscript $PLOT_TAG_COUNT_DIST_SCRIPT $HOMER_DIR'/'$SAMPLENAME || { echo $PLOT_TAG_COUNT_DIST_SCRIPT' fell over!' >&2; exit 1; }
	Rscript $PLOT_TAG_FREQ_SCRIPT $HOMER_DIR'/'$SAMPLENAME || { echo $PLOT_TAG_FREQ_SCRIPT' fell over!' >&2; exit 1; }
	Rscript $PLOT_TAG_FREQ_UNIQ_SCRIPT $HOMER_DIR'/'$SAMPLENAME || { echo $PLOT_TAG_FREQ_UNIQ_SCRIPT' fell over!' >&2; exit 1; }
	Rscript $PLOT_TAG_GC_SCRIPT $HOMER_DIR'/'$SAMPLENAME || { echo $PLOT_TAG_GC_SCRIPT' fell over!' >&2; exit 1; }
	Rscript $PLOT_TAG_LENGTH_DIST_SCRIPT $HOMER_DIR'/'$SAMPLENAME || { echo $PLOT_TAG_LENGTH_DIST_SCRIPT' fell over!' >&2; exit 1; }

done

############################################################################

############################################################################
# Differential peak analysis:

# a method to kickoff the differential peak analysis script
# $1 is a full path to the peak file (the one we are looking for enriched peaks in)
# $2 is a full path to the tag directory for the target file 
# $3 is a full path to the tag directory for the input
# $4 is a full path to the directory for the differential peak files
function run_diff_peaks
{
	echo getDifferentialPeaks $1 $2 $3 -F $FOLD_ENRICHMENT -P $PVAL > $4'/'$(basename $2)'_vs_'$(basename $3)'.tsv' 2> $4'/'$(basename $2)'_vs_'$(basename $3)'.log'
	echo getDifferentialPeaks $1 $2 $3 -rev -F $FOLD_ENRICHMENT -P $PVAL > $4'/'$(basename $2)'_vs_'$(basename $3)'.tsv' 2> $4'/'$(basename $2)'_vs_'$(basename $3)'.log'
	getDifferentialPeaks $1 $2 $3 -F $FOLD_ENRICHMENT -P $PVAL > $4'/'$(basename $2)'_vs_'$(basename $3)'.tsv' 2> $4'/'$(basename $2)'_vs_'$(basename $3)'.log'
	getDifferentialPeaks $1 $2 $3 -rev -F $FOLD_ENRICHMENT -P $PVAL > $4'/'$(basename $2)'_vs_'$(basename $3)'.tsv' 2> $4'/'$(basename $2)'_vs_'$(basename $3)'.log'
}

echo "Run differential peak analysis.  Looking for peaks with fold enrichment $FOLD_ENRICHMENT with p-value of $PVAL"

#if the contrast file was not given:
if [ ! -f $CONTRAST_FILE ]; then
	#run all-vs-all if no contrast file was given
	#create a contrast file so the analysis can be run (and logged) in the same fashion

	#this line reads the first column of the valid sample file (the chip'd samples) and puts the names into an array ALL_SAMPLES
	IFS=$'\n' read -d '' -r -a ALL_SAMPLES < <(cut -f1 $VALID_SAMPLE_FILE)
 
	L=${#ALL_SAMPLES[@]} #length of the array
	for (( i=0; i<$L; i++ ))
	do
        	let start=i+1
        	for (( j=$start; j<$L; j++ ))
        	do
			print "%s\t%s\n" ${ALL_SAMPLES[$i]} ${ALL_SAMPLES[$j]} >> $PROJECT_DIR'/'$CONTRAST_FILE
        	done
	done
fi

while read CONTRAST; do
        SAMPLE_A=$(echo $CONTRAST | awk '{print $1}')
        SAMPLE_B=$(echo $CONTRAST | awk '{print $2}')
	SAMPLE_A_PEAK_DIR=$PROJECT_DIR'/'$HOMER_DIR'/'$SAMPLE_A
	SAMPLE_B_PEAK_DIR=$PROJECT_DIR'/'$HOMER_DIR'/'$SAMPLE_B
	run_diff_peaks $SAMPLE_A_PEAK_DIR'/'$PEAKFILE_NAME $SAMPLE_A_PEAK_DIR $SAMPLE_B_PEAK_DIR $PROJECT_DIR'/'$HOMER_DIR'/'$DIFF_PEAKS_DIR &
done < $CONTRAST_FILE

#wait for all these processes to finish before moving on:
wait
echo "Completed differential peak analysis at:"
date

#Report creation:

#copy the necessary libraries to go with the html report:
cp -r $REPORT_TEMPLATE_LIBRARIES $REPORT_DIR

#run the injection script to create the report:
if [ $TEST -eq $NUM0 ]; then
	$PYTHON $CREATE_REPORT_SCRIPT
else
	echo "Perform mock creation of output report."
fi
############################################################


############################################################
#cleanup
rm $VALID_SAMPLE_LIST


