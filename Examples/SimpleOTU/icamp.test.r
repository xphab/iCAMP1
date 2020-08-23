# version 2020.8.23
rm(list=ls())
t0=Sys.time() # to calculate time cost

# 1 # set folder paths and file names, please change according to the folder paths and file names in your computer.
# the folder saving the input files
wd="E:/Dropbox/ToolDevelop/package/iCAMP/LatestVersion/Example"

# the OTU table file (Tab delimited txt file)
com.file="otus.txt"

# the phylogenetic tree file
tree.file="tree.nwk"

# the treatment informaiton table
treat.file="treat2col.txt"

# the environmental varialbes
env.file="environment.txt"
# if you do not have env file or the env may not represent niche, skip step 7 and 8, but check the alternative way to determine binning setting, e.g. bin.size.limit.

# the folder to save the output. please change to a new folder even if you are just testing the example data.
save.wd="E:/Dropbox/ToolDevelop/package/iCAMP/LatestVersion/Example/TestOutputs20"
if(!dir.exists(save.wd)){dir.create(save.wd)}

# 2 # key parameter setting
prefix="Test"  # prefix of the output file names. usually use a project ID.
rand.time=100  # randomization time, 1000 is usually enough. For example test, you may set as 100 or less to save time.
nworker=4 # nworker is thread number for parallel computing, which depends on the CPU core number of your computer.
memory.G=50 # to set the memory size as you need (but should be less than the available space in your hard disk), so that calculation of large tree will not be limited by physical memory. unit is Gb.

# 3 # load R packages and data
library(iCAMP)
library(ape)
setwd(wd)
comm=t(read.table(com.file, header = TRUE, sep = "\t", row.names = 1,
                  as.is = TRUE, stringsAsFactors = FALSE, comment.char = "",
                  check.names = FALSE))
tree=read.tree(file = tree.file)
treat=read.table(treat.file, header = TRUE, sep = "\t", row.names = 1,
                 as.is = TRUE, stringsAsFactors = FALSE, comment.char = "",
                 check.names = FALSE)

env=read.table(env.file, header = TRUE, sep = "\t", row.names = 1,
                 as.is = TRUE, stringsAsFactors = FALSE, comment.char = "",
                 check.names = FALSE) # skip this if you do not have env.file

# 4 # match sample IDs in OTU table and treatment information table
sampid.check=match.name(rn.list=list(comm=comm,treat=treat,env=env))
# sampid.check=match.name(rn.list=list(comm=comm,treat=treat)) # if you do not have env.file
# for the example data, the output should be "All match very well".
# for your data files, if you have not matched their IDs, the unmatched samples will be removed.
treat=sampid.check$treat
comm=sampid.check$comm
comm=comm[,colSums(comm)>0,drop=FALSE] # if some unmatched samples were removed, some OTUs may become ghosts, then you may use this line to remove them if necessary.
env=sampid.check$env # skip this if you do not have env.file

# 5 # match OTU IDs in OTU table and tree file
spid.check=match.name(cn.list=list(comm=comm),tree.list=list(tree=tree))
# for the example data, the output should be "All match very well".
# for your data files, if you have not matched the IDs before, the unmatched OTUs will be removed.
comm=spid.check$comm
tree=spid.check$tree

# 6 # calculate pairwise phylogenetic distance matrix.
# since microbial community data usually has a large number of species (OTUs or ASVs), we use "big.matrix" in R package "bigmemory" to handle the large phylogenetic distance matrix. 
setwd(save.wd)
if(!file.exists("pd.desc")) 
{
  pd.big=iCAMP::pdist.big(tree = tree, wd=save.wd, nworker = nworker, memory.G = memory.G)
  # output files:
  # path.rda: a R object to list all the nodes and  edge lengthes from root to every tip. saved in R data format. an intermediate output when claculating phylogenetic distance matrix.
  # pd.bin: BIN file (backingfile) generated by function big.matrix in R package bigmemory. This is the big matrix storing pairwise phylogenetic distance values. By using this bigmemory format file, we will not need memory but hard disk when calling big matrix for calculation.
  # pd.desc: the DESC file (descriptorfile) to hold the backingfile (pd.bin) description.
  # pd.taxon.name.csv: comma delimited csv file storing the IDs of tree tips (OTUs), serving as the row/column names of the big phylogenetic distance matrix.
}else{
  # if you already calculated the phylogenetic distance matrix in a previous run
  pd.big=list()
  pd.big$tip.label=read.csv(paste0(save.wd,"/pd.taxon.name.csv"),row.names = 1,stringsAsFactors = FALSE)[,1]
  pd.big$pd.wd=save.wd
  pd.big$pd.file="pd.desc"
  pd.big$pd.name.file="pd.taxon.name.csv"
}

