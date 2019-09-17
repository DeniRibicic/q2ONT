# q2ONT
Bash pipeline for QIIME2 analysis of ONT generated full-length 16S rRNA sequences.

## Getting started

### Prerequsites 
  - Miniconda 3
  
````
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
chmod u+x Miniconda3-latest-Linux-x86_64.sh
./Miniconda3-latest-Linux-x86_64.sh
conda update conda
````    
  - QIIME2
  
````
wget https://data.qiime2.org/distro/core/qiime2-2019.7-py36-linux-conda.yml
conda env create -n qiime2-2019.7 --file qiime2-2019.7-py36-linux-conda.yml
# OPTIONAL CLEANUP
rm qiime2-2019.7-py36-linux-conda.yml
````
  - Trimmomatic
  
````conda install -c bioconda trimmomatic````


### Downloads
  - clone Git repository or just download q2ONT.sh script
  
  - Latest Silva q2 compatible db, i.e v.132
  
  ```` wget https://www.arb-silva.de/download/archive/qiime/SILVA_132_release.zip````




### How to use
1. After cloning ````q2ONT.sh```` bash script, place it somewhere in your path so it will be accessible, e.g. ````/home/user/bin````.
   Thereafter make it executable by running ````chmod u+x q2ONT.sh````.

   This script assumes that you have basecalled ONT generated ````.fast5```` files and have all corresponding ````.fastq```` files          placed in a direcotry, e.g ````0_basecalled-fastq````.

2. If not already done, you need to convert Silva representative sequnces (e.g. 99_otus.fasta) and corresponding taxonomy into q2          artefact.

      You can do this as follows:
      
      ````
      qiime tools import \
      --input-path Silva_132_release/rep_set/rep_set_all/99/99_otus.fasta \
      --output-path Silva_132_release/rep_set/rep_set_all/99/99_otus.qza 
      --type 'FeatureData[Sequence]'
      ````
      and
      
      ````
      qiime tools import \
      --input-path Silva_132_release/taxonomy/taxonomy_all/99/consensus_taxonomy_7_levels.txt \
      --output-path Silva_132_release/taxonomy/taxonomy_all/99/consensus_taxonomy_7_levels.qza \
      --type 'FeatureData[Taxonomy]' \
      --input-format HeaderlessTSVTaxonomyFormat
      ````
      
      Also, you will need to train classifier which will be used during taxonomical annotation.

      You can do this as follows:
      
      ````
      qiime feature-classifier fit-classifier-naive-bayes \
      --i-reference-reads Silva_132_release/rep_set/rep_set_all/99/99_otus.qza \
      --i-reference-taxonomy Silva_132_release/taxonomy/taxonomy_all/99/consensus_taxonomy_7_levels.qza \ 
      --o-classifier Silva_132_release/rep_set/rep_set_all/99/classifier.qza
      ````

   Now having everything in place go one direcory up from where your ````.fastq```` files are located. 
   i.e, if you type ````ls```` it should list directory containing your ````.fastq```` files.
   e.g.
   
   ````
   ls
   0_basecalled-fastq
   ````
   
3. Run the q2ONT.sh script: 

      ```q2ONT.sh [-i fastq_directory] [-j reference_seqs] [-c classifier] [-t threads]```


    where:
 
      ````[-i fastq_directory]```` is the directory containing all of your basecalled ````.fastq```` files; e.g ````0_basecalled-fastq````

      ````[-j reference_seqs]```` is reference sequence q2 artefact; e.g ````99_otus.qza````. Use complete path to it.

      ````[-c classifier]```` is q2 pretrained classifier; e.g.````classifier.qza````. Use complete path to it.

      ````[-t threads]```` is the number of CPU threads you want to use
       
 4. After a successful run, direcotry ````exported```` should be generated. This directory will contain files in native format (not q2      artefact) all ready to be loaded in Phyloseq package for further data exploration;

       1. biom file with added taxonomy (````table-with-taxonomy.biom````)
       2. newick tree file (````tree.nwk````) and 
       3. representative sequences file (````dna-sequences.fasta````)
       
   
 Happy QIIMEing!!
