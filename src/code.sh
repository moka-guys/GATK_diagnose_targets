#!/bin/bash

# The following line causes bash to exit at any point if there is any error
# and to output each line as it is executed -- useful for debugging
set -e -x -o pipefail


#
# This app is only a wrapper. The actual GATK3 software must be provided
# by the user. It is expected to be found in the parent project.
#
# Locate and download the GATK jar file.
#
#mark-section "locating GATK jar file"
#download-gatk-jar.sh

#
# Fetch inputs
#
mark-section "downloading inputs"
dx-download-all-inputs --parallel

mv ~/in/gatk_jar_file/* ~/GenomeAnalysisTK.jar
mv ~/in/bam_index/* ~/in/sorted_bam/

# Show all the java versions installed on this worker
# Show the java version the worker is using
echo $(java -version)

#
# Use java7 as the default java version. 
# If java7 doesn't work with the GATK version (3.6 and above) then switch to java8 and try again.
#
update-alternatives --set java /usr/lib/jvm/java-7-openjdk-amd64/jre/bin/java
java -jar GenomeAnalysisTK.jar -version || (update-alternatives --set java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java && java -jar GenomeAnalysisTK.jar -version)



#
# Calculate 80% of memory size, for java
#
head -n1 /proc/meminfo | awk '{print int($2*0.8/1024)}' >.mem_in_mb.txt
java="java -Xmx$(<.mem_in_mb.txt)m"

#
# Fetch vendor exome regions, if given
#
if [[ "$vendor_exome" != "" ]]
then
  mark-section "downloading vendor exome coordinates"
  dx download "$APPDATA:/vendor_exomes/${vendor_exome}_${genome}_targets.bed"
  region_opts=("-L" "${vendor_exome}_${genome}_targets.bed")
  if [[ "$padding" != "0" ]]
  then
    region_opts+=("-ip" "$padding")
  fi
# else
#   mark-section "downloading provided targets"
#   dx download ~/in/targets_bed/"$targets_bed"
#   region_opts=("-L" "targets.bed")
#   if [[ "$padding" != "0" ]]
#   then
#     region_opts+=("-ip" "$padding")
#   fi
fi


#
# Detect and download the appropriate human genome and related reference files
#
mark-section "detecting reference genome"
samtools view -H "$sorted_bam_path" | grep ^@SQ | cut -f1-3 | md5sum | cut -c1-32 >.genome-fingerprint.txt
case "$(<.genome-fingerprint.txt)" in
  9220d59b0d7a55a43b22cad4a87f6797)
    genome=b37
    subgenome=b37
    ;;
  45340a8b2bb041655c6f6d4f9985944f)
    genome=b37
    subgenome=hs37d5
    ;;
  2f23b2f7c9731db07f0d1c8f9bc8c9d9)
    genome=hg19
    subgenome=hg19
    ;;
  53a8d91e94b765bd69c104611a2f796c)
    genome=grch38
    subgenome=grch38 # No alt analysis
    dx-jobutil-report-error "The GRCh38 reference genome is not supported by this app."
    ;;
  *)
    echo "Non-matching human genome. The input BAM contains the following chromosomes (names and sizes):"
    samtools view -H "$sorted_bam_path" | grep ^@SQ | cut -f1-3
    dx-jobutil-report-error "The reference genome of the input BAM file did not match any of the known human ones. Additional diagnostic information has been provided in the job log."
    ;;
esac

#
# Get reference genome
#
mark-section "downloading reference genome"
APPDATA=project-B6JG85Z2J35vb6Z7pQ9Q02j8
dx cat "$APPDATA:/misc/gatk_resource_archives/${subgenome}.fasta-index.tar.gz" | tar zxf -



#
# Run GATK DiagnoseTargets
#
mark-section "DiagnoseTargets"
$java -jar GenomeAnalysisTK.jar -T DiagnoseTargets -R genome.fa -I "$sorted_bam_path" -L "$targets_bed_path" -o DiagnoseTargets.vcf -missing MissingTargets.vcf

mark-section "DepthOfCoverage"
$java -jar GenomeAnalysisTK.jar -T DepthOfCoverage -R genome.fa -I "$sorted_bam_path" -L "$targets_bed_path" -o DepthOfCoverage.txt -geneList "$refseq_path" -ct 20 --minMappingQuality 20
rm -f "$sorted_bam_path"


mark-section "uploading results"
mkdir -p ~/out/dtvcf/QC / ~/out/mtvcf/QC /
mv DiagnoseTargets.vcf ~/out/dtvcf/QC /"$sorted_bam_prefix".dt.vcf
mv MissingTargets.vcf ~/out/mtvcf/QC /"$sorted_bam_prefix".mt.vcf
mkdir -p ~/out/DepthOfCoverage1/QC / ~/out/DepthOfCoverage2/QC / ~/out/DepthOfCoverage3/QC / ~/out/DepthOfCoverage4/QC /
mkdir -p ~/out/DepthOfCoverage5/QC / ~/out/DepthOfCoverage6/QC / ~/out/DepthOfCoverage7/QC / ~/out/DepthOfCoverage8/QC /
mv DepthOfCoverage.txt ~/out/DepthOfCoverage1/QC /"$sorted_bam_prefix".DepthOfCoverage
mv DepthOfCoverage.txt.sample_cumulative_coverage_counts ~/out/DepthOfCoverage2/QC /"$sorted_bam_prefix".DepthOfCoverage.sample_cumulative_coverage_counts
mv DepthOfCoverage.txt.sample_cumulative_coverage_proportions ~/out/DepthOfCoverage3/QC /"$sorted_bam_prefix".DepthOfCoverage.sample_cumulative_coverage_proportions
mv DepthOfCoverage.txt.sample_gene_summary ~/out/DepthOfCoverage4/QC /"$sorted_bam_prefix".DepthOfCoverage.sample_gene_summary 
mv DepthOfCoverage.txt.sample_interval_statistics ~/out/DepthOfCoverage5/QC /"$sorted_bam_prefix".DepthOfCoverage.sample_interval_statistics
mv DepthOfCoverage.txt.sample_interval_summary ~/out/DepthOfCoverage6/QC /"$sorted_bam_prefix".DepthOfCoverage.sample_interval_summary
mv DepthOfCoverage.txt.sample_statistics ~/out/DepthOfCoverage7/QC /"$sorted_bam_prefix".DepthOfCoverage.sample_statistics
mv DepthOfCoverage.txt.sample_summary ~/out/DepthOfCoverage8/QC /"$sorted_bam_prefix".DepthOfCoverage.sample_summary

# upload 
dx-upload-all-outputs --parallel
mark-success