####################
# you may skip step 7-8, if the "alternative way" based on stochasticity is applicable, as mentioned in the method part of iCAMP paper (Ning et al 2020 Nature Communications).
# 7 # assess niche preference difference between species
# env is required for this step.
# since microbial community data usually has a large number of species (OTUs or ASVs), we use "big.matrix" in R package "bigmemory" to handle the large niche difference matrix. 
setwd(save.wd)
niche.dif=iCAMP::dniche(env = env,comm = comm,method = "niche.value",
                        nworker = nworker,out.dist=FALSE,bigmemo=TRUE,
                        nd.wd=save.wd)

# 8 # within-bin phylogenetic signal assessment.
# For real data, you may try several different settings of binning, and choose the one leading to the best within-bin phylogenetic signal.
# env is required for this step.
# 8.1 # try phylogenetic binning using current setttings.
ds = 0.2 # setting can be changed to explore the best choice
bin.size.limit = 5 # setting can be changed to explore the best choice. # here set as 5 just for the small example dataset. For real data, usually try 12 to 48.
phylobin=taxa.binphy.big(tree = tree, pd.desc = pd.big$pd.file,pd.spname = pd.big$tip.label,
                         pd.wd = pd.big$pd.wd, ds = ds, bin.size.limit = bin.size.limit,
                         nworker = nworker)
# 8.2 # test within-bin phylogenetic signal.
sp.bin=phylobin$sp.bin[,3,drop=FALSE]
sp.ra=colMeans(comm/rowSums(comm))
abcut=3 # you may remove some species, if they are too rare to perform reliable correlation test.
commc=comm[,colSums(comm)>=abcut,drop=FALSE]
dim(commc)
spname.use=colnames(commc)
binps=iCAMP::ps.bin(sp.bin = sp.bin,sp.ra = sp.ra,spname.use = spname.use,
                    pd.desc = pd.big$pd.file, pd.spname = pd.big$tip.label, pd.wd = pd.big$pd.wd,
                    nd.list = niche.dif$nd,nd.spname = niche.dif$names,ndbig.wd = niche.dif$nd.wd,
                    cor.method = "pearson",r.cut = 0.1, p.cut = 0.05, min.spn = 5)
if(file.exists(paste0(prefix,".PhyloSignalSummary.csv"))){appendy=TRUE;col.namesy=FALSE}else{appendy=FALSE;col.namesy=TRUE}
write.table(data.frame(ds=ds,n.min=bin.size.limit,binps$Index),file = paste0(prefix,".PhyloSignalSummary.csv"),
            append = appendy, quote=FALSE, sep=",", row.names = FALSE,col.names = col.namesy)
if(file.exists(paste0(prefix,".PhyloSignalDetail.csv"))){appendy2=TRUE;col.namesy2=FALSE}else{appendy2=FALSE;col.namesy2=TRUE}
write.table(data.frame(ds=ds,n.min=bin.size.limit,binID=rownames(binps$detail),binps$detail),file = paste0(prefix,".PhyloSignalDetail.csv"),
            append = appendy2, quote = FALSE, sep = ",", row.names = FALSE, col.names = col.namesy2)
# since this example small data is randomly generated, the correlation should be very weak.
# usually, you are looking for a binning setting lead to higher RAsig.abj (relative abundance of bins with significant phylogenetic signal) and relative high meanR (mean correlation coefficient across bins).
# see help document of the function "ps.bin" for the meaning of output.

####################
# 9 # iCAMP analysis
# 9.1 # without omitting small bins.
# commonly use # set sig.index as Confidence instead of SES.RC (betaNRI/NTI + RCbray)
bin.size.limit = 5 # For real data, usually use a proper number according to phylogenetic signal test or try some settings then choose the reasonable stochasticity level. our experience is 12, or 24, or 48. but for this example dataset which is too small, have to use 5.
sig.index="Confidence" # see other options in help document of icamp.big.
icres=iCAMP::icamp.big(comm=comm, pd.desc = pd.big$pd.file, pd.spname=pd.big$tip.label,
                       pd.wd = pd.big$pd.wd, rand = rand.time, tree=tree,
                       prefix = prefix, ds = 0.2, pd.cut = NA, sp.check = TRUE,
                       phylo.rand.scale = "within.bin", taxa.rand.scale = "across.all",
                       phylo.metric = "bMPD", sig.index=sig.index, bin.size.limit = bin.size.limit, 
                       nworker = nworker, memory.G = memory.G, rtree.save = FALSE, detail.save = TRUE, 
                       qp.save = FALSE, detail.null = FALSE, ignore.zero = TRUE, output.wd = save.wd, 
                       correct.special = TRUE, unit.sum = rowSums(comm), special.method = "depend",
                       ses.cut = 1.96, rc.cut = 0.95, conf.cut=0.975, omit.option = "no",meta.ab = NULL)
