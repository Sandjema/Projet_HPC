#!/bin/bash
#SBATCH --time=1:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
##SBATCH --mem=3G
#SBATCH --mem=12G
#SBATCH --cpus-per-task=6
#SBATCH -o atacseq/log/slurmjob-%A-%a
#SBATCH --job-name=trim_atac
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

#program modified by
__author__='Myriam Said'
__email__='myriam.said@etu.uca.fr


echo 'Trimming'

# Handling errors
#set -x # debug mode on
set -o errexit # ensure script will stop in case of ignored error
set -o nounset # force variable initialisation
#set -o verbose
#set -euo pipefail

IFS=$'\n\t'

# Set up whatever package we need to run with
module purge
module load gcc/8.1.0 python/3.7.1 cutadapt/1.18


echo "Set up directories ..." >&2
# Set up the temporary directory
SCRATCHDIR=/storage/scratch/"$USER"/"$SLURM_JOB_ID"

OUTPUT="$HOME"/results/atacseq/cutadapt
mkdir -p "$OUTPUT"
mkdir -p -m 700 "$SCRATCHDIR"
cd "$SCRATCHDIR"

# Set up data directory
DATA_DIR="$HOME/data/atacseq"

# Run the program
echo "Start on $SLURMD_NODENAME: "`date` >&2

echo "Set up 2 arrays with forward and reverse fastq.gz sequence files..." >&2
tab_fwd=($(ls "$DATA_DIR"/*_1.fastq.gz))
echo "tab_fwd = " >&2
printf '%s\n' "${tab_fwd[@]}" >&2

tab_rev=($(ls "$DATA_DIR"/*_2.fastq.gz))
echo "tab_rev = " >&2
printf '%s\n' "${tab_rev[@]}" >&2

echo $(basename "${tab_fwd[$SLURM_ARRAY_TASK_ID]}" .fastq.gz )

echo "Run the trimming with cutadapt tool..." >&2

cutadapt -j 1 -a Nextera R1=CTGTCTCTTATACACATCTCCGAGCCCACGAGAC -A Nextera R2=CTGTCTCTTATACACATCTGACGCTGCCGACGA \
    --output=output1.gz --paired-output=output2s.gz --error-rate=0.1 --times=1 --overlap=3 --minimum-length=20 --pair-filter=any --quality-cutoff=20 \
    "${tab_fwd[$SLURM_ARRAY_TASK_ID]}" "${tab_rev[$SLURM_ARRAY_TASK_ID]}"

# Move results in one's directory
mv  "$SCRATCHDIR" "$OUTPUT"

echo "Stop job : "`date` >&2
