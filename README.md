### Debarcoding and Demultiplexing Raw Fastq Files (the ones generated by the sequencing machine)
# This task is quite specific to both PCR and Sequencing protocols you have adopted in the Lab.
# In the example below, we are referring to a two-round PCR method which two pairs of adapters were used:
# a) Illumina overhang adapter sequence (For_i5 and Rev_i7) on the 1st round of amplifications, and
# b) iNEXT barcodes (For_A-H - Rev_1-12) on the 2nd round.
# For more details on this approach, please refer to [Faircloth & Glenn, 2012 - PLoS One](http://journals.plos.org/plosone/article?id=10.1371/journal.pone.0042543).
## Debarcoding with QIIME1 tools
# Please refer to http://qiime.org/install/install.html for instructions on how to install QIIME1
# Activating qiime1 environment:
$ source activate qiime1
# Creating a project parent directory for the whole analysis:
$ mkdir projectX
# Entering this directory:
$ cd projectX/
# Creating a directory where there will be all your raw fastq files:
$ mkdir raw_data
# Entering this directory:
$ cd raw_data/
# Running the following command in order to extract barcodes:
$ for i in `ls *fastq.gz | sed 's/R[12].*/R/g' | uniq`; do extract_barcodes.py -c barcode_paired_end -f `echo "$i""1_001.fastq.gz"` -r `echo "$i""2_001.fastq.gz"` --bc1_len 8 --bc2_len 8 -o `echo $i | sed 's/_.*/\-barcodes/g'`; done
# NOTE: Please adjust both --bc1_len and --bc2_len parameters according to your barcodes' length (in this example, we are using a length of 8 nucleotides for both barcodes)
# Compressing and renaming debarcoded files in order to use them as input for qiime2 "demux" command below
$ for i in `ls -d *barcodes`; do gzip $i/*fastq; mv $i/reads1.fastq.gz $i/forward.fastq.gz; mv $i/reads2.fastq.gz $i/reverse.fastq.gz; done
# Going back to the parent projectX directory:
$ cd ../
# Deactivating qiime1 environment:
$ source deactivate

## Demultiplexing with QIIME2 tools and an ad-hoc PERL script 
# Please refer to  https://docs.qiime2.org/2018.6/install for instructions on how to install QIIME2
# Activating qiime2 environment:
$ source activate qiime2-2018.6
# Preparing map files that will associate specific barcodes' combination to their respective samples:
$ perl prepBCmapFiles4Qiime2.pl iNext-barcodes.tab samples-map.tab 
# NOTES:
# 1) "prepBCmapFiles4Qiime2.pl" PERL script can be obtained [here](https://github.com/eltonjrv/microbiome.westernu/blob/bin/prepBCmapFiles4Qiime2.pl)
# 2) See/Download [iNext-barcodes.tab](https://github.com/eltonjrv/microbiome.westernu/blob/accFiles/iNext-barcodes.tab) and [samples-map.tab](https://github.com/eltonjrv/microbiome.westernu/blob/accFiles/samples-map.tab) as guiding examples, if you have adopted/encountered a demultiplexing situation like ours.
# Creating a new directory to store all output files generated by the command above (barcodes_*tab):
$ mkdir BCmapFiles
# Moving barcodes_*tab files to that new directory:
$ mv barcodes_*tab BCmapFiles/
# Importing qiime1-debarcoded fastq files as qiime2 .qza format:
$ for i in `ls -d raw_data/*-barcodes`; do qiime tools import --type EMPPairedEndSequences --input-path $i --output-path `echo $i | sed 's/.*\///g' | sed 's/\-barcodes/\-input4demux/g'`; done
# Running the actual demultiplexing task with "qiime demux" from qiime2:
$ for i in `ls BCmapFiles/`; do Mbase=`echo $i | sed 's/barcodes_[0-9]*\-//g' | sed 's/\.tab//g'`; qiime demux emp-paired --m-barcodes-file BCmapFiles/$i --m-barcodes-category BarcodeSequence --i-seqs `echo $Mbase`-input4demux.qza --o-per-sample-sequences `echo $i | sed 's/barcodes_//g' | sed 's/\.tab//g'`-demuxOUT.qza; done
# Summarizing the demultiplexed qza files as qzv ones in order to be visualized at https://view.qiime2.org/:
$ for i in `ls *OUT.qza`; do qiime demux summarize --i-data $i --o-visualization `echo $i | sed 's/qza$/qzv/g'`; done
# Deactivating qiime2 environment:
$ source deactivate