# there are quite a few parameters in this function, please check the help document of "icamp.big".
# output files:
# Test.iCAMP.detail.rda: the object "icres" saved in R data format. it is a list object. The first element bNRIiRCa is the result of relative importance of each assembly process in each pairwise comparison (each turnover). The second element "detail" including binning information (named taxabin), phylogenetic and taxonomic metrics results in each bin (named like bNRIi, RCa, etc.), relative abundance of each bin (bin.weight), relative importance of each process in each turnover between communities (processes), input settings (setting), and input community data matrix (comm). See help document of the function icamp.big for more details.

############################
# 9.2 to 9.4 are some optional special settings you may explore.
# 9.2 # explore different ways for null model significance test.
# 9.2.1 # set detail.null=TRUE, output all null values, to facilitate normality test and switch between different options
detail.null=TRUE
bin.size.limit = 5 
sig.index="SES.RC" # this is traditional way, with assumption that null values of phylogenetic metrics follow normal distribution. 
prefixb="TestB"

icres2=iCAMP::icamp.big(comm=comm, pd.desc = pd.big$pd.file, pd.spname=pd.big$tip.label,
                       pd.wd = pd.big$pd.wd, rand = rand.time, tree=tree,
                       prefix = prefixb, ds = 0.2, pd.cut = NA, sp.check = TRUE,
                       phylo.rand.scale = "within.bin", taxa.rand.scale = "across.all",
                       phylo.metric = "bMPD", sig.index=sig.index, bin.size.limit = bin.size.limit, 
                       nworker = nworker, memory.G = memory.G, rtree.save = FALSE, detail.save = TRUE, 
                       qp.save = FALSE, detail.null = detail.null, ignore.zero = TRUE, output.wd = save.wd, 
                       correct.special = TRUE, unit.sum = rowSums(comm), special.method = "depend",
                       ses.cut = 1.96, rc.cut = 0.95, conf.cut=0.975, omit.option = "no",meta.ab = NULL)
# 9.2.2 # normality test
nntest=iCAMP::null.norm(icamp.output=icres2, p.norm.cut=0.05, detail.out=FALSE)
# output shows non-normal distribution ratio in each bin, i.e. the proportion of turnovers which have null values significantly deviated from normal distribution.
# if some ratio values are very high, may need to change to use "Confidence" as sig.index.

# 9.2.3 # change sig.index to "Confidence".
icres3=iCAMP::change.sigindex(icamp.output = icres2, sig.index = "Confidence", detail.save = TRUE, detail.null = FALSE, conf.cut = 0.975)
head(icres3$CbMPDiCBraya)

# 9.2.4 # change sig.index to "RC" for both phylogenetic and taxonomic metrics.
icres4=iCAMP::change.sigindex(icamp.output = icres2, sig.index = "RC", detail.save = TRUE, detail.null = FALSE, rc.cut = 0.95)
head(icres4$RCbMPDiRCbraya)

# 9.2.5 # the function can also change the significance threshold.
icres5=iCAMP::change.sigindex(icamp.output = icres2, sig.index = "SES.RC", detail.save = TRUE, detail.null = FALSE, ses.cut = 1.64, rc.cut = 0.9)
head(icres5$bNRIiRCbraya)

# 9.3 # you may specify the relative abundance of each species in the regional pool, if it is not the same as the average relative abundance from the "comm" you input.
meta.ab=rep(1,ncol(comm)) # here i assume all the species actuall have the same relative abundance in the regional pool.
prefix2=paste0(prefix,".MetaCrct")
sig.index="Confidence" # see other options in help document of icamp.big.
icres.meta=iCAMP::icamp.big(comm=comm, pd.desc = pd.big$pd.file, pd.spname=pd.big$tip.label,
                       pd.wd = pd.big$pd.wd, rand = rand.time, tree=tree,
                       prefix = prefix2, ds = 0.2, pd.cut = NA, sp.check = TRUE,
                       phylo.rand.scale = "within.bin", taxa.rand.scale = "across.all",
                       phylo.metric = "bMPD", sig.index=sig.index, bin.size.limit = bin.size.limit, 
                       nworker = nworker, memory.G = memory.G, rtree.save = FALSE, detail.save = TRUE, 
                       qp.save = FALSE, detail.null = FALSE, ignore.zero = TRUE, output.wd = save.wd, 
                       correct.special = TRUE, unit.sum = rowSums(comm), special.method = "depend",
                       ses.cut = 1.96, rc.cut = 0.95, conf.cut=0.975, omit.option = "no",meta.ab=meta.ab)

