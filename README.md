# 1. Debarcoding and Demultiplexing Raw Fastq Files (the ones generated by the sequencing machine)
##### This task is strictly dependent on both PCR and Sequencing protocols one has adopted in the Lab. 
In the example below, we are referring to a two-round PCR method on which two pairs of adapters were used for a paired-end deep sequencing:
a) Illumina overhang adapter sequence (For_i5 and Rev_i7) on the 1st round of amplifications, and 
b) iNEXT barcodes (For_A-H - Rev_1-12) on the 2nd round.
For more details on this approach, please refer to [Faircloth & Glenn, 2012 - PLoS One](http://journals.plos.org/plosone/article?id=10.1371/journal.pone.0042543).
##### If you have not adopted this approach and have all your fastq files already demultiplexed, please go straight to topic 2. 
## Debarcoding with QIIME1 tools
##### Please refer to http://qiime.org/install/install.html for instructions on how to install QIIME1
Activating qiime1 environment:
```
$ source activate qiime1
```
Creating a project parent directory for the whole analysis:
```
$ mkdir projectX
```
Entering this directory:
```
$ cd projectX/
```
Creating a directory where there will be all your raw fastq files:
```
$ mkdir raw_data
```
Entering this directory:
```
$ cd raw_data/
```
Running the following command in order to extract barcodes:
```
$ for i in `ls *fastq.gz | sed 's/R[12].*/R/g' | uniq`; do extract_barcodes.py -c barcode_paired_end -f `echo "$i""1_001.fastq.gz"` -r `echo "$i""2_001.fastq.gz"` --bc1_len 8 --bc2_len 8 -o `echo $i | sed 's/_.*/\-barcodes/g'`; done
```
>NOTE: Please adjust both --bc1_len and --bc2_len parameters according to your barcodes' length (in this example, we are using a length of 8 nucleotides for both barcodes).

Compressing and renaming debarcoded files in order to use them as input for qiime2 "demux" command below
```
$ for i in `ls -d *barcodes`; do gzip $i/*fastq; mv $i/reads1.fastq.gz $i/forward.fastq.gz; mv $i/reads2.fastq.gz $i/reverse.fastq.gz; done
```
Going back to the parent projectX directory:
```
$ cd ../
```
Deactivating qiime1 environment:
```
$ source deactivate
```
## Demultiplexing with QIIME2 tools and an ad-hoc PERL script 
##### Please refer to  https://docs.qiime2.org/2018.6/install for instructions on how to install QIIME2
Activating qiime2 environment:
```
$ source activate qiime2-2018.6
```
Preparing map files that will associate specific barcodes' combination to their respective samples:
```
$ perl prepBCmapFiles4Qiime2.pl iNext-barcodes.tab samples-map.tab 
```
>NOTES:
1) "prepBCmapFiles4Qiime2.pl" PERL script can be obtained [here](https://github.com/eltonjrv/microbiome.westernu/blob/bin/prepBCmapFiles4Qiime2.pl)
2) See/Download [iNext-barcodes.tab](https://github.com/eltonjrv/microbiome.westernu/blob/accFiles/iNext-barcodes.tab) and [samples-map.tab](https://github.com/eltonjrv/microbiome.westernu/blob/accFiles/samples-map.tab) as guiding examples, if you have adopted/encountered a demultiplexing situation like ours.

Creating a new directory to store all output files generated by the command above (barcodes_\*tab):
```
$ mkdir BCmapFiles
```
Moving barcodes_\*tab files to that new directory:
```
$ mv barcodes_*tab BCmapFiles/
```
Importing qiime1-debarcoded fastq files as qiime2 .qza format:
```
$ for i in `ls -d raw_data/*-barcodes`; do qiime tools import --type EMPPairedEndSequences --input-path $i --output-path `echo $i | sed 's/.*\///g' | sed 's/\-barcodes/\-input4demux/g'`; done
```
Running the actual demultiplexing task with "qiime demux" from qiime2:
```
$ for i in `ls BCmapFiles/`; do Mbase=`echo $i | sed 's/barcodes_[0-9]*\-//g' | sed 's/\.tab//g'`; qiime demux emp-paired --m-barcodes-file BCmapFiles/$i --m-barcodes-category BarcodeSequence --i-seqs `echo $Mbase`-input4demux.qza --o-per-sample-sequences `echo $i | sed 's/barcodes_//g' | sed 's/\.tab//g'`-demuxOUT.qza; done
```
Summarizing the demultiplexed qza files as qzv ones in order to be visualized at https://view.qiime2.org/:
```
$ for i in `ls *OUT.qza`; do qiime demux summarize --i-data $i --o-visualization `echo $i | sed 's/qza$/qzv/g'`; done
```
Deactivating qiime2 environment:
```
$ source deactivate
```

# 2. Microbiome Sequencing Analyses
## Trimming primers with Trimmomatic
##### Please refer to http://www.usadellab.org/cms/?page=trimmomatic for Trimmomatic download and instructions
```
$ for i in `ls inputs/*R1*fastq.gz`; do R1=`echo $i | sed 's/inputs\///g' | sed 's/\.fastq\.gz$//g'`; R2=`echo $i | sed 's/inputs\///g' | sed 's/\.fastq\.gz$//g' | sed 's/_R1_/_R2_/g'`; java -jar /path/to/Trimmomatic-0.33/trimmomatic-0.33.jar PE -phred33 $i `echo $i | sed 's/_R1_/_R2_/g'` $R1.fq $R1.unpaired.fq $R2.fq $R2.unpaired.fq HEADCROP:20; done
```
> NOTES:
1) Please pay attention that you need to type your trimmmomatic installation full PATH after the "java -jar" command above.
2) Edit the "HEADCROP:20" parameter according to your primers' average length. In this example, primers' length is ~ 20 bp.

Removing unpaired reads after trimming:
```
$ rm *unpaired*
```
Creating a new directory where trimmed-primers fastq files must be placed into:
```
$ mkdir inputs-woPrimers
```
Moving trimmed-primers fastq files to that new directory:
```
$ mv *fq inputs-woPrimers/
```
## Running UPARSE on sequenced amplicons
##### Please refer to https://www.drive5.com/usearch/download.html in order to download USEARCH tools
```
$ bash run-uparse-mj20-amp340-380-ZOTUs.bash inputs-woPrimers/ >run-uparse.log
```
>NOTES:
1) UPARSE pipeline does a series of tasks such as: mate joining and quality filtering of your sequenced amplicons, ZOTUs/ESVs assembly, taxonomic classification, and both alpha- and beta-diversity analyses on all your samples.
2) The "run-uparse-mj20-amp340-380-ZOTUs.bash" BASH script may be obtained [here](https://github.com/eltonjrv/microbiome.westernu/blob/master/run-uparse-mj20-amp340-380-ZOTUs.bash).
2.1) One may tune parameters on each command in the script according to his/her needs.
2.2) On the first uparse command "usearch -fastq_mergepairs" (line 36), we have set a minimum of 20 bp for merging R1 and R2 mates (accepting a maximum difference of 5 bases within the overlapped region, as set by default), as well as a minimum and maximum merged sequence length of 340 and 380, respectively. This is because our V4-V5 target amplicon region is ~ 400 bp long and, after primers are trimmed, we get a ~ 360 bp-long full amplicon to be joined, allowing an arbitrary  +/- 20 bp range.   
2.3) This script uses a customized RDP refDB, which we added a Mycoplasma_haemocanis 16S rRNA sequence from SILVA-DB (ID: H0HHaemo). In order to download it, please go [here](https://github.com/eltonjrv/microbiome.westernu/tree/refDB) and click on the "Clone or download" green button, then "Download ZIP". After unzipping the downloaded folder, uncompress the "rdp_16s-wMhaemocanis.fa.gz" file with "gunzip" command, and then copy it to the directory where you will run this script (e.g. projectX/). Line 53 from the script will format that file in order to be used as a refDB (\*.udb) for taxonomic classification purposes. If you want to use your own customized refDB, please edit script's line 53.
3) An "outputs" directory will be created and all uparse-generated files will be placed within it.

# 3. ZOTU/ESV Table Customization for Diagnostics Purposes
##### This topic is aimed at creating a customized ZOTU table which will make data visual inspection easier for clinicians
Move to the uparse-generated "outputs" directory:
```
$ cd outputs/
```
#### A metadata file will also be needed (which I'll call "samples-metadata.tsv" in this tutorial). Please have your metadata file prepared as this [example](https://github.com/eltonjrv/microbiome.westernu/blob/accFiles/samples-metadata.tsv).
>NOTES about the metadata table:
1) Columns 1 and 4 are mandatory.
2) Column 4 must contain any textual string that best describes your samples.
3) There must not be any colon ":" within your sample descriptions.

Once you have the three files ready, run the following command:
```
$ bash customize-OTUtable.bash zotus_table_uparse.tsv zotus.sintax samples-metadata.tsv
```
>NOTES:
1) "customize-OTUtable.bash script" may be obtained [here](https://github.com/eltonjrv/microbiome.westernu/blob/bin/customize-OTUtable.bash).
2) There are two other embedded scripts that must also be placed within the current directory where you'll run customize-OTUtable.bash: [customize-OTUtable.R](https://github.com/eltonjrv/microbiome.westernu/blob/bin/customize-OTUtable.R) and [sampleID-to-sampleDescription.pl](https://github.com/eltonjrv/microbiome.westernu/blob/bin/sampleID-to-sampleDescription.pl).
3) A "zotus_table_uparse-customized.tsv" main output file is created with the above command.

## Improving customized ZOTU table
In case one wants to keep only the last taxonomic level assigned to each zotu, instead of seeing the whole taxonomic classification, run the following:
```
$ sed 's/\td\:.*s\:/\ts\:/g' zotus_table_uparse-customized.tsv |  sed 's/\td\:.*g\:/\tg\:/g' | sed 's/\td\:.*f\:/\tf\:/g' | sed 's/\td\:.*o\:/\to\:/g' | sed 's/\td\:.*c\:/\tc\:/g' | sed 's/\td\:.*p\:/\tp\:/g' >zotus_table_uparse-customized.tsv2
```
##### Removing zotus that are present in Neg_Ctrl (NTC, water-only) from all samples.
```
$ grep '_neg_' zotus_table_uparse-customized.tsv2 | cut -f 2 | sort -u >ZotusOnNTC.txt
```
>NOTE: On the command above, replace '_neg_' by any other tag that characterizes the negative control in your sample Descriptions (e.g. NTC, water, blank, etc ...)
```
$  perl -e 'open(FILE, "zotus_table_uparse-customized.tsv2"); open(FILE2, "ZotusOnNTC.txt"); while(<FILE2>){chomp($_); $hash{$_} = 1;} while(<FILE>){chomp($_); @array = split(/\t/, $_); if($hash{$array[1]} eq ""){print("$_\n");}}' >zotus_table_uparse-wTaxa-customized-woNTCzotus.tsv
```
###### Keeping taxa of interest only (ToIs)
```
$ grep -P 'Ehrlichia|Anaplasma|Bartonella|Mycoplasma|Rickettsia' zotus_table_uparse-customized-woNTCzotus.tsv >zotus_table_uparse-wTaxa-customized-woNTCzotus-ToIonly.tsv
```
>NOTE: Replace the name of above genera by the ones of your interest (keep ' and | signs).

