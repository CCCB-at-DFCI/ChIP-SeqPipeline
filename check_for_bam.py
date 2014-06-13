"""
This script is run on aligned data-- 
  Given info about the project, look into the sample-specific directories and locate the bam files
  If the bam files do not exist, update the file containing the 'valid' samples, removing this sample
  In this way, we will not attempt to run a chIP analysis on samples where we do not have the necessary data
"""

import os


def read_samples(samples_file):
    """
    Reads the samples file, which has all the samples.
    Each line has the chip and input sample name
    Returns a list of these names, paired as tuples
    """
    sample_tuples = []
    try:
        with open(samples_file, 'r') as f:
            for line in f:
                try:
                    chip, input=line.strip().split('\t')
                    if len(chip)>0 and len(input)>0:
                        sample_tuples.append((chip, input))
                except ValueError: #if there are not two samples on a line
                    pass
            return set(sample_tuples)
    except IOError:
        sys.exit("I/O Error: Could not find samples file: "+str(samples_file))



def read_sample_list(sample_list_file):
    samples = []
    try:
        with open(sample_list_file, 'r') as f:
            for line in f:
                s=line.strip()
                if len(s)>0:
                    samples.append(s)
            return set(samples)
    except IOError:
        sys.exit("I/O Error: Could not find sample list file: "+str(sample_list_file))


def check_bam(sample_list, project_dir, sample_dir_prefix, align_dir_name, bam_suffix):
    valid_samples = []
    for sample in sample_list:
        sample_dir = os.path.join(project_dir, str(sample_dir_prefix)+str(sample))
        align_dir = os.path.join(sample_dir, align_dir_name)

        #check that this sample has a bam file:
        if os.path.exists(os.path.join(align_dir, str(sample)+str(bam_suffix))):
          valid_samples.append(sample)
        else:
          print "BAM or count file was not found for sample "+str(sample)+".  Perhaps the alignment failed?"
    return valid_samples


def write_valid_sample_file(validated_sample_filepath, sample_pairings, validated_sample_name_set):
    with open(validated_sample_filepath, 'w') as vsf:
        for chip, input in sample_pairings:
            if chip in validated_sample_name_set and input in validated_sample_name_set:
                vsf.write(str(chip)+"\t"+str(input)+"\n")

def write_valid_sample_list(valid_sample_list_filepath, validated_sample_names):
    with open(valid_sample_list_filepath, 'w') as f:
        for sample in validated_sample_names:
            f.write(str(sample)+"\n")


       

if __name__=="__main__":

    sample_file = os.environ['VALID_SAMPLE_FILE']
    sample_list_file = os.environ['VALID_SAMPLE_LIST']
    project_dir = os.environ['PROJECT_DIR']
    sample_dir_prefix = os.environ['SAMPLE_DIR_PREFIX']
    align_dir_name = os.environ['ALN_DIR_NAME']
    bam_suffix = os.environ['BAM_EXTENSION']

    #construct the full path to the necessary files:
    validated_sample_filepath = os.path.join(project_dir, sample_file) 
    sample_list_filepath = os.path.join(project_dir, sample_list_file) 

    #parse the files to get the pairings and the 'master list'
    sample_pairings = read_samples(samples_file)
    sample_list = read_sample_list(sample_list_file)

    #determine valid sdamples by the presence of a bam file in the appropriate location:
    valid_samples = check_bam(sample_list, project_dir, sample_dir_prefix, align_dir_name, bam_suffix)

    #rewrite the sample files
    write_valid_sample_file(validated_sample_filepath, sample_pairings, validated_sample_name_set)
    write_valid_sample_list(sample_list_filepath, valid_samples)

