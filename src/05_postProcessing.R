path = "/icgc/dkfzlsdf/analysis/B080/sharma/boulantLab/T84_IL22_IFNL/"

# Load count data generated by feature counts
dat = readRDS(paste0(path, "/data/counts/T84_IL22_INFL_counts.RDS"))

# Annotation
f = list.files(paste0(path, "data/bam/"), pattern = ".bam", )
f = grep(".bam.summary", f, invert = T, value = T)
f = grep(".bam.indel.vcf", f, invert = T, value = T)

anno = gsub("_R1_001.bam", "", f)
anno = gsub("IL-22", "IL22", anno)
anno = gsub("IFN-L", "IFNL", anno)
anno = gsub("22L", "IL22_IFNL", anno)
anno = data.frame(ID = f, do.call("rbind", strsplit(anno, "-", fixed=T)))
colnames(anno) = c("ID", "Treatment", "Time", "Replicate")
anno$Replicate = sapply(strsplit(anno$Replicate, "_"), function(x) x[1])

# Making ID match the column names from the count matrix above
anno$ID = gsub("-", ".", anno$ID)
anno$ID = gsub("_", ".", anno$ID)

# Renaming replicate IDs to make them consistent across all samples
anno$Replicate[anno$Treatment == "Mock" & anno$Time == "6h"] = c("1", "2", "3")
anno$Replicate[anno$Treatment == "Mock" & anno$Time == "12h"] = c("1", "2", "3")
anno$Replicate = paste0("Rep-", anno$Replicate)

anno$Treatment = factor(anno$Treatment, levels = c("Mock", "IL22", "IFNL", "IL22_IFNL"))
anno$Time = factor(anno$Time, levels = c("3h", "6h", "12h", "24h"))
anno$Replicate = factor(anno$Replicate, levels = c("Rep-1", "Rep-2", "Rep-3"))

# Rename samples for clarity
if(identical(colnames(dat$counts), anno$ID)){
  colnames(dat$counts) = paste(anno$Treatment,anno$Time, anno$Replicate, sep="-")
  anno$SampleID = paste(anno$Treatment,anno$Time, anno$Replicate, sep="-")
  anno$Condition = paste(anno$Treatment,anno$Time, sep="-")
  anno = anno[,c("SampleID", "Treatment", "Time", "Replicate", "Condition")]
}

# Save Feature Counts summary with matching column names for MultiQC
stats = dat$stat
tmp = strsplit(colnames(stats), ".", fixed = T)
tmp = sapply(tmp, function(x){
  
  if(is.element("22L", x) | is.element("Mock", x)){
    a = paste(x[1:3], collapse = "-")
    b = paste(x[4:6], collapse= "_")
    x = paste0(a,"_",b,".", x[7])
    rm(a,b)
  }
  
  if(is.element("IFN", x) | is.element("IL", x)){
    a = paste(x[1:4], collapse = "-")
    b = paste(x[5:7], collapse= "_")
    x = paste0(a,"_",b,".", x[8])
    rm(a,b)
  }
  
  return(x)
})

colnames(stats) = tmp
write.table(stats, file = paste0(path, "/data/counts/T84-IL22-INFL_counts.summary"), quote=F, row.names = F, sep="\t")
rm(tmp)

# Restrict to non-duplicated protein coding genes only
pcg = dat$annotation[dat$annotation$gene_biotype == "protein_coding",]
cnt = dat$counts[pcg$GeneID,]

# Restrict to genes whose row sum > 0
cnt = cnt[rowSums(cnt) > 0,]
pcg = pcg[pcg$GeneID %in% rownames(cnt),]

# Removig duplicated hgnc gene names
sum(duplicated(pcg$gene_name))
#[1] 3
pcg = pcg[!duplicated(pcg$gene_name),]
cnt = dat$counts[pcg$GeneID,]

# Sanity check
if(identical(rownames(cnt), pcg$GeneID)){
  rownames(cnt) = pcg$gene_name
}

# Saving results for downstream analysis using DEseq2
saveRDS(list(counts = cnt, geneanno = pcg, sampanno = anno),
        paste0(path, "data/counts/T84_IL22_INFL_filtered_counts.RDS"))

write.csv(data.frame(Gene = rownames(cnt), cnt, stringsAsFactors = F),
          paste0(path, "data/counts/T84_IL22_INFL_filtered_counts.csv"), 
          quote = FALSE, row.names = F)
