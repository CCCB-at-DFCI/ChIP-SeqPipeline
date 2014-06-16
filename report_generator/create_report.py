import sys
import os
import re
import glob

#some regexes:
QC_SEARCH_STRING = "#QC_REPORT#"
SAMPLE_ID = "#SAMPLE_ID#"
QC_METADATA_TABLE = "#QC_METADATA_TABLE#"
QC_PLOT_SECTION = "#QC_PLOT_SECTION#"
IMG_SRC = "#IMG_SRC#"
IMG_DATAFILE = "#IMG_DATAFILE#"
IMG_DATAFILE_BASENAME = "#IMG_DATAFILE_BASENAME#"
PEAK_SECTION = "#PEAK_SECTION#"
PEAK_FILE_LINK_SECTION = "#PEAK_FILE_LINK_SECTION#"
PEAK_FILE_LINK = "#PEAK_FILE_LINK#"
PEAK_FILE_BASENAME = "#PEAK_FILE_BASENAME#"
MOTIF_SECTION = "#MOTIF_SECTION#"
MOTIF_FILE_LINK_SECTION = "#MOTIF_FILE_LINK_SECTION#"
MOTIF_FILE_LINK = "#MOTIF_FILE_LINK#"
MOTIF_FILE_BASENAME = "#MOTIF_FILE_BASENAME#"
MOTIF_FILE_DESCRIPTION = "#MOTIF_FILE_DESCRIPTION#"
GO_SECTION = "#GO_SECTION#"
GO_FILE_LINK_SECTION = "#GO_FILE_LINK_SECTION#"
GO_FILE_LINK = "#GO_FILE_LINK#"
GO_FILE_BASENAME = "#GO_FILE_BASENAME#"
GO_FILE_DESCRIPTION = "#GO_FILE_DESCRIPTION#"
BED_FILE_SECTION="#BED_FILE_SECTION#"
BED_FILE_LINK="#BED_FILE_LINK#"
BED_FILE_BASENAME="#BED_FILE_BASENAME#"
DIFF_PEAKS_SECTION="#DIFF_PEAK_SECTION#"
DIFF_PEAK_FILE_LINK="#DIFF_PEAK_FILE_LINK#"
DIFF_PEAK_FILE_BASENAME="#DIFF_PEAK_FILE_BASENAME#"

DIV_REGEX = "<div.*</div>" #greedy match!



OUTPUT_EXPLANATION = "#OUTPUT_EXPLANATION#"


def get_search_pattern(target):
    return "<!--\s*"+str(target)+".*"+str(target)+"\s*-->"


def extract_template_textblock(pattern, template_html):
    matches = re.findall(pattern, template_html, flags=re.DOTALL)
    try:
        return matches[0] #the block of html that is the template
    except IndexError:
        print "Could not find a proper match in the template file."


def read_template_html(template_html_file):
    #read-in the template:
    try:
      with open(template_html_file, 'r') as report_template:
        return report_template.read()
    except IOError:
      sys.exit('Could not locate the template html file.')


def get_sample_ids(samples_file):
    #parse the sample file:
    all_sample_ids = []
    try:
        with open(samples_file) as sf:
            for line in sf:
                all_sample_ids.append(line.strip().split('\t')[0])
        return all_sample_ids
    except IOError:
        sys.exit('Could not locate the sample file: '+str(samples_file))



def write_completed_template(completed_html_report, html):
    with open(completed_html_report, 'w') as outfile:
        outfile.write(html)



