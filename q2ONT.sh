#!/bin/bash
#  This is a wrapper script for automation of QIIME2 analysis of ONT generated full-length 16S rRNA amplicons.
#
#  Version 1.0 (August 20, 2019)
#
#  This script is adjusted to work with qiime2-2019.4 release
#
#  Copyright (c) 2019-2020 Deni Ribicic
#
#  This script is provided -as-is-, without any express or implied
#  warranty. In no event will the authors be held liable for any damages
#  arising from the use of this software.
#
#  Also, this script is a free piece of software and you are allowed to
#  modify it to your own needs.

echo ""
echo ""

how_to_use="\nHow to use:\n\n$(basename "$0") [-i fastq_directory] [-j reference_seqs] [-c classifier] [-t threads]\n"

while :
do
    case "$1" in
      -h | --help)
          echo -e $how_to_use
          exit 0
          ;;
      -i)
          fastq_directory=$2
          shift 2
          echo "Working directory: $fastq_directory"
          ;;
      -j)
           reference_seqs=$2
           shift 2
           echo "Reference sequences: $reference_seqs"
           ;;
      -c)
           classifier=$2
           shift 2
           echo "Pretrained full-length 16S rRNA classifier: $classifier"
           ;;
      -t)
           threads=$2
           shift 2
           echo "Number of CPU threads: $threads"
           ;;
       --) # End of all options
           shift
           break
           ;;
       -*)
           echo "Error: Unknown option: $1" >&2
           ## or call function display_help
           exit 1
           ;;
        *) # No more options
           break
           ;;
    esac
done

echo ""
echo ""

