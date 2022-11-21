#!/bin/bash
#SBATCH --time=5:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=30G
#SBATCH --cpus-per-task=6   # Nb of threads we want to run on
#SBATCH -o atacseq/log/slurmjob-%A-%a
#SBATCH --job-name=deeptools_atac
#SBATCH --partition=short
#SBATCH --array=0-5

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

echo 'Data mining with deepTools'

# Handling errors
#set -x # debug mode on
set -o errexit # ensure script will stop in case of ignored error
set -o nounset # force variable initialisation
#set -o verbose
#set -euo pipefail

IFS=$'\n\t'

#Set up whatever package we need to run with
module purge
module load gcc/4.8.4 python/2.7.9 numpy/1.9.2 samtools/1.3 deepTools/3.1.2

echo "Set up directories ..." >&2
#Set up the temporary directory
SCRATCHDIR=/storage/scratch/"$USER"/"$SLURM_JOB_ID"

OUTPUT="$HOME"/atacseq/results/deeptools
mkdir -p "$OUTPUT"
mkdir -p -m 700 "$SCRATCHDIR"
cd "$SCRATCHDIR"

echo "Set up an array with alignment files .bam after cleaning with picard" >&2

tab=($(find "$HOME"/atacseq/results/picard -type f -name "*_trim_mapped_sorted_q2_nodup.bam"))
echo "tab = " >&2
printf '%s\n' "${tab[@]}" >&2

#Current filename
SHORTNAME=$(basename "${tab[$SLURM_ARRAY_TASK_ID]}" .bam )
echo "shortname = $SHORTNAME" >&2

#Run the program
echo "Start on $SLURMD_NODENAME: "`date` >&2

echo "fusion of files .bam into one with multiBamSummary" >&2
# --bamfiles <file> : Path to input files .bam
# -o <file> : Path to output files

multiBamSummary bins --bamfiles "${tab[@]}" -o "$OUTPUT"/array.npz

#Set up the path to the aggregate file
NPZ="$OUTPUT"/array.npz

echo "plotCorrelation in order to see the correlation between samples" >&2
# -in <file> : Path to aggregated file .bam
# -o <file> : Path to output files
# -p <character> : Choose whether you want to plot a heatmap or a scatterplot
# -c <character> : Choose whether to use the pearson or the spearman coefficient
# --removeOutliers : Will remove outliers from the samples

plotCorrelation -in "$NPZ" -p heatmap -c pearson -o "$OUTPUT"/heatmap.png --removeOutliers

echo "bamCoverage in order to see the coverage on the genome from each sample"
# -b <file> : Path to input file .bam
# -o <file> : Path to output files
# -of <character> : Choose whether the output will be in Bigwig or in bedgraph format

bamCoverage -b "${tab[$SLURM_ARRAY_TASK_ID]}" -o "$SHORTNAME".bedgraph -of bedgraph

echo "Comparison of the reads length according to samples with bamPEFragmentSize"
# -b <file> : Path to input file .bam
# -o <file> : Path to output files
# --samplesLabels <character> : Rename the samples by these labels

bamPEFragmentSize -b "${tab[@]}" --samplesLabel 0h_R1 0h_R2 0h_R3 24h_R1 24h_R2 24h_R3 --table "$OUTPUT"/table.tsv \
 -o "$OUTPUT"/hist.png

#Move results from scratch to user one's directory
mv  "$SCRATCHDIR" "$OUTPUT"

echo "Stop job : "`date` >&2