# 9.4 # consider to omit small bins
# 9.4.1 # if you would like to omit small bins rather than merging them to nearest relatives, set omit.option as "test" to check what will be omitted.
omit.option = "test"
icres.omit=iCAMP::icamp.big(comm=comm, pd.desc = pd.big$pd.file, pd.spname=pd.big$tip.label,
                            pd.wd = pd.big$pd.wd, rand = rand.time, tree=tree,
                            prefix = prefix, ds = 0.2, pd.cut = NA, sp.check = TRUE,
                            phylo.rand.scale = "within.bin", taxa.rand.scale = "across.all",
                            phylo.metric = "bMPD", sig.index=sig.index, bin.size.limit = bin.size.limit, 
                            nworker = nworker, memory.G = memory.G, rtree.save = FALSE, detail.save = TRUE, 
                            qp.save = FALSE, detail.null=FALSE, ignore.zero = TRUE, output.wd = save.wd, 
                            correct.special = TRUE, unit.sum = rowSums(comm), special.method = "depend",
                            ses.cut = 1.96, rc.cut = 0.95, conf.cut=0.975, omit.option = omit.option)
# "test" will return a detailed table of omitted species.

# 9.4.2 # then set it as "omit" to omit the small bins.
omit.option = "omit"
icres.omit2=iCAMP::icamp.big(comm=comm, pd.desc = pd.big$pd.file, pd.spname=pd.big$tip.label,
                            pd.wd = pd.big$pd.wd, rand = rand.time, tree=tree,
                            prefix = prefix, ds = 0.2, pd.cut = NA, sp.check = TRUE,
                            phylo.rand.scale = "within.bin", taxa.rand.scale = "across.all",
                            phylo.metric = "bMPD", sig.index=sig.index, bin.size.limit = bin.size.limit, 
                            nworker = nworker, memory.G = memory.G, rtree.save = FALSE, detail.save = TRUE, 
                            qp.save = FALSE, detail.null=FALSE, ignore.zero = TRUE, output.wd = save.wd, 
                            correct.special = TRUE, unit.sum = rowSums(comm), special.method = "depend",
                            ses.cut = 1.96, rc.cut = 0.95, conf.cut=0.975, omit.option = omit.option)
# In this simple example, since all bins are small, "omit" should return an error. In real data, this will go ahead to do iCAMP analysis with the strict bins which are big enough (>bin.size.limit).
###############################


# 10 # iCAMP bin level statistics
icbin=icamp.bins(icamp.detail = icres$detail,treat = treat,
                 clas=NULL,silent=FALSE, boot = TRUE,
                 rand.time = rand.time,between.group = TRUE)
save(icbin,file = paste0(prefix,".iCAMP.Summary.rda")) # just to archive the result. rda file is automatically compressed, and easy to load into R.
write.csv(icbin$Pt,file = paste0(prefix,".ProcessImportance_EachGroup.csv"),row.names = FALSE)
write.csv(icbin$Ptk,file = paste0(prefix,".ProcessImportance_EachBin_EachGroup.csv"),row.names = FALSE)
write.csv(icbin$Ptuv,file = paste0(prefix,".ProcessImportance_EachTurnover.csv"),row.names = FALSE)
write.csv(icbin$BPtk,file = paste0(prefix,".BinContributeToProcess_EachGroup.csv"),row.names = FALSE)

# output files:
# Test.iCAMP.Summary.rda: the object "icbin" saved in R data format. see help document of the function icamp.bins for description of each element in the object.
# Test.ProcessImportance_EachGroup.csv: Relative importance of each process in governing the turnovers in a group of samples.
# Test.ProcessImportance_EachBin_EachGroup.csv: Relative importance of each process in governing the turnovers of each bin among a group of samples.
# Test.ProcessImportance_EachTurnover.csv: Relative importance of each process in governing the turnovers between each pair of communities (samples).
# Test.BinContributeToProcess_EachGroup.csv: Bin contribution to each process, measuring the contribution of each bin to the relative importance of each process in the assembly of a group of communities.

