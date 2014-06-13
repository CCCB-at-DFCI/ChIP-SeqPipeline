y"""
This script performs some basic checking (e.g. if FASTQ files exist)
and writes the appropriate parameters into the template alignment script
"""

import os
import sys
import re
import glob

class SampleMetaData:
    """
    Object to hold project-specific details together
    """
    def __init__(self,
                 project_dir,
                 output_dir,
                 paired_end_reads,
                 assembly,
                 script_nametag,
                 sample_dir_prefix,
                 genome_index,
                 bam_suffix,
                 samplesheet):
        self.project_dir = project_dir
        self.output_dir = output_dir
        self.paired_end_reads = paired_end_reads
        self.assembly = assembly
        self.script_nametag = script_nametag
        self.sample_dir_prefix = sample_dir_prefix
        self.genome_index = genome_index
        self.bam_suffix = bam_suffix
        self.samplesheet = samplesheet


class Sample:

    def __init__(self, sample_name, sample_metadata, script_template_string):
        self.sample_name = sample_name
        self.sample_metadata = sample_metadata
        self.script_template = script_template_string
        self.sample_dir = ""
        self.fastq_a = ""
        self.fastq_b = ""
        self.sequencing_info_dict = None


def read_samples(samples_file):
    """
    Reads the samples file, which has all the samples.
    Each line has the chip and input sample name
    Returns a set of these names
    The only check performed is that each chIP sample has a matching input sample.
    It does NOT check that the data files exist for each samples-- that is performed later.
    """
    samples = []
    try:
        with open(samples_file, 'r') as f:
            for line in f:
                try:
                    chip, input=line.strip().split('\t')
                    if len(chip)>0 and len(input)>0:
                        samples.append((chip, input))
                except ValueError: #if there are not two samples on a line
                    pass
            return set(samples)
    except IOError:
        sys.exit("I/O Error: Could not find samples file: "+str(samples_file))


def read_template_script(template_script):
    """
    Reads the template script file into a string and returns it
    """
    try:
        f = open(template_script, 'r')
        default_script = f.read()
        return default_script
    except IOError:
        sys.exit("I/O Error:  Could not find the template script file: "+str(template_script))


def valid_sample(sample):
    """
    Receives a Sample object.  Check that the proper files exist and return True if ok, else False
    """
    if not sample.fastq_a:
        return False
    if sample.sample_metadata.paired_end_reads == 1 and not sample.fastq_b:
        return False
    return True


def find(pattern):
    """
    Using glob, find the first occurrence of the pattern.  IF not found, return None
    """
    try:
        return glob.glob(pattern)[0]
    except IndexError:
        return None


def parse_seq_info(samplesheet):
    try:
        with open(samplesheet, 'r') as f:
            keys = f.readline().strip().split(',')
            values = f.readline().strip().split(',')
            return dict(zip(keys, values))
    except IOError:
        sys.exit("Could not locate the sample sheet at: "+str(samplesheet))


def prepare_sample(sample):
    """
    Receives a Sample object-- prepares things like the paths, etc. based on the project metadata
    and the sample-specific data
    """
    sample.sample_dir = os.path.join(sample.sample_metadata.project_dir,
                                       str(sample.sample_metadata.sample_dir_prefix)+sample.sample_name)

    #locate the fastq files (if not found, they are set to None)
    search_pattern = os.path.join(sample.sample_dir, sample.sample_name)
    sample.fastq_a = find(search_pattern+"*R1*fastq.gz")
    sample.fastq_b = find(search_pattern+"*R2*fastq.gz")

    #extract sample metadata (for read group info) from the samplesheet:
    
    sample.sequencing_info_dict = parse_seq_info(os.path.join(sample.sample_dir, sample.sample_metadata.samplesheet))

    return sample


def inject_script(sample):
    """
    Inject the relevant parameters into the template scripts
    """
    #inject parameters common to alignment template scripts:
    sample.script_template = re.sub("%GENOME_INDEX%", str(sample.sample_metadata.genome_index), str(sample.script_template))
    sample.script_template = re.sub("%BAM_FILE_SUFFIX%", str(sample.sample_metadata.bam_suffix), str(sample.script_template))
    sample.script_template = re.sub("%SAMPLE_NAME%", str(sample.sample_name), str(sample.script_template))
    sample.script_template = re.sub("%SAMPLE_DIR%", str(sample.sample_dir), str(sample.script_template))
    sample.script_template = re.sub("%ASSEMBLY%", str(sample.sample_metadata.assembly), str(sample.script_template))
    sample.script_template = re.sub("%OUTPUTDIRECTORY%",
                                    str(os.path.join(sample.sample_dir, sample.sample_metadata.output_dir)), str(sample.script_template))

    #paired or single-end protocol specifics:
    if sample.sample_metadata.paired_end_reads == 1: # if paired
        sample.script_template = re.sub("%PAIRED%", str(1), str(sample.script_template))
        sample.script_template = re.sub("%FASTQFILEA%", str(sample.fastq_a), str(sample.script_template))
        sample.script_template = re.sub("%FASTQFILEB%", str(sample.fastq_b), str(sample.script_template))
    else: #single-end
        sample.script_template = re.sub("%PAIRED%", str(0), str(sample.script_template))
        sample.script_template = re.sub("%FASTQFILEA%", str(sample.fastq_a), str(sample.script_template))
        sample.script_template = re.sub("%FASTQFILEB%", "", str(sample.script_template))

    return sample


