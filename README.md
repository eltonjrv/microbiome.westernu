#### The following is a **Standard Operating Procedure (SOP)** for microbiome analyses applied to vector-borne disease diagnostics using 16S rRNA Next-Generation Sequencing.
##### **Research Team: Elton Vasconcelos, Joseph Geiger, Brian Oakley, Pedro Diniz.** College of Veterinary Medicine at Western University of Health Sciences, Pomona, CA, USA.
>Author: Elton Vasconcelos

################## Software to be installed prior executing this SOP ################## 
  - [QIIME1](http://qiime.org/install/install.html)\*
  - [QIIME2](https://docs.qiime2.org/2018.6/install)\*
  - [UPARSE](https://www.drive5.com/usearch/download.html)
  - [Trimmomatic](http://www.usadellab.org/cms/?page=trimmomatic)
  - [Muscle](https://www.drive5.com/muscle/downloads.htm)
  - Perl and Bash (already installed on any Unix-based system: Mac or Linux)
  - [Bioperl](https://bioperl.org/)
  - [R](https://www.r-project.org/)
 
 \* Only if you are running debarcoding and demultiplexing steps (topic 1 below).

#############################################################################

# 1. Debarcoding and Demultiplexing Raw Fastq Files (generated by the sequencing machine)
##### This task is strictly dependent on both PCR and Sequencing protocols one has adopted in the Lab. 
In the example below, we are referring to a two-round PCR method on which two pairs of adapters were used for a paired-end deep sequencing:
a) iNEXT barcodes (For_A-H - Rev_1-12) on the 1st round of amplifications, and 
b) Illumina overhang adapter sequences (For_i5 and Rev_i7) on the 2nd round.
For more details on this approach, please refer to [Faircloth & Glenn, 2012 - PLoS One](http://journals.plos.org/plosone/article?id=10.1371/journal.pone.0042543).
>NOTE: If you have not adopted this approach and/or have all your fastq files already demultiplexed, please go straight to topic 2. 

### 1.1. Debarcoding with QIIME1 tools
##### Please refer to http://qiime.org/install/install.html for instructions on how to install QIIME1
1.1.1.  Creating a project parent directory for the whole analysis:
```
$ mkdir projectX
```
1.1.2. Entering this directory:
```
$ cd projectX/
```
1.1.3. Creating a directory where there will be all your raw fastq files, and going within it:
```
$ mkdir raw_data
$ cd raw_data/
```
1.1.4. Activating qiime1 environment:
```
$ source activate qiime1
```
1.1.5. Running the following command in order to extract barcodes:
```
$ for i in `ls *fastq.gz | sed 's/R[12].*/R/g' | uniq`; do extract_barcodes.py -c barcode_paired_end -f `echo "$i""1_001.fastq.gz"` -r `echo "$i""2_001.fastq.gz"` --bc1_len 8 --bc2_len 8 -o `echo $i | sed 's/_.*/\-barcodes/g'`; done
```
>NOTE: Please adjust both --bc1_len and --bc2_len parameters according to your barcodes' length (in this example, we are using a length of 8 nucleotides for both barcodes).

1.1.6. Compressing and renaming debarcoded files in order to use them as input for qiime2 "demux" command below
```
$ for i in `ls -d *barcodes`; do gzip $i/*fastq; mv $i/reads1.fastq.gz $i/forward.fastq.gz; mv $i/reads2.fastq.gz $i/reverse.fastq.gz; done
```
1.1.7. Going back to the parent projectX directory:
```
$ cd ../
```
1.1.8. Deactivating qiime1 environment:
```
$ source deactivate
```
### 1.2. Demultiplexing with QIIME2 tools and an *ad hoc* PERL script 
##### Please refer to  https://docs.qiime2.org/2018.6/install for instructions on how to install QIIME2
1.2.1. Creating a directory for the demultiplexing job ad entering it:
```
$ mkdir demux
$ cd demux/
```
1.2.2. Preparing map files that will associate specific barcodes' combination to their respective samples:
```
$ perl prepBCmapFiles4Qiime2.pl iNext-barcodes.tab samples-map.tab 
```
>NOTES: One must have both the *ad hoc* script (prepBCmapFiles4Qiime2.pl) and two the input files (iNext-barcodes.tab and samples-map.tab) placed into the current directory.
I) "prepBCmapFiles4Qiime2.pl" PERL script can be obtained [here](https://github.com/eltonjrv/microbiome.westernu/blob/bin/prepBCmapFiles4Qiime2.pl).
II) See/Download [iNext-barcodes.tab](https://github.com/eltonjrv/microbiome.westernu/blob/accFiles/iNext-barcodes.tab) and [samples-map.tab](https://github.com/eltonjrv/microbiome.westernu/blob/accFiles/samples-map.tab) as guiding examples, if you have adopted/encountered a demultiplexing situation like ours.

1.2.3. Creating a new directory to store all output files generated by the command above (barcodes_\*tab):
```
$ mkdir BCmapFiles
```
1.2.4. Moving barcodes_\*tab files to that new directory:
```
$ mv barcodes_*tab BCmapFiles/
```
1.2.5. Activating qiime2 environment:
```
$ source activate qiime2-2018.6
```
1.2.6. Importing qiime1-debarcoded fastq files as qiime2 .qza format:
```
$ for i in `ls -d ../raw_data/*-barcodes`; do qiime tools import --type EMPPairedEndSequences --input-path $i --output-path `echo $i | sed 's/.*\///g' | sed 's/\-barcodes/\-input4demux/g'`; done
```
1.2.7. Running the actual demultiplexing task with "qiime demux" command:
```
$ for i in `ls BCmapFiles/`; do Mbase=`echo $i | sed 's/barcodes_[0-9]*\-//g' | sed 's/\.tab//g'`; qiime demux emp-paired --m-barcodes-file BCmapFiles/$i --m-barcodes-category BarcodeSequence --i-seqs `echo $Mbase`-input4demux.qza --o-per-sample-sequences `echo $i | sed 's/barcodes_//g' | sed 's/\.tab//g'`-demuxOUT.qza; done
```
1.2.8. Summarizing the demultiplexed qza files as qzv ones in order to be visualized at https://view.qiime2.org/ (Important for sequenced reads quality control assessment/visualization on each sample):
```
$ for i in `ls *OUT.qza`; do qiime demux summarize --i-data $i --o-visualization `echo $i | sed 's/qza$/qzv/g'`; done
```
1.2.9. Deactivating qiime2 environment:
```
$ source deactivate
```
1.2.10. Creating a directory to store and uncompress demultiplexed qza files, in order to have fastq files for topic 2 below:
```
$ mkdir demux-unzipped
$ cd demux-unzipped/
$ ln -s ../*demuxOUT.qza .
$ ls | xargs -i unzip {}
```
1.2.11. Going back to the parent projectX/ dir:
```
$ cd ../../
```

# 2. Microbiome Sequencing Analyses
2a) Since UPARSE will be the main microbiome analyzer used here, let's first create a "uparse-run" directory and then go within it:
```
$ mkdir uparse-run
$ cd uparse-run/
```
2b) Creating an "inputs" directory and placing symbolic links of demultiplexed fastq files that will be used by UPARSE:
```
$ mkdir inputs
$ cd inputs/
$ ln -s ../../demux/demux-unzipped/*/data/*gz .
$ cd ../
```
>NOTE: If you are coming straight to this topic because you already had demultiplexed your samples on your own, please disconsider the "ln -s" command above and just place your demultiplexed and compressed fastq files (\*.fastq.gz) into the "inputs" dir. Please also make sure that your fastq.gz file names start with "sampleID" followed by "\_1\_L001\_R[12]\_001.fastq.gz". For example, take a look at our [sample metadata table](https://github.com/eltonjrv/microbiome.westernu/blob/accFiles/samples-metadata.tsv) and see that, for the first sample, the paired file names will be the following: 865A1\_1\_L001\_R1\_001.fastq.gz and 865A1\_1\_L001\_R2\_001.fastq.gz.
### 2.1. Trimming primers with Trimmomatic (this must be done prior running UPARSE)
##### Please refer to http://www.usadellab.org/cms/?page=trimmomatic for Trimmomatic download and instructions
2.1.1. Running trimmomatic
```
$ for i in `ls inputs/*R1*fastq.gz`; do R1=`echo $i | sed 's/inputs\///g' | sed 's/\.fastq\.gz$//g'`; R2=`echo $i | sed 's/inputs\///g' | sed 's/\.fastq\.gz$//g' | sed 's/_R1_/_R2_/g'`; java -jar /path/to/your/Trimmomatic-x.xx/trimmomatic-x.xx.jar PE -phred33 $i `echo $i | sed 's/_R1_/_R2_/g'` $R1.fq $R1.unpaired.fq $R2.fq $R2.unpaired.fq HEADCROP:20; done
```
> NOTES:
I) Please pay attention that you need to type your trimmmomatic installation full PATH after the "java -jar" command above.
II) Edit the "HEADCROP:20" parameter according to your primers' average length. In this example, primers' length is ~ 20 bp.

2.1.2. Removing unpaired reads after trimming:
```
$ rm *unpaired*
```
2.1.3. Creating a new directory where trimmed fastq files must be placed into:
```
$ mkdir inputs-woPrimers
```
2.1.4. Moving trimmed fastq files to that new directory:
```
$ mv *fq inputs-woPrimers/
```
### 2.2. Running UPARSE on sequenced and trimmed amplicons
##### Please refer to https://www.drive5.com/usearch/download.html in order to download USEARCH tools
2.2.1. Running the actual microbiome analyzer tool:
```
$ bash run-uparse-mj20-amp340-380-ZOTUs.bash inputs-woPrimers/ 2>run-uparse.log
```
>NOTES:
I) UPARSE pipeline does a series of tasks such as: mate joining and quality filtering of your sequenced amplicons, ZOTUs/ESVs assembly, taxonomic classification, and both alpha- and beta-diversity analyses on all your samples.
II) The "run-uparse-mj20-amp340-380-ZOTUs.bash" BASH script may be obtained [here](https://github.com/eltonjrv/microbiome.westernu/blob/master/run-uparse-mj20-amp340-380-ZOTUs.bash).
IIa) One may tune parameters on each command in the script according to his/her needs.
IIb) On the first uparse command "usearch -fastq_mergepairs" (line 35), we have set a minimum of 20 bp for merging R1 and R2 mates (accepting a maximum difference of 5 bases within the overlapped region, as set by default), as well as a minimum and maximum merged sequence length of 340 and 380, respectively. This is because our V4-V5 target amplicon region is ~ 400 bp long and, after primers are trimmed, we get a ~ 360 bp-long full amplicon to be joined, allowing an arbitrary  +/- 20 bp range.   
IIc) This script uses a customized RDP refDB, which we added Mycoplasma_haemocanis, Ehrlichia_canis, and Anaplasma_platys 16S rRNA sequence from SILVA-DB (IDs: H0HHaemo, I8UCani3, and IE3Plat5). In order to download it, please go [here](https://github.com/eltonjrv/microbiome.westernu/tree/refDB) and click on the "Clone or download" green button, then "Download ZIP". After unzipping the downloaded folder, uncompress the "rdp_16s-wMhaemocanis-Ecanis-Aplatys.fa.gz" file with "gunzip" command, and then place it into the directory where you will run this script ("uparse-run/" in this example). Line 52 from the ""run-uparse-mj20-amp340-380-ZOTUs.bash"" script will format that file in order to be used as a refDB (\*.udb) for taxonomic classification purposes. If you want to use your own customized refDB, please edit script's line 52.
III) An "outputs" directory will be created and all uparse-generated files will be placed within it.


# 3. ZOTU/ESV Table Customization for Diagnostics Purposes
##### This topic is aimed at creating a customized ZOTU table which will make data visual inspection easier for clinicians
3a) Move to the uparse-generated "outputs" directory:
```
$ cd outputs/
```
#### ATTENTION: A metadata file will also be needed (which I'll call "samples-metadata.tsv" in this tutorial). Please have your metadata file prepared as this [example](https://github.com/eltonjrv/microbiome.westernu/blob/accFiles/samples-metadata.tsv) and place it within the current directory (outputs).
>NOTES about the metadata table:
I) Columns 1 and 4 are mandatory.
II) Column 4 must contain any textual string that best describes your samples.
III) There must not be any colon ":" nor blank spaces within your sample descriptions.

3b) There will already be two important uparse-generated files within the "outputs" dir ("zotus_table_uparse.tsv" and "zotus.sintax") . Once you have those two files plus your "samples-metadata.tsv" ready, run the following command:
```
$ bash customize-OTUtable.bash zotus_table_uparse.tsv zotus.sintax samples-metadata.tsv
```
>NOTES:
I) "customize-OTUtable.bash" script may be obtained [here](https://github.com/eltonjrv/microbiome.westernu/blob/bin/customize-OTUtable.bash).
II) There are two other embedded scripts that must also be placed within the current directory where you'll run customize-OTUtable.bash: [customize-OTUtable.R](https://github.com/eltonjrv/microbiome.westernu/blob/bin/customize-OTUtable.R) and [sampleID-to-sampleDescription.pl](https://github.com/eltonjrv/microbiome.westernu/blob/bin/sampleID-to-sampleDescription.pl).
III) A "zotus_table_uparse-customized.tsv" main output file is created with the above command.

### 3.1. Improving customized ZOTU table
3.1.1. In case one wants to keep only the last taxonomic level assigned to each zotu, instead of seeing the whole taxonomic classification, run the following:
```
$ sed 's/\td\:.*s\:/\ts\:/g' zotus_table_uparse-customized.tsv |  sed 's/\td\:.*g\:/\tg\:/g' | sed 's/\td\:.*f\:/\tf\:/g' | sed 's/\td\:.*o\:/\to\:/g' | sed 's/\td\:.*c\:/\tc\:/g' | sed 's/\td\:.*p\:/\tp\:/g' >zotus_table_uparse-customized.tsv2
```
### 3.2. Removing zotus that are present in Neg_Ctrl (NTC, water-only) from all samples.
3.2.1. Catching all zotus present in negative control samples (NTCs):
```
$ grep '_neg_' zotus_table_uparse-customized.tsv2 | cut -f 2 | sort -u >ZotusOnNTC.txt
```
>NOTE: On the command above, replace '\_neg\_' by any other tag that characterizes the negative control in your sample descriptions (e.g. NTC, water, blank, etc ...)

3.2.2. Generating a new zotu table without any zotu present in the NTCs:
```
$  perl -e 'open(FILE, "zotus_table_uparse-customized.tsv2"); open(FILE2, "ZotusOnNTC.txt"); while(<FILE2>){chomp($_); $hash{$_} = 1;} while(<FILE>){chomp($_); @array = split(/\t/, $_); if($hash{$array[1]} eq ""){print("$_\n");}}' >zotus_table_uparse-customized-woNTCzotus.tsv
```
### 3.3.  Keeping taxa of interest only (ToIs)
3.3.1. Catching your taxa of interest within the zotu table:
```
$ grep -P 'Ehrlichia|Anaplasma|Bartonella|Mycoplasma|Rickettsia' zotus_table_uparse-customized-woNTCzotus.tsv >zotus_table_uparse-wTaxa-customized-woNTCzotus-ToIonly.tsv
```
>NOTE: Replace the name of above genera by the ones of your interest (keep both ' and | signs).


# 4. Phylogenetic Diversity Investigation on ToIs
### 4.1. Preparing files for phylogenetic analyses of your ToI(s)
4.1.1. Within the uparse-generated "outputs/" directory, create a new directory to work on tree-prep files, and go within it:
```
$ mkdir ToI_trees
$ cd ToI_trees
```
4.1.2. Creating a symbolic link of both uparse-generated zotus.fa and zotus_table_uparse-customized.tsv files:
```
$ ln -s ../zotus.fa .
$ ln -s ../zotus_table_uparse-customized.tsv .
```
4.1.3. Catching ZOTU IDs of genus-level ToI from the customized ZOTU table (Ehrlichia and Bartonella are genus examples used herein as ToI):
```
$ grep 'g:Ehrlichia' zotus_table_uparse-customized.tsv | cut -f 2 | sort -u >Ehr-zotus.nam
$ grep 'g:Bartonella' zotus_table_uparse-customized.tsv | cut -f 2 | sort -u >Bart-zotus.nam
```
4.1.4. Catching ToI-ZOTU sequences and placing them in separate fasta files:	
```
$ perl seqs1.pl -outfmt fasta -incl Ehr-zotus.nam -seq zotus.fa >Ehr-zotus.fa
$ perl seqs1.pl -outfmt fasta -incl Bart-zotus.nam -seq zotus.fa >Bart-zotus.fa
```
>NOTES:
I) Please download both seqs1.pl and seqtools.pl PERL scripts from the [bin branch](https://github.com/eltonjrv/microbiome.westernu/tree/bin) and place them in the current work directory (ToI_trees). 
II) One must edit line 9 from "seqstools.pl" in order to properly point to your BioPerl full PATH, as well as line 31 from "seqs1.pl", replacing the seqtools.pl correct location.
III) One must also have BioPerl properly installed on the system in order to run this tool. Please refer to bioperl.org for instructions on how to install BioPerl.

### 4.2. Relying on SILVA type strains database for phylogenetic comparisons
#### Download "SILVA_132_SSURef_NR99_13_12_17_opt-typeStrains.fasta.gz" file from the [refDB branch](https://github.com/eltonjrv/microbiome.westernu/tree/refDB). 
This file contains 16S rRNA sequences for 23,127 type strain bacteria. Therefore, it is a good initial source for a comparison against your ToI-ZOTUs on a rough phylogenetic view. Of course, one must use the whole SILVA (~ 700k 16S RNA sequences) as well as BlastN against NCBI-NT db for assurance about "novel species/strains" discovery.
>NOTE: Go to [refDB branch](https://github.com/eltonjrv/microbiome.westernu/tree/refDB) and click on the "Clone or download" green button, then "Download ZIP". 

4.2.1. After unzipping the downloaded folder, uncompress such file like the following:
```
$ gunzip SILVA_132_SSURef_NR99_13_12_17_opt-typeStrains.fasta.gz
```
4.2.2. Catching ToI type strain sequences from SILVA:
```
$ perl geneSearcher.pl Ehrlichia SILVA_132_SSURef_NR99_13_12_17_opt-typeStrains.fasta 
$ perl geneSearcher.pl Bartonella SILVA_132_SSURef_NR99_13_12_17_opt-typeStrains.fasta 
```
>NOTE: "geneSearcher.pl" PERL script may be obtained [here](https://github.com/eltonjrv/bioinfo.scripts/blob/master/geneSearcher.pl).

4.2.3. Merging both ToI type strain sequences and ToI-ZOTUs in a single file:
```
$ cat Ehrlichia_from_SILVA_132_SSURef_NR99_13_12_17_opt-typeStrains.fasta Ehr-zotus.fa >Ehr-4tree.fasta
$ cat Bartonella_from_SILVA_132_SSURef_NR99_13_12_17_opt-typeStrains.fasta Bart-zotus.fa >Bart-4tree.fasta
```
### 4.3. Running a global Multiple Sequence Alignment (MSA) with muscle:
4.3.1. Running muscle in order to get an MSA in fasta format
```
$ muscle -in Ehr-4tree.fasta  -out Ehr-4tree_aln.fa
$ muscle -in Bart-4tree.fasta -out Bart-4tree_aln.fa
```
>NOTE: Refer to https://www.drive5.com/muscle/downloads.htm for instructions on how to download and install muscle.

4.3.2. Keeping the ToI-ZOTUs stretch only in the MSA, that is, the 16S rRNA target-amplicon region:
```
$ perl cutMSA.pl Ehr-4tree_aln.fa Zotu9 TGTGCCAG 360 for >Ehr-4tree_alnCut.fa 
$ perl cutMSA.pl Bart-4tree_aln.fa Zotu7 TATTGGA 360 for >Bart-4tree_alnCut.fa 
```
>NOTE: The *ad hoc* "cutMSA.pl" PERL script may be obtained [here](https://github.com/eltonjrv/bioinfo.scripts/blob/master/cutMSA.pl). Please read "cutMSA.pl" initial commented lines for instructions on how to run it. Those final "\*\_alnCut.fa" outputs must be used as inputs on [MEGA](https://www.megasoftware.net/), so the user can perform his/her most convenient phylogenetic inference methods.