def inject_qc_reports(template_html, all_sample_ids, config, project_dir):

    pattern = get_search_pattern(QC_SEARCH_STRING)
    match = extract_template_textblock(pattern, template_html)
    if match:

        #extract out the plot section and remove the section tags:
        plot_section_template = extract_template_textblock(QC_PLOT_SECTION+".*"+QC_PLOT_SECTION, match)
	plot_section_template = re.sub(QC_PLOT_SECTION, '', plot_section_template)	

	new_content = ""
        for sample_id in all_sample_ids:
            s = match
            s = re.sub(SAMPLE_ID, sample_id, s)
            
            sample_dir = os.path.join(config['ANALYSIS_DIR_NAME'], sample_id)

            relative_path = os.path.relpath(sample_dir, config['REPORT_DIR'])

            #substitute in a html table of the metadata:

            peak_info_file = os.path.join(project_dir, sample_dir, config['PEAK_INFO_FILE'])
            s = re.sub(QC_METADATA_TABLE, create_html_table( extract_peak_analysis_metadata(peak_info_file) ,2), s)

            #add the plots and file links for this sample's QC:
            plot_section = ""
            for qc_file, qc_plot in config['QC_OUTPUT']:
                section_text = plot_section_template            
                section_text = re.sub(IMG_SRC, os.path.join(relative_path, qc_plot), section_text)
                section_text = re.sub(IMG_DATAFILE, os.path.join(relative_path, qc_file), section_text)
                section_text = re.sub(IMG_DATAFILE_BASENAME, qc_file, section_text)
                plot_section += section_text

            #substitute this plot_section into the sample template:
            s = re.sub(QC_PLOT_SECTION+".*"+QC_PLOT_SECTION, plot_section, s, flags=re.DOTALL)

            content = re.findall(DIV_REGEX, s, flags=re.DOTALL)
            new_content += content[0]

        template_html = re.sub(pattern, new_content, template_html, flags=re.DOTALL)
    return template_html


def inject_peak_reports(template_html, all_sample_ids, config, project_dir):

    pattern = get_search_pattern(PEAK_SECTION)
    match = extract_template_textblock(pattern, template_html)
    if match:

        #extract out the Link section and remove the tags:
        link_section_template = extract_template_textblock(PEAK_FILE_LINK_SECTION+".*"+PEAK_FILE_LINK_SECTION, match)
	link_section_template = re.sub(PEAK_FILE_LINK_SECTION, '', link_section_template)	

	new_content = ""
        for sample_id in all_sample_ids:
            s = match
            s = re.sub(SAMPLE_ID, sample_id, s)
            
            sample_dir = os.path.join(project_dir, config['ANALYSIS_DIR_NAME'], sample_id)

            relative_path = os.path.relpath(sample_dir, os.path.join(project_dir,config['REPORT_DIR']))

            #add the file links for this sample's peak analysis:
            link_section = ""
            for output_file in config['PEAK_ANALYSIS_OUTPUT']:
                section_text = link_section_template            
                section_text = re.sub(PEAK_FILE_LINK, os.path.join(relative_path, output_file), section_text)
                section_text = re.sub(PEAK_FILE_BASENAME, output_file, section_text)
                link_section += section_text

            #substitute this plot_section into the sample template:
            s = re.sub(PEAK_FILE_LINK_SECTION+".*"+PEAK_FILE_LINK_SECTION, link_section, s, flags=re.DOTALL)

            content = re.findall(DIV_REGEX, s, flags=re.DOTALL)
            new_content += content[0]

        template_html = re.sub(pattern, new_content, template_html, flags=re.DOTALL)
    return template_html


def inject_motif_reports(template_html, all_sample_ids, config, project_dir):

    pattern = get_search_pattern(MOTIF_SECTION)
    match = extract_template_textblock(pattern, template_html)
    if match:

        #extract out the Link section and remove the tags:
        link_section_template = extract_template_textblock(MOTIF_FILE_LINK_SECTION+".*"+MOTIF_FILE_LINK_SECTION, match)
	link_section_template = re.sub(MOTIF_FILE_LINK_SECTION, '', link_section_template)	

	new_content = ""
        for sample_id in all_sample_ids:
            s = match
            s = re.sub(SAMPLE_ID, sample_id, s)
            
            sample_dir = os.path.join(project_dir, config['ANALYSIS_DIR_NAME'], sample_id)

            #add the file links for this sample's peak analysis:
            link_section = ""
            for description, output_file in config['MOTIF_ANALYSIS_OUTPUT']:
                section_text = link_section_template            
                file_matches = glob.glob(os.path.join(sample_dir, config['MOTIF_DIR_PREFIX']+'*', output_file))
                try:
                    full_path = file_matches[0]
                    relative_path = os.path.relpath(full_path, os.path.join(project_dir, config['REPORT_DIR']))
                    section_text = re.sub(MOTIF_FILE_LINK, relative_path, section_text)
                    section_text = re.sub(MOTIF_FILE_BASENAME, str(description)+": "+str(output_file), section_text)
                    link_section += section_text
                except IndexError:
                    pass	

            #substitute this plot_section into the sample template:
            s = re.sub(MOTIF_FILE_LINK_SECTION+".*"+MOTIF_FILE_LINK_SECTION, link_section, s, flags=re.DOTALL)

            content = re.findall(DIV_REGEX, s, flags=re.DOTALL)
            new_content += content[0]

        template_html = re.sub(pattern, new_content, template_html, flags=re.DOTALL)
    return template_html