def write_valid_sample_file(validated_sample_filepath, sample_pairings, validated_sample_name_set):
    with open(validated_sample_filepath, 'w') as vsf:
        for chip, input in sample_pairings:
            if chip in validated_sample_name_set and input in validated_sample_name_set:
                vsf.write(str(chip)+"\t"+str(input)+"\n")


def write_valid_sample_list(valid_sample_list_filepath, validated_sample_names):
    with open(valid_sample_list_filepath, 'w') as f:
        for sample in validated_sample_names:
            f.write(str(sample)+"\n")


def write_script(sample):
    """
    Writes the formatted template to a file in the appropriate location
    """
    outfile = str(sample.sample_name)+str(sample.sample_metadata.script_nametag)
    outfile = os.path.join(sample.sample_dir, outfile)
    with open(outfile, 'w') as o:
        o.write(sample.script_template)


if __name__ == '__main__':

    """
    samples_file: is the sample file (tab-separated).  Each row has the sample name and the "condition"
    project_dir: is the parent directory containing all the sample subdirectories.  Also known as the project directory
    output_dir: is the output directory for the alignment files (e.g. BAM).
            -- this is relative to the sample-specific directory!  Thus, not a full path
    samplesheet: specifies the name (not the path) of the experiment meta-data.  Often SampleSheet.csv
    paired_end_reads: specifies if paired-end (1) or single-end (0)
    assembly: is the genome (hg19, mm10, etc)
    validated_sample_filepath: is the NAME to an output file that will report the valid samples to align.
            -- That is, if there is an error (e.g. a missing FASTQ) for one of the samples, we will skip the alignment
            -- This file will contain a subset of the samples specified in the originl sample file (argv[1]).
            -- If everything is good, then this file ends up being a verbatim copy of the original sample file.
    template_script: is a template script for performing the alignment.  This will be filled in by this script
    script_nametag: is a "nametag" for the formatted/injected scripts that this will create.  This helps identify the alignment script that will be called later on
    sample_dir_prefix: is the prefix for the sample directory (e.g. with prefix='Sample_' for sample XXX the directory would be 'Sample_XXX')
    genome_index: is a full path to the genome index for the aligner
    bam_suffix: is a file suffix to place on the output BAM file so that it may be easily identified later on in the pipeline
    """

    try:
        samples_file = os.environ['SAMPLES_FILE']
        project_dir = os.environ['PROJECT_DIR']
        output_dir = os.environ['ALN_DIR_NAME']
        samplesheet = os.environ['SAMPLE_SHEET_NAME']
        paired_end_reads = int(os.environ['PAIRED_READS'])
        assembly = os.environ['ASSEMBLY']
        validated_sample_filename = os.environ['VALID_SAMPLE_FILE']
        template_script = os.environ['ALIGN_SCRIPT_TEMPLATE']
        script_nametag = os.environ['FORMATTED_ALIGN_SCRIPT_NAMETAG']
        sample_dir_prefix = os.environ['SAMPLE_DIR_PREFIX']
        genome_index = os.environ['GENOME_INDEX']
        bam_suffix = os.environ['BAM_EXTENSION']
        valid_sample_list_file = os.environ['VALID_SAMPLE_LIST']

        #create a data object to hold all the metadata about the project/sample:
        sample_metadata = SampleMetaData(
            project_dir,
            output_dir,
            paired_end_reads,
            assembly,
            script_nametag,
            sample_dir_prefix,
            genome_index,
            bam_suffix,
            samplesheet,
        )

        #construct some full paths:
        validated_sample_filepath = os.path.join(project_dir, validated_sample_filename)
        valid_sample_list_filepath = os.path.join(project_dir, valid_sample_list_file)

        #get a set (of tuples of chip and input sample) of all sample pairings by parsing the sample file:
        sample_pairings = read_samples(samples_file)

        #create a set of the sample names
        sample_name_set = {sample for pairing_tuple in sample_pairings for sample in pairing_tuple}

        #read-in the default script to a string
        script_template_string = read_template_script(template_script)

        #create a list of Sample objects
        all_samples = [Sample(sample_name, sample_metadata, script_template_string) for sample_name in sample_name_set]

        #prepare samples
        all_samples = map(prepare_sample, all_samples)

        #validate the samples-- check that the correct files exist:
        all_samples = [s for s in all_samples if valid_sample(s)]

        #get the validated sample names (For ease)
        validated_sample_names = {s.sample_name for s in all_samples}

        #inject the parameters:
        all_samples = map(inject_script, all_samples)

        #write the scripts
        map(write_script, all_samples)

        #write the validated sample files:
        write_valid_sample_pairings(validated_sample_filepath, sample_pairings, validated_sample_names):
        write_valid_sample_list(valid_sample_list_filepath, validated_sample_names)

    except KeyError:
        exit("An error occurred")

