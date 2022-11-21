#!/bin/bash
#SBATCH --time=0:30:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=30G
#SBATCH --cpus-per-task=1   # Nb of threads we want to run on
#SBATCH -o atacseq/log/slurmjob-%A-%a
#SBATCH --job-name=bedtools_atac
#SBATCH --partition=short
#SBATCH --array=0-0

# Program configuration
__author__='Nadia Goué'
__email__='nadia.goue@uca.fr'
__credits__=["Nadia Goué"]
__license__='GPL3'
__maintainer__='Nadia Goué'
__status__='Development'
__version__='0.0.1'
__developper__='Myriam Said'
__email__='myriam.said@etu.uca.fr'

echo 'Identification of DNA access sites with bedtools'

# Handling errors
#set -x # debug mode on
set -o errexit # ensure script will stop in case of ignored error
set -o nounset # force variable initialisation
#set -o verbose
#set -euo pipefail

IFS=$'\n\t'

#Set up whatever package we need to run with
module purge
module load gcc/4.8.4 bedtools/2.27.1

echo "Set up directories ..." >&2

#Set up the temporary directory
SCRATCHDIR=/storage/scratch/"$USER"/"$SLURM_JOB_ID"

OUTPUT="$HOME"/atacseq/results/bedtools
mkdir -p "$OUTPUT"
mkdir -p -m 700 "$SCRATCHDIR"
cd "$SCRATCHDIR"

echo "Set up two arrays with results from MACS2" >&2
MASC2_DIR="$HOME"/atacseq/results/macs2

tab_0h=($(find "$MASC2_DIR" -type f -name "50k_0h_*.narrowPeak"))
echo "tab_0h = " >&2
printf '%s\n' "${tab_0h[@]}" >&2

tab_24h=($(find "$MASC2_DIR" -type f -name "50k_24h_*.narrowPeak"))
echo "tab_24h = " >&2
printf '%s\n' "${tab_24h[@]}" >&2

# Current filename
SHORTNAME=$(basename "${tab_0h[$SLURM_ARRAY_TASK_ID]}" .bed )
echo "shortname = $SHORTNAME" >&2

# Run the program
echo "Start on $SLURMD_NODENAME: "`date` >&2

echo "Concatenate all files from each array" >&2
cat "${tab_0h[@]}" > "$OUTPUT"/50k_0h_trim_mapped_sorted_q2_nodup_combined_peaks.narrowPeak
cat "${tab_24h[@]}" > "$OUTPUT"/50k_24h_trim_mapped_sorted_q2_nodup_combined_peaks.narrowPeak

ZERO_DIR="$OUTPUT"/50k_0h_trim_mapped_sorted_q2_nodup_combined_peaks.narrowPeak
TWENTYFOUR_DIR="$OUTPUT"/50k_24h_trim_mapped_sorted_q2_nodup_combined_peaks.narrowPeak

echo "Sort and merge on each combined files"
# -k POS1,POS2 :
# -i : Path to input file

sort -k1,1 -k2,2n "$ZERO_DIR" | bedtools merge -i - > "$OUTPUT"/50k_0h_trim_mapped_sorted_q2_nodup_combined_merged_peaks.bed
sort -k1,1 -k2,2n "$TWENTYFOUR_DIR" | bedtools merge -i - > "$OUTPUT"/50k_24h_trim_mapped_sorted_q2_nodup_combined_merged_peaks.bed

ZERO_DIR="$OUTPUT"/50k_0h_trim_mapped_sorted_q2_nodup_combined_merged_peaks.bed
TWENTYFOUR_DIR="$OUTPUT"/50k_24h_trim_mapped_sorted_q2_nodup_combined_merged_peaks.bed

echo "Identification of common DNA access sites with intersect from bedtools" >&2
# -a <fichier> : Path to input files .bam
# -b <fichier> : Path to input files .bam
# -wa : Reporting the original A feature
# -v : Reporting the absence of any overlapping features

bedtools intersect -wa -a "$ZERO_DIR" -b "$TWENTYFOUR_DIR" > 50k_trim_mapped_sorted_q2_nodup_combined_merged_common.bed

echo "Identification of unique DNA access sites with intersect from bedtools" >&2

bedtools intersect -wa -v -a "$ZERO_DIR" -b "$TWENTYFOUR_DIR" > 50k_0h_trim_mapped_sorted_q2_nodup_combined_merged_unique.bed
bedtools intersect -wa -v -a "$TWENTYFOUR_DIR" -b "$ZERO_DIR" > 50k_24h_trim_mapped_sorted_q2_nodup_combined_merged_unique.bed

#Move results user one's directory
mv  "$SCRATCHDIR" "$OUTPUT"

echo "stop job : "'date' >&2