def inject_ontology_reports(template_html, all_sample_ids, config, project_dir):

    pattern = get_search_pattern(GO_SECTION)
    match = extract_template_textblock(pattern, template_html)
    if match:

        #extract out the Link section and remove the tags:
        link_section_template = extract_template_textblock(GO_FILE_LINK_SECTION+".*"+GO_FILE_LINK_SECTION, match)
	link_section_template = re.sub(GO_FILE_LINK_SECTION, '', link_section_template)	

	new_content = ""
        for sample_id in all_sample_ids:
            s = match
            s = re.sub(SAMPLE_ID, sample_id, s)
            
            sample_dir = os.path.join(project_dir, config['ANALYSIS_DIR_NAME'], sample_id)

            #add the file links for this sample's peak analysis:
            link_section = ""
            for description, output_file in config['GO_ANALYSIS_OUTPUT']:
                section_text = link_section_template            
                file_matches = glob.glob(os.path.join(sample_dir, '*', output_file))
                try:
                    full_path = file_matches[0]
                    relative_path = os.path.relpath(full_path, os.path.join(project_dir, config['REPORT_DIR']))
                    section_text = re.sub(GO_FILE_LINK, relative_path, section_text)
                    section_text = re.sub(GO_FILE_DESCRIPTION, str(description)+": ", section_text)
                    section_text = re.sub(GO_FILE_BASENAME, output_file, section_text)
                    link_section += section_text
                except IndexError:
                    pass	

            #substitute this plot_section into the sample template:
            s = re.sub(GO_FILE_LINK_SECTION+".*"+GO_FILE_LINK_SECTION, link_section, s, flags=re.DOTALL)

            content = re.findall(DIV_REGEX, s, flags=re.DOTALL)
            new_content += content[0]

        template_html = re.sub(pattern, new_content, template_html, flags=re.DOTALL)
    return template_html


def inject_bedfile_links(template_html, all_sample_ids, config, project_dir):

    pattern = get_search_pattern(BED_FILE_SECTION)
    match = extract_template_textblock(pattern, template_html)

    if match:
        new_content = ""
        analysis_dir = os.path.join(project_dir, config['ANALYSIS_DIR_NAME'])
        file_matches = glob.glob(os.path.join(analysis_dir, '*', '*'+str(config['BED_FILE_SUFFIX'])))

        if len(file_matches)>0:
            for f in file_matches:
                relative_path = os.path.relpath(f, os.path.join(project_dir, config['REPORT_DIR']))
                s = match
                s = re.sub(BED_FILE_LINK, relative_path, s)
                s = re.sub(BED_FILE_BASENAME, os.path.basename(f), s)
                content = re.findall(DIV_REGEX, s, flags=re.DOTALL)
                new_content += content[0]
        else:
            new_content='<div class="alert alert-info">BED files were not created or found.</div>'

        template_html = re.sub(pattern, new_content, template_html, flags=re.DOTALL)
    return template_html


def inject_diff_peaks_links(template_html, all_sample_ids, config, project_dir):

    pattern = get_search_pattern(DIFF_PEAKS_SECTION)
    match = extract_template_textblock(pattern, template_html)

    if match:
        new_content = ""
        analysis_dir = os.path.join(project_dir, config['ANALYSIS_DIR_NAME'])
        file_matches = glob.glob(os.path.join(analysis_dir, '*', '*'+str(config['DIFF_PEAKS_TAG']+'*')))

        if len(file_matches)>0:
            for f in file_matches:
                relative_path = os.path.relpath(f, os.path.join(project_dir, config['REPORT_DIR']))
                s = match
                s = re.sub(DIFF_PEAK_FILE_LINK, relative_path, s)
                s = re.sub(DIFF_PEAK_FILE_BASENAME, os.path.basename(f), s)
                content = re.findall(DIV_REGEX, s, flags=re.DOTALL)
                new_content += content[0]
        else:
            new_content='<div class="alert alert-info">Differential peak analysis files were not created or found.</div>'

        template_html = re.sub(pattern, new_content, template_html, flags=re.DOTALL)
    return template_html


