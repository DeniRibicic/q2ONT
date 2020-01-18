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
wget https://data.qiime2.org/distro/core/qiime2-2019.10-py36-linux-conda.yml
conda env create -n qiime2-2019.7 --file qiime2-2019.10-py36-linux-conda.yml
# OPTIONAL CLEANUP
rm qiime2-2019.7-py36-linux-conda.yml
````
  - Trimmomatic
  
````conda install -c bioconda trimmomatic````

  - Porechop

````
git clone https://github.com/rrwick/Porechop.git
cd Porechop
python3 setup.py install
porechop -h
````

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
 
 
 ### What does script do?
 
 The file output from the workflow can be traced based on file indexing (prefix numbers added as the files are generated).  
 
 1) First step includes concatenating all ````.fastq```` files into one file.
 
 2) ````porechop```` is employed to demultiplex your reads.
 
 3) ````trimmomatic```` will discard all reads shorter than 1400 bp. All reads longer than 1400 bp will be cropped to that length.
    These settings can be changed if desired, you will just have to modify it manually beofre running the script. You want to look at        ````MINLEN:1400 CROP:1400```` parameter.
    
 4) QIIME2 imports now reads creating ````4_single-end-demux.qza```` artefact together with visualization file                               ````4_single-end-demux.qzv```` which can be viewed in QIIME2View online tool.
 
 5) q2 will dereplicate sequences and create also visualization files for each.
 
 6) Chimeric sequences are screened for and are filtered out from the workflow. Subsequently OTUs are clustered via open reference           option using ````vsearch```` at 85% identity. This can be also changed manually digging into script. However, due to high error rate     of ONT platform, it is advised to cluster otu at 85% similarity or even less*.
 
 7) Reads are aligned using ````mafft````
 
 8) Alignments are masked.
 
 9) Un-rooted tree is created.
 
 10) Rooted tree is created.
 
 11) Taxonomy is assigned using pre-trained SILVA classifier
 
 * Curren, Emily, et al. "Rapid profiling of tropical marine cyanobacterial communities." Regional Studies in Marine Science 25 (2019):    100485.