# 11 # Bootstrapping test
# please specify which column in the treatment information table.
i=1
treat.use=treat[,i,drop=FALSE]
icamp.result=icres$CbMPDiCBraya
icboot=iCAMP::icamp.boot(icamp.result = icamp.result,treat = treat.use,rand.time = rand.time,
                         compare = TRUE,silent = FALSE,between.group = TRUE,ST.estimation = TRUE)
save(icboot,file=paste0(prefix,".iCAMP.Boot.",colnames(treat)[i],".rda"))
write.csv(icboot$summary,file = paste0(prefix,".iCAMP.BootSummary.",colnames(treat)[i],".csv"),row.names = FALSE)
write.csv(icboot$compare,file = paste0(prefix,".iCAMP.Compare.",colnames(treat)[i],".csv"),row.names = FALSE)

# output files:
# Test.iCAMP.Boot.Management.rda: the object "icboot" saved in R data format. see help document of the function icamp.boot for description of each element in the object.
# Test.BootSummary.Management.csv: a table to summarize bootstrapping results. see help document of the function icamp.boot for description of the output element "summary".
# Test.Compare.Management.csv: a table to summarize comparison index, effect size, and significance between each two groups. see help document of the function icamp.boot for description of the output element "compare".

# 12 # Other approach: QPEN (quantifying community assembly processes based on entire-community null model analysis)
qpout=iCAMP::qpen(comm=comm,pd=pd.big$pd.file,pd.big.wd=pd.big$pd.wd,
                  pd.big.spname=pd.big$tip.label,ab.weight=TRUE,
                  rand.time=rand.time, nworker=nworker,project=prefix,
                  wd=save.wd, save.bNTIRC=TRUE)

# 13 # Other approach: Neutral taxa percentage
snmout=iCAMP::snm.comm(comm = comm, treat = treat, 
                       rand=rand.time, alpha=0.05)
write.csv(snmout$stats,file = paste0(prefix,".NeutralModel.Stats.csv"))
write.csv(snmout$ratio.summary,file = paste0(prefix,".NeutralModel.TypeRatio.csv"))

# 14 # Other approach: tNST and pNST (taxonomic and phylogenetic normalized stochasticity ratio)
# need to install package NST if not yet
if(!("NST" %in% installed.packages()[,"Package"])){install.packages("NST")}
library(NST)
i=1
treat.use=treat[,i,drop=FALSE]

# 14.1a # tNST
tnstout=NST::tNST(comm=comm, group=treat.use, dist.method="bray", 
                  abundance.weighted=TRUE, rand=rand.time,  
                  nworker=nworker, null.model="PF", output.rand = TRUE,
                  SES = TRUE, RC = TRUE)
write.csv(tnstout$index.grp,file = paste0(prefix,".tNST.summary.",colnames(treat)[i],".csv"))
write.csv(tnstout$index.pair.grp,file = paste0(prefix,".tNST.pairwise.",colnames(treat)[i],".csv"))

# 14.1b # bootstrapping test for tNST
tnst.bt=NST::nst.boot(nst.result=tnstout, group=treat.use,
                      rand=rand.time, nworker=nworker)
write.csv(tnst.bt$NST.summary,file = paste0(prefix,".tNST.bootstr.",colnames(treat)[i],".csv"))
write.csv(tnst.bt$NST.compare,file = paste0(prefix,".tNST.compare.",colnames(treat)[i],".csv"))

# 14.2a # pNST
pnstout=NST::pNST(comm=comm, pd.desc=pd.big$pd.file, pd.wd=pd.big$pd.wd, 
                  pd.spname=pd.big$tip.label, group=treat.use, abundance.weighted=TRUE,
                  rand=rand.time, phylo.shuffle=TRUE, nworker=nworker,
                  output.rand = TRUE, SES=FALSE, RC=FALSE)
write.csv(pnstout$index.grp,file = paste0(prefix,".pNST.summary.",colnames(treat)[i],".csv"))
write.csv(pnstout$index.pair.grp,file = paste0(prefix,".pNST.pairwise.",colnames(treat)[i],".csv"))

pnst.bt=NST::nst.boot(nst.result=pnstout, group=treat.use,
                      rand=rand.time, nworker=nworker)
write.csv(pnst.bt$NST.summary,file = paste0(prefix,".pNST.bootstr.",colnames(treat)[i],".csv"))
write.csv(pnst.bt$NST.compare,file = paste0(prefix,".pNST.compare.",colnames(treat)[i],".csv"))

(t=format(Sys.time()-t0)) # to calculate time cost

# End #