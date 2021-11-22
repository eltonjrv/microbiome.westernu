### **Standard Operating Procedure (SOP)** for microbiome analyses applied to vector-borne disease diagnostics using 16S rRNA Next-Generation Sequencing.
#### Research Team: Elton Vasconcelos*, Chayan Roy, Joseph Geiger, Brian Oakley, Pedro Diniz.
##### Affiliation: College of Veterinary Medicine at Western University of Health Sciences, Pomona, CA, USA. 
##### \*Current affiliation: Leeds Omics, University of Leeds, UK.
>Author: Elton Vasconcelos (Oct/2018)

>Reviewed and retested by Chayan Roy and Elton Vasconcelos (Sep/2020).
>Reviewed by Elton Vasconcelos (Nov/2021)

If you use this pipeline (or part of it) on your research, please cite [Vasconcelos et al., 2021 - BMC Vet.Res.](https://bmcvetres.biomedcentral.com/articles/10.1186/s12917-021-02969-9)

################## Software to be installed prior executing this SOP ################## 
  - [QIIME2](https://docs.qiime2.org/2021.8/install)\*
  - [UPARSE](https://www.drive5.com/usearch/download.html)
  - [Trimmomatic](http://www.usadellab.org/cms/?page=trimmomatic)
  - [Muscle](https://drive5.com/muscle5/)
  - Perl and Bash (already installed on any Unix-based system: Mac or Linux)
  - [Bioperl](https://bioperl.org/)
  - [R](https://www.r-project.org/)
 
 \* Only if you are running demultiplexing step (topic 1 below).

#############################################################################

# 1. Debarcoding and Demultiplexing Raw Fastq Files (generated by the sequencing machine)
##### This task is strictly dependent on both PCR and Sequencing protocols one has adopted in the Lab. 
In the example below, we are referring to a two-round PCR method on which **two pairs of adapters** were used for a **paired-end sequencing**:
a) iNEXT barcodes (For_A-H - Rev_1-12) on the 1st round of amplifications, and 
b) Illumina overhang adapter sequences (For_i5 and Rev_i7) on the 2nd round.
For more details on this approach, please refer to [Faircloth & Glenn, 2012 - PLoS One](http://journals.plos.org/plosone/article?id=10.1371/journal.pone.0042543).
>NOTE: If you have not employed this multiplexing approach or have all your fastq files already demultiplexed, please take a look at [qiime2 demultiplexing forum](https://forum.qiime2.org/t/demultiplexing-and-trimming-adapters-from-reads-with-q2-cutadapt/2313) or move straight to topic 2 below. 

### 1.1. Preparing directories and importing raw fastq files to QIIME2
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
1.1.4. Transferring your fastq files to the current work directory (raw_data/) with your most suitable commando/tool (e.g. cp, scp, ftp, WinScp, FileZilla, etc ...).
1.1.5. Renaming your fastq files. 
1.1.5.1. If you have only one pair of fastq files, rename R1 to forward.fastq.gz and R2 to reverse.fastq.gz, then move straight to sub-item 1.1.6:
```
$ mv your_R1_file.fastq.gz forward.fastq.gz
$ mv your_R2_file.fastq.gz reverse.fastq.gz
```
1.1.5.2. If you have several (n) pairs of fastq files, it will be required to create several (n) experimental subdirectories within raw_data/;
1.1.5.2.a. For example, the command below automatically creates 10 subdirectories named "ExpN", where N is a number from 1 to 10. Edit the command according to the total number of fastq files pairs you have on hands.
```
$ for i in `seq 1 10`; do mkdir Exp$i; done
```
1.1.5.2.b. Then move each pair of fastq files that were already placed within raw_data/ (sub-item 1.1.4) to each respective recently created subdirectory (Exp1 to Exp10), and rename the files. Below is an example of the commands' set for the Exp1 instance:
```
$ mv your_first_fastq_pair_R[12]*.fastq.gz Exp1/
$ cd Exp1/
$ mv your_first_fastq_pair_R1.fastq.gz forward.fastq.gz
$ mv your_first_fastq_pair_R2.fastq.gz reverse.fastq.gz
$ cd ../
```
>NOTE: Since we don't know how your fastq files are originally named, we recommend that you move them separately with the individual commands set above. In case you are famliar with the Unix Shell, feel free to do it through a "for" loop.

1.1.6. Creating a directory for the demultiplexing job and entering it:
```
$ mkdir demux
$ cd demux/
```
1.1.7. Activating qiime2 environment (once you have properly installed it through this [link](https://docs.qiime2.org/2021.8/install):
```
$ source activate qiime2-2021.8
```
1.1.8. Importing fastq files as qiime2 .qza format:
1.1.8.1. For a single pair of fastq files (coming from 1.1.5.1 sub-item above), do the following:
```
$  qiime tools import --type MultiplexedPairedEndBarcodeInSequence --input-path ../raw_data/ --output-path multiplexed-seqs.qza
```
1.1.8.2. For several (n) pairs of fastq files (coming from 1.1.5.2 sub-item above), do this instead:
```
$ for i in `ls -d ../raw_data/Exp*/`; do qiime tools import --type MultiplexedPairedEndBarcodeInSequence --input-path $i --output-path `echo $i | sed 's/.*\///g'`-multiplexed-seqs.qza; done
```

### 1.2. Debarcoding and demultiplexing
1.2.1. Preparing a sample-barcode map file (samples-map-BCseq.tab) by running a single-line *ad hoc* PERL script
```
$ perl -e 'open(FILE, "samples-map.tab"); open(FILE2, "iNext-barcodes.tab"); while(<FILE2>) {chomp($_); @array2 = split(/\t/, $_); $hash{$array2[0]} = $array2[1];} while(<FILE>) {chomp($_); @array = split(/\t/, $_); if($hash{$array[1]} ne "" && $hash{$array[2]} ne "") {print("$array[0]\t$hash{$array[1]}\t$hash{$array[2]}\n");} else {print("$_\t**error** ->barcode sequence not found\n");}}' >samples-map-BCseq.tab
```
>NOTES: One must prepare and place both input files (iNext-barcodes.tab and samples-map.tab) into the current directory (demux/). Please see/download [iNext-barcodes.tab](https://github.com/eltonjrv/microbiome.westernu/blob/accFiles/iNext-barcodes.tab) and [samples-map.tab](https://github.com/eltonjrv/microbiome.westernu/blob/accFiles/samples-map.tab) as guiding examples, in case you have employed a demultiplexing situation like ours. The generated output from the command above is [samples-map-BCseq.tab](https://github.com/eltonjrv/microbiome.westernu/blob/accFiles/samples-map-BCseq.tab), which will be used in downstream steps.

1.2.2. Splitting samples-map-BCseq.tab into N different iNext-Rev barcode combinations (one map file for each iNext-Rev barcode):
```
$ for i in `grep -v '^\#' samples-map-BCseq.tab | cut -f 3 | sort -u`; do grep -P "Sample|$i" samples-map-BCseq.tab >iNextRev_`echo $i`-samples-map-BCseq.tab; done
```
>NOTE: At the time this SOP was written, "qiime cutadapt" function considered only one iNext-Rev barcode per sample-barcode map file.

1.2.3. Actual debarcoding and demultiplexing process with qiime cutadapt
1.2.3.1. Debarcoding and demultiplexing a single pair of fastq file (multiplexed-seqs.qza file created on 1.1.8.1. step above):
```
$ for i in `ls iNextRev*tab`; do qiime cutadapt demux-paired --i-seqs multiplexed-seqs.qza --m-forward-barcodes-file $i --m-forward-barcodes-column iNext-For --m-reverse-barcodes-file $i --m-reverse-barcodes-column iNext-Rev --o-per-sample-sequences `echo $i | sed 's/\-samples.*$//g'`-demultiplexed-seqs.qza --o-untrimmed-sequences `echo $i | sed 's/\-samples.*$//g'`-untrimmed.qza --verbose; done
```
1.2.3.2. Debarcoding and demultiplexing several (n) pairs of fastq files (Exp\*-multiplexed-seqs.qza files created on 1.1.8.2. step above):
```
$ for j in `ls Exp*seqs.qza`; do for i in `ls iNextRev*tab`; do qiime cutadapt demux-paired --i-seqs $j --m-forward-barcodes-file $i --m-forward-barcodes-column iNext-For --m-reverse-barcodes-file $i --m-reverse-barcodes-column iNext-Rev --o-per-sample-sequences `echo $j | sed 's/\-multiplexed.*$//g'`_`echo $i | sed 's/\-samples.*$//g'`-demultiplexed-seqs.qza --o-untrimmed-sequences `echo $j | sed 's/\-multiplexed.*$//g'`_`echo $i | sed 's/\-samples.*$//g'`-untrimmed.qza --verbose; done; done
```
1.2.4. Removing untrimmed.qza files:
```
$ rm *untrimmed.qza
```
1.2.5. Summarizing the demultiplexed qza files as qzv ones in order to be visualized at https://view.qiime2.org/ (Important for sequenced reads quality control assessment/visualization on each sample):
```
$ for i in `ls *demultiplexed-seqs.qza`; do qiime demux summarize --i-data $i --o-visualization `echo $i | sed 's/qza$/qzv/g'`; done
```
1.2.6. Deactivating qiime2 environment:
```
$ source deactivate
```
or
```
$ conda deactivate
```
1.2.7. Creating a directory to store and uncompress demultiplexed qza files, in order to have fastq files for topic 2 below:
```
$ mkdir demux-unzipped
$ cd demux-unzipped/
$ ln -s ../*demultiplexed-seqs.qza .
$ ls | xargs -i unzip {}
```
1.2.8. Going back to the parent projectX/ dir:
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
$ bash run-uparse-amp250-450-ZOTUs.bash inputs-woPrimers/ 2>run-uparse.log
```
>NOTES:
I) UPARSE pipeline does a series of tasks such as: mate joining and quality filtering of your sequenced amplicons, ZOTUs/ESVs assembly, taxonomic classification, and both alpha- and beta-diversity analyses on all your samples.
II) "run-uparse-amp250-450-ZOTUs.bash" BASH script may be obtained [here](https://github.com/eltonjrv/microbiome.westernu/blob/master/run-uparse-amp250-450-ZOTUs.bash).
IIa) One may tune parameters on each command in the script according to his/her needs.
IIb) This script uses a customized RDP refDB, which we have added Ehrlichia_canis, Ehrlichia_chafeensis, Anaplasma_platys, Anaplasma_phagocytophilum, Mycoplasma_haemocanis and Mycoplasma_haematoparvum 16S rRNA sequences. In order to download it, please go [here](https://github.com/eltonjrv/microbiome.westernu/tree/refDB) and click on the "Clone or download" green button, then "Download ZIP". After unzipping the downloaded folder, uncompress the "rdp_16s_extra_seqs.fa.gz" file with "gunzip" command, and then place it into the directory where you will run this script ("uparse-run/" in this example). Line 52 from the ""run-uparse-amp250-450-ZOTUs.bash"" script will format that file in order to be used as a refDB (\*.udb) for taxonomic classification purposes. If you want to use your own customized refDB fasta file, please edit script's lines 52 and 53.
IIc) In order to play with different OTU clustering % identity thresholds (95, 97, and 99%), one must run the alternative "run-uparse-amp250-450-OTUs95_97_99_100.bash" script that is provided [here](https://github.com/eltonjrv/microbiome.westernu/blob/master/run-uparse-amp250-450-OTUs95_97_99_100.bash).
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
3.1.1. In case one wants to keep only the last taxonomic level assigned to each zotu, instead of seeing the whole taxonomic classification (from phylum to species), run the following:
```
$ sed 's/\td\:.*s\:/\ts\:/g' zotus_table_uparse-customized.tsv |  sed 's/\td\:.*g\:/\tg\:/g' | sed 's/\td\:.*f\:/\tf\:/g' | sed 's/\td\:.*o\:/\to\:/g' | sed 's/\td\:.*c\:/\tc\:/g' | sed 's/\td\:.*p\:/\tp\:/g' >zotus_table_uparse-customized.tsv2
```
### 3.2. Subtracting NTC-derived ZOTUs counts OR removing the whole NTC-derived ZOTUs content from all target samples.
3.2.1. Subtracting NTC-derived ZOTUs counts from target samples
```
$ Rscript NTC-ZOTUs-subtraction.R zotus_table_uparse-customized.tsv
```
>NOTE: "NTC-ZOTUs-subtraction.R" script is provided [here](https://github.com/eltonjrv/microbiome.westernu/blob/bin/NTC-ZOTUs-subtraction.R).

3.2.2. Alternatively, one may want to remove the whole NTC-derived ZOTUs content. So, first catch all zotus present in negative control samples:
```
$ grep '_neg_' zotus_table_uparse-customized.tsv2 | cut -f 2 | sort -u >ZotusOnNTC.txt
```
>NOTE: On the command above, replace '\_neg\_' by any other tag that characterizes the negative control in your sample descriptions (e.g. NTC, water, blank, etc ...)

3.2.3. Then, with the following PERL code, create a new zotu table without any NTC-derived zotu:
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
