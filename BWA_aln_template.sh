#!/bin/bash

#check for the proper dependencies:
if ! which bwa ; then
	echo "Could not find bwa aligner in your PATH"
	exit 1
fi

if ! which samtools ; then
	echo "Could not find samtools in your PATH"
	exit 1
fi

if ! which java ; then
        echo "Could not find java in your PATH"
        exit 1
fi

#parameters to be filled in:
SAMPLE_DIR="%SAMPLE_DIR%"
FASTQFILEA="%FASTQFILEA%"
FASTQFILEB="%FASTQFILEB%"
SAMPLE_NAME="%SAMPLE_NAME%"
ASSEMBLY="%ASSEMBLY%"
PAIRED=%PAIRED%
BAM_FILE_SUFFIX=%BAM_FILE_SUFFIX%
BWAIDX="%GENOME_INDEX%"
NUM0=0
NUM1=1
OUTDIR=%OUTPUTDIRECTORY%
PICARD_DIR=%PICARD_DIR%


#create and change to the output directory
mkdir $OUTDIR

#go to sample directory
cd $SAMPLE_DIR

#print out some parameters for this alignment:
echo Working files and variables are':'
echo Sample Directory is $SAMPLE_DIR
echo Read 1 fastq file is $FASTQFILEA
if [ $PAIRED -eq $NUM1 ]; then
	echo Read 2 fastq file is $FASTQFILEB
fi
echo Sample Name is $SAMPLE_NAME
echo The Assembly is $ASSEMBLY

echo 'BWA INDEX is set to '$BWAIDX
date
echo The output directory is $OUTDIR


#make a temporary directory for intermediate files in the coverage calculation
TMPDIR=`mktemp -d $OUTDIR/tempdir.XXXXXX`
echo the temp directory is $TMPDIR


if [ $PAIRED -eq $NUM0 ]; then
    # Run BWA alignment, BAM conversion, and sorting
    bwa aln -t 4 $BWAIDX $FASTQFILEA >$TMPDIR/s1_1.sai
    bwa samse $BWAIDX $TMPDIR/s1_1.sai $FASTQFILEA | samtools view -Shb - >$TMPDIR/aln.bam

elif [ $PAIRED -eq $NUM1 ]; then
    bwa aln -t 6 $BWAIDX $FASTQFILEA >$TMPDIR/s1_1.sai
    bwa aln -t 6 $BWAIDX $FASTQFILEB >$TMPDIR/s1_2.sai
    bwa sampe $BWAIDX $TMPDIR/s1_1.sai $TMPDIR/s1_2.sai $FASTQFILEA $FASTQFILEB | samtools view -Shb - >$TMPDIR/aln.bam
else
     echo "ERROR. No pairing option specified."
fi

#post-alignment sorting, indexing:
samtools sort -o -m 2500000000 $TMPDIR/aln.bam $SAMPLE_NAME >$OUTDIR/$SAMPLE_NAME.bam
samtools index $OUTDIR/$SAMPLE_NAME.bam
samtools flagstat $OUTDIR/$SAMPLE_NAME.bam >$OUTDIR/flagstat.rawBAM.out

# Create a de-duped BAM file 
DEDUP_BAM=$OUTDIR'/'$SAMPLE_NAME.rmdup.bam
java -Xmx6g -jar $PICARD_DIR/MarkDuplicates.jar INPUT=$OUTDIR/$SAMPLE_NAME.bam OUTPUT=$DEDUP_BAM ASSUME_SORTED=TRUE TMP_DIR=./picardTemp/ REMOVE_DUPLICATES=TRUE METRICS_FILE=$DEDUP_BAM.metrics.out VALIDATION_STRINGENCY=LENIENT
samtools flagstat $DEDUP_BAM >$OUTDIR/flagstat.dedupBAM.out

#cleanup
rm $TMPDIR/*.sai
rm $TMPDIR/aln.bam

# make a new bam file with only primary alignments  (if BAM is paired end, you may still have singletons here..so no filtering for proper pairs)
FILTERED_FILE=$OUTDIR'/'$SAMPLE_NAME.primary.bam
samtools view -b -F 0x0100 $DEDUP_BAM > $FILTERED_FILE
samtools index $FILTERED_FILE

#rename with suffix for easier finding
mv $FILTERED_FILE $OUTDIR'/'$SAMPLE_NAME$BAM_FILE_SUFFIX

chmod 744 $OUTDIR
chmod -R a+rx $OUTDIR

date