def extract_peak_analysis_metadata(peakfile):
	
	d={}
	try:
		with open(peakfile, 'r') as pf:
			for line in pf:
				if line.strip().startswith('#'): 
					#strip all '#' and all whitespace
					try:
						line = line.strip()
						id, val = line.strip('# ').split('=')
						d[id] = [val] #point to a list for flexibility with table-writing method
					except ValueError:
						#exception is thrown if no key-value pair-- just ignore this line
						pass
	except IOError:
		pass
	return d


def create_html_table(data, cols):
	html = "<table class=\"table\"><tbody>"
	for key, vals in data.iteritems():
		html += "<tr>"
		html += "<td>" +str(key)+"</td>"
		for val in vals:
			html += "<td>" +str(val)+"</td>"
		html += "</tr>"
	html += "</tbody></table>"
	return html
	


if __name__ == "__main__":

	project_dir = os.environ['PROJECT_DIR']

	config={}
	config['TEMPLATE_HTML_REPORT'] = os.environ['REPORT_TEMPLATE_HTML']
	config['SAMPLES_FILE']= os.environ['VALID_SAMPLE_FILE'] #the two column file with chip and input samples
	config['ANALYSIS_DIR_NAME']=os.environ['HOMER_DIR']
	config['REPORT_DIR']=os.environ['REPORT_DIR']
	config['PEAK_INFO_FILE']=os.environ['PEAKINFO_FILE']
	config['QC_OUTPUT']=[
			(os.environ['TAG_GC_CONTENT_FILE'],os.environ['TAG_GC_PLOT']),
			(os.environ['TAG_AUTOCORRELATION_FILE'], os.environ['TAG_AUTOCORRELATION_PLOT']),
			(os.environ['TAG_FREQ_FILE'],os.environ['TAG_FREQ_PLOT']),
			(os.environ['TAG_FREQ_UNIQ_FILE'],os.environ['TAG_FREQ_UNIQ_PLOT']),
			(os.environ['TAG_COUNT_DISTRIBUTION_FILE'],os.environ['TAG_COUNT_DIST_PLOT']),
			(os.environ['TAG_LENGTH_DISTRIBUTION_FILE'],os.environ['TAG_LENGTH_DIST_PLOT'])]

	peakfile_prefix = os.environ['PEAKFILE_NAME']
	peakfile_name = str(peakfile_prefix)+os.environ['PEAKFILE_EXT']
	annotated_peakfile_name = str(peakfile_prefix)+os.environ['ANNOTATED_TAG']+os.environ['PEAKFILE_EXT']

	config['PEAK_ANALYSIS_OUTPUT']=[os.environ['PEAKINFO_FILE'], peakfile_name, annotated_peakfile_name]
	config['MOTIF_DIR_PREFIX']=os.environ['MOTIF_DIR_PREFIX']
	config['MOTIF_ANALYSIS_OUTPUT']=[('Known motif enrichment', os.environ['KNOWN_RESULTS_HTML']), ('De Novo motif enrichment',os.environ['DENOVO_RESULTS_HTML'])]
	config['GO_ANALYSIS_OUTPUT']=[('Genome ontology- based on peaks',os.environ['GENOME_ONTOLOGY_RESULTS_HTML']),
					('Gene ontology analysis of bound genes',os.environ['GENE_ONTOLOGY_RESULTS_HTML'])]
	config['BED_FILE_SUFFIX']=os.environ['BED_FILE_SUFFIX']
	config['DIFF_PEAKS_TAG']=os.environ['DIFF_PEAKS_TAG']

	#get the chIP'd samples:
	all_sample_ids = get_sample_ids(os.path.join(project_dir, config['SAMPLES_FILE']))

	#fill in the template script:
	html = read_template_html(config['TEMPLATE_HTML_REPORT'])
	html = inject_qc_reports(html, all_sample_ids, config, project_dir)
	html = inject_peak_reports(html, all_sample_ids, config, project_dir)
	html = inject_motif_reports(html, all_sample_ids, config, project_dir)
	html = inject_ontology_reports(html, all_sample_ids, config, project_dir)
	html = inject_bedfile_links(html, all_sample_ids, config, project_dir)
	html = inject_diff_peaks_links(html, all_sample_ids, config, project_dir)

	write_completed_template(os.path.join(project_dir, config['REPORT_DIR'], os.environ['FINAL_RESULTS_REPORT']), html)