#  prepare fastq file by merging it all into one file
echo "concatenating .fastq files..."
cat $fastq_directory/*.fastq > 1_total_run.fastq
gzip 1_total_run.fastq
if [ -f "1_total_run.fastq.gz" ]; then
echo ""
echo ""
echo "all fastq files merged!"
else
echo "fastq files failed to merge!!!"
fi
echo ""
echo ""

#  demultiplex samples and trim adapters
echo "demultiplexing and trimming reads"
porechop -i 1_total_run.fastq.gz -b 2_demux-reads
if [ -d "2_demux-reads" ]; then
echo ""
echo ""
echo "samples successfully demultiplexed"
else
echo "demultiplexing failed!!!"
fi

echo ""
echo ""
#  QC on length, renaming and moving files to a new directory
mkdir 3_QC
cd 2_demux-reads
echo ""
echo ""
echo "quality assessing reads; filtering and trimming to 1400 bp"
for file in *.fastq.gz; do
trimmomatic SE -threads $threads -phred33 $file $file-trimmed MINLEN:1400 CROP:1400
done
cd ..
mv 2_demux-reads/*.gz-trimmed 3_QC/

cd 3_QC
for file in *-trimmed; do
mv "$file" "${file/.gz-trimmed/}" 
done

for file in *.fastq; do
mv "$file" "${file/./_01_L001_R1_001.}"
done

gzip *.fastq
cd ..

echo ""
echo ""
#  load QIIME2
echo "activating QIIME2..."
source activate qiime2-2019.4
echo "qiime2-2019.4 active"

#  Get input files and locations
echo "looking for input files ..."
echo ""
if [ -d "3_QC" ]; then
echo "using '3_QC' folder to import reads ..."
qiime tools import \
--type 'SampleData[SequencesWithQuality]' \
--input-path 3_QC \
--input-format CasavaOneEightSingleLanePerSampleDirFmt \
--output-path 4_single-end-demux.qza
else
echo ""
echo ""
echo "wrong format. Check your .fastq filenames!!!"
fi

if [ -f "4_single-end-demux.qza" ]; then
echo "reads successfully imported as '.qza' file!"
echo ""
echo ""
echo "preparing visualization file ..."
qiime demux summarize \
--i-data 4_single-end-demux.qza \
--o-visualization 4_single-end-demux.qzv
else
echo "reads FAILED TO IMPORT!!!"
fi

echo ""
echo ""
echo "dereplicating sequences..."
qiime vsearch dereplicate-sequences \
--i-sequences 4_single-end-demux.qza \
--o-dereplicated-table 5_derep-table.qza \
--o-dereplicated-sequences 5_derep-seqs.qza

if [ -f "5_derep-table.qza" ]; then
echo "sequences successfully dereplicated!"
echo ""
echo ""
echo "generating visualization files..."
qiime feature-table tabulate-seqs \
--i-data 5_derep-seqs.qza \
--o-visualization 5_derep-seqs.qzv

qiime feature-table summarize \
--i-table 5_derep-table.qza \
--o-visualization 5_derep-table.qzv
else
echo "sequences FAILED TO DEREPLICATE!!!"
fi

#chimera screening
echo ""
echo ""
echo "screening for chimeric sequences..."
qiime vsearch uchime-ref \
--i-table 5_derep-table.qza \
--i-sequences 5_derep-seqs.qza \
--i-reference-sequences $reference_seqs \
--output-dir 6.1_uchime-ref-out \
--p-threads $threads

if [ -d "6.1_uchime-ref-out" ]; then
echo "chimeric sequences detected and mapped!"
echo ""
echo ""
echo "visualizing chimera stats"
qiime metadata tabulate \
--m-input-file 6.1_uchime-ref-out/stats.qza \
--o-visualization 6.1_uchime-ref-out/stats.qzv
else
echo "FAILED TO DETECT or MAP chimeric sequences!!!"
fi

#filtering out chimeric sequences and features together with borderline chimera
echo ""
echo ""
echo "filtering chimeric sequences..."

qiime feature-table filter-features \
--i-table 5_derep-table.qza \
--m-metadata-file 6.1_uchime-ref-out/nonchimeras.qza \
--o-filtered-table 6.1_uchime-ref-out/table-nonchimeric-wo-borderline.qza

qiime feature-table filter-seqs \
--i-data 5_derep-seqs.qza \
--m-metadata-file 6.1_uchime-ref-out/nonchimeras.qza \
--o-filtered-data 6.1_uchime-ref-out/rep-seqs-nonchimeric-wo-borderline.qza

if [ -f "6.1_uchime-ref-out/rep-seqs-nonchimeric-wo-borderline.qza" ]; then
echo "chimeric sequences filtered from the dataset!"
echo ""
echo ""
echo "visualizing non-chimeric data..."
qiime feature-table summarize \
--i-table 6.1_uchime-ref-out/table-nonchimeric-wo-borderline.qza \
--o-visualization 6.1_uchime-ref-out/table-nonchimeric-wo-borderline.qzv
else
echo "FAILED to FILTER OUT chimeric sequences!!!"
fi

#OTU clustering
echo ""
echo ""
echo "OTU clustering at 85% similarity ..."
echo ""
echo ""
echo "time for a coffee, this will take a bit..."
qiime vsearch cluster-features-open-reference \
--i-table 6.1_uchime-ref-out/table-nonchimeric-wo-borderline.qza \
--i-sequences 6.1_uchime-ref-out/rep-seqs-nonchimeric-wo-borderline.qza \
--i-reference-sequences $reference_seqs \
--p-perc-identity 0.85 \
--o-clustered-table 6.2_table-op_ref-85.qza \
--o-clustered-sequences 6.2_rep-seqs-op_ref-85.qza \
--o-new-reference-sequences 6.2_new-ref-seqs-op_ref-85.qza \
--p-threads $threads

#aligning sequences
if [ -f "6.2_rep-seqs-op_ref-85.qza" ]; then
echo ""
echo ""
echo "OTU clustering successful!"
echo ""
echo ""
echo "sequence alignment with mafft..."
qiime alignment mafft \
--i-sequences 6.2_rep-seqs-op_ref-85.qza \
--o-alignment 7_aligned-filtered_derep-seqs.qza
else
echo "OTU clustering FAILED!!!"
fi

if [ -f "7_aligned-filtered_derep-seqs.qza" ]; then
echo "sequences successfully aligned!"
echo ""
echo ""
echo "masking and filtering highly variable positions..."
qiime alignment mask \
--i-alignment 7_aligned-filtered_derep-seqs.qza \
--o-masked-alignment 8_masked-aligned-filtered_derep-seqs.qza
else
echo "sequences FAILED to ALIGN!!!"
fi 

if [ -f "8_masked-aligned-filtered_derep-seqs.qza" ]; then
echo "highly variable positions masked and filtered out!"
echo ""
echo ""
echo "creating un-rooted tree..."
qiime phylogeny fasttree \
--i-alignment 8_masked-aligned-filtered_derep-seqs.qza \
--o-tree 9_unrooted-tree.qza
else
echo "FAILED to MASK and FILTER OUT highly variable positions!!!"
fi

if [ -f "9_unrooted-tree.qza" ]; then
echo "un-rooted tree generated!"
echo ""
echo ""
echo "creating rooted tree..."
qiime phylogeny midpoint-root \
--i-tree 9_unrooted-tree.qza \
--o-rooted-tree 10_rooted-tree.qza
else
echo "FAILED TO GENERATE un-rooted tree!!!"
fi

if [ -f "10_rooted-tree.qza" ]; then
echo "rooted tree generated"
else
echo "FAILED TO GENERATE rooted tree!!!"
fi


#Finally assigning taxonomy
echo ""
echo ""
echo "Assigning taxonomy..."
echo ""
echo ""
echo "relax and get another cup of coffee... this may take a while..."
qiime feature-classifier classify-sklearn \
--i-classifier $classifier \
--i-reads 6.2_rep-seqs-op_ref-85.qza \
--o-classification 11_taxonomy-sklearn.qza \
--p-reads-per-batch 5000
if [ -f "11_taxonomy-sklearn.qza" ]; then
echo "taxonomy successfuly assigned"
else 
echo "taxonomy FAILED TO ASSIGN!!!"
fi

echo ""
echo ""
echo "exporting out of q2 format and making phyloseq ready..."
echo "all the converted files will be located in folder 'exported'"
echo ""
echo ""

#  make a directory for files to be exported 
mkdir exported

#  converting all necessary files for Phyloseq input
echo "export 6.2_table-op_ref-85.qza to biom file (feature-table.biom)"
qiime tools export --input-path 6.2_table-op_ref-85.qza --output-path exported/
if [ -f "exported/feature-table.biom" ]; then
echo "biom file successfully exported :)"
else
echo "biom file FAILED TO EXPORT!!!"
fi

echo ""
echo ""
echo "export 11_taxonomy-sklearn.qza to text file (taxonomy.tsv)"
qiime tools export --input-path 11_taxonomy-sklearn.qza --output-path exported/
if [ -f "exported/taxonomy.tsv" ]; then
echo "taxonomy file successfully exported :)"
else
echo "taxonomy file FAILED TO EXPORT!!!"
fi

echo ""
echo ""
echo "export 10_rooted-tree.qza to newick file format (tree.nwk)"
qiime tools export --input-path 10_rooted-tree.qza --output-path exported/
if [ -f "exported/tree.nwk" ]; then
echo "tree file successfully exported :)"
else
echo "tree file FAILED TO EXPORT!!!"
fi

echo ""
echo ""
echo "export 6.2_rep.seqs-op_ref-85.qza to fasta file (dna-sequences.fasta)"
qiime tools export --input-path 6.2_rep-seqs-op_ref-85.qza --output-path exported/
if [ -f "exported/dna-sequences.fasta" ]; then
echo "fasta file successfully exported :)"
else
echo "fasta file FAILED TO EXPORT!!!"
fi
echo ""
echo ""
echo ""

#edit the taxonomy.tsv file for compatible header line
sed -i -e 's/Feature ID/#OTUID/g; s/Taxon/taxonomy/g; s/Confidence/confidence/g' exported/taxonomy.tsv

#Finally, add taxonomy to biom file
biom add-metadata -i exported/feature-table.biom -o exported/table-with-taxonomy.biom --observation-metadata-fp exported/taxonomy.tsv --sc-separated taxonomy
if [ -f "exported/table-with-taxonomy.biom" ]; then
echo ""
echo "biom file with taxonomy successfully generated <table-with-taxonomy.biom> :)"
else
echo "biom file with taxonomy FAILED TO EXPORT!!!"
fi


echo ""
echo ""
echo ""
echo "~~~ END ~~~"
