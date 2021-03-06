#!/usr/bin/bash
# Programmer: Elton Vasconcelos, DVM, PhD
# March, 2017
### This is a pilot pipeline using both ad-hoc PERL scripts (placed in the "bin" branch) and QIIME tools (http://qiime.org/scripts/index.html)
### If you use this whole tool or part of it, please cite this github page acknowledging the author (Vasconcelos, EJ) as well as QIIME suite developers.

### One must have QIIME installed and run the following command before starting the pipeline
source activate qiime1

### Quality control (trimming) and demultiplexing
bash qiimePipe-demultiplexing.bsh

### Catching our samples and relabelling each sequence (adding Diniz's study labels)
for i in `ls *fna`; do perl catching_samples_after_demultiplexing-QIIMEpipe.pl $i metaSampleID-studyLabel-barCodes-prep.tab >`echo $i | sed 's/\.fna/\-DinizLabels.fasta/g'`; done

### Screening for chimeras using usearch aligner and SILVA type strains 16S db as reference
for i in `ls *Labels.fasta`; do identify_chimeric_seqs.py -i $i -r ../../16S-DBs/ARB-SILVA/SSURef_NR99_128_SILVA_07_09_16_opt-typeStrains-UbyT.fasta -m usearch61 --non_chimeras_retention intersection -o `echo $i | sed 's/\-.*//g'`-chimScreenOUT; done
for i in `ls -d *chimScreenOUT`; do  perl /home/elton/bioinformatics-tools/perl-scripts/seqs1.pl -outfmt fasta -incl $i/non_chimeras.txt -seq `echo $i | sed 's/\-chimScreenOUT//g'`-demultiplexed-DinizLabels.fasta  >`echo $i | sed 's/\-chimScreenOUT//g'`-demultiplexed-DinizLabels-nonChim.fasta; done

### Preparing a summary of the sequences content in each sample after all the tiltering steps performed above
wc -l *joined/fastqjoin.join.fastq | sed -r 's/^ +//g' | sed 's/ /\t/g' | awk '{ print $2 "\t" $1 / 4 }' >numSeqs-joined.txt
grep -c '>' *fastaqual/fastqjoin.join.fna | sed 's/\:/\t/g' >numSeqs-fastaqual.txt 
grep -c '>' *F_splitOUT/seqs.fna | sed 's/\:/\t/g' >numSeqs-iNextF-demultiplexed.txt 
grep -c '>' *R_splitOUT/seqs.fna | sed 's/\:/\t/g' >numSeqs-iNextR-demultiplexed.txt 
grep -c '>' *Labels.fasta | sed 's/\:/\t/g' >numSeqs-DinizLabels.txt
wc -l *chimScreenOUT/non_chimeras.txt | head -26 | sed -r 's/^ +//g' | sed 's/ /\t/g' | awk '{ print $2 "\t" $1 }' >numSeqs-non_chimeras.txt
paste numSeqs-joined.txt numSeqs-fastaqual.txt numSeqs-iNextF-demultiplexed.txt numSeqs-iNextR-demultiplexed.txt numSeqs-DinizLabels.txt numSeqs-non_chimeras.txt >qiimePipe-Summary.tsv 

### Picking OTUs
cat *nonChim.fasta >seqs.fna
pick_de_novo_otus.py -i seqs.fna -o dnOTUs -p parameters.txt

### Plotting taxonomic classification charts
make_otu_heatmap.py -i otu_table.biom -t rep_set.tre -m ../newSampleIDs.tab -o heatmap_plot-genusLevel.pdf --obs_md_level 6
summarize_taxa_through_plots.py -i otu_table.biom -m ../newSampleIDs.tab -p parameter.txt -f -o summaryPlots

### Statistical metrics
# within each sample
alpha_diversity.py -i otu_table.biom -o aDiv-metrics.tsv -m observed_otus,observed_species,chao1,shannon,simpson,goods_coverage
alpha_rarefaction.py -i otu_table.biom -t rep_set.tre -m ../newSampleIDs.tab -o aRarefaction
# among samples
#beta_diversity.py -i otu_table.biom -t rep_set.tre -o bDiv -m bray_curtis,weighted_unifrac #does not generate PCoA plots
beta_diversity_through_plots.py -i otu_table.biom -t rep_set.tre -m ../newSampleIDs.tab -p ../parameters.txt --color_by_all_fields -o bDivPlots
### ATTENTION below
# After removing both column and row of the negative control (NoFlea-M5) on the weighted_unifrac_dm-woNoFlea.txt, and commenting that sample line in the mapFile, the following command will compare SouthCA and NorthCA fleas (regarding their OTUs' content) using ADONIS (an adapted permonova statistical analysis)
compare_categories.py --method adonis -i weighted_unifrac_dm-woNoFlea.txt -m newSampleIDs-woNoFlea.tab -c Description -o adonis_out-woNoFlea -n 999


