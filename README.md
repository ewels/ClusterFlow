# <img src="docs/assets/Cluster_Flow_logo.png" width="400" title="Cluster Flow">

### A user-friendly bioinformatics workflow tool

---

# Cluster Flow is now archived

_This project is no longer under active maintenance. You're welcome to use it, but no updates or bug fixes will be posted. We recommend using [Nextflow](https://nextflow.io/) together with [nf-core](https://nf-co.re/) instead._

_Many thanks to everyone who used and supported Cluster Flow over the years._

---


[![Build Status](https://img.shields.io/travis/ewels/clusterflow.svg?style=flat-square)](https://travis-ci.org/ewels/clusterflow)
[![Gitter](https://img.shields.io/badge/gitter-%20join%20chat%20%E2%86%92-4fb99a.svg?style=flat-square)](https://gitter.im/ewels/clusterflow)
[![DOI](https://img.shields.io/badge/DOI-10.12688%2Ff1000research.10335.2-lightgrey.svg?style=flat-square)](http://dx.doi.org/10.12688/f1000research.10335.2)

**Find Cluster Flow documentation with information and examples at
[https://ewels.github.io/clusterflow/](https://ewels.github.io/clusterflow/)**

---

Cluster Flow is a pipelining tool to automate and standardise
bioinformatics analyses on high-performance cluster environments.
It is designed to be easy to use, quick to set up and flexible to configure.

Cluster Flow is written in Perl and works by launching jobs to a cluster
(can also be run locally). Each job is a stand-alone Perl executable wrapper
around a bioinformatics tool of interest.

Modules collect extensive logging information and Cluster Flow e-mails
the user with a summary of the pipeline commands and exit codes upon completion.

## Installation
You can find stable versions to download on the
[releases page](https://github.com/ewels/clusterflow/releases).

You can get the development version of the code by cloning this repository:
```
git clone https://github.com/ewels/clusterflow.git
```

Once downloaded and extracted, create a `clusterflow.config` file in the
script directory, based on `clusterflow.config.example`.

Next, you need to add the main `cf` executable to your `PATH`. This can be done
as an environment module, with a symlink to `bin` or by adding to your `~/.bashrc`
file.

Finally, run the setup wizard (`cf --setup`) and genomes wizard (`cf --add_genome`) and
you're ready to go! See the [installation docs](docs/installation.md) for more
information.

## Usage
Pipelines are launched by naming a pipeline or module and the input files. A simple
example could look like this:
```bash
cf sra_trim *.fastq.gz
```

Most pipelines need reference genomes, and Cluster Flow has built in reference
genome management. Parameters can be passed to modify tool behaviour.

For example, to run the `fastq_bowtie` pipeline (FastQC, TrimGalore! and Bowtie)
with Human data, trimming the first 6bp of read 1, the command would be:

```bash
cf --genome GRCh37 --params "clip_r1=6" fastq_bowtie *.fastq.gz
```

Additional common Cluster Flow commands are as follows:
```bash
cf --genomes     # List available reference genomes
cf --pipelines   # List available pipelines
cf --modules     # List available modules
cf --qstat       # List running pipelines
cf --qdel [id]   # Cancel jobs for a running pipeline
```


## Supported Tools
Cluster Flow comes with modules and pipelines for the following tools:

| Read QC & pre-processing     | Aligners / quantifiers  | Post-alignment processing                               | Post-alignment QC                                                                                               |
| ---------------------------- | ----------------------- | ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| [FastQ Screen](fastqscreen)  | [Bismark](bismark)      | [bedtools](bedtools) (`bamToBed`, `intersectNeg`)       | [deepTools](deeptools) (`bamCoverage`, `bamFingerprint`)                                                        |
| [FastQC](fastqc)             | [Bowtie 1](bowtie1)     | [subread featureCounts](featurecounts)                  | [MultiQC](multiqc)                                                                                              |
| [TrimGalore!](trimgalore)    | [Bowtie 2](bowtie2)     | [HTSeq Count](htseq_count)                              | [phantompeaktools](phantompeaktools) (`runSpp`)                                                                 |
| [SRA Toolkit](sratoolkit)    | [BWA](bwa)              | [Picard](picard) (`MarkDuplicates`)                     | [Preseq](preseq)                                                                                                |
|                              | [HiCUP](hicup)          | [Samtools](samtools) (`bam2sam`, `dedup`, `sort_index`) | [RSeQC](rseqc) (`geneBody_coverage`, `inner_distance`, `junction_annotation`, `junction_saturation`, `read_GC`) |
|                              | [HISAT2](hisat2)        |                                                         |                                                                                                                 |
|                              | [Kallisto](kallisto)    |                                                         |                                                                                                                 |
|                              | [STAR](star)            |                                                         |                                                                                                                 |
|                              | [TopHat](tophat)        |                                                         |                                                                                                                 |

## Citation
Please consider citing Cluster Flow if you use it in your analysis.

> **Cluster Flow: A user-friendly bioinformatics workflow tool [version 2; referees: 3 approved].** <br/>
> Philip Ewels, Felix Krueger, Max Käller, Simon Andrews <br/>
> _F1000Research_ 2016, **5**:2824 <br/>
> doi: [10.12688/f1000research.10335.2](http://dx.doi.org/10.12688/f1000research.10335.2)

```
@article{Ewels2016,
author = {Ewels, Philip and Krueger, Felix and K{\"{a}}ller, Max and Andrews, Simon},
title = {Cluster Flow: A user-friendly bioinformatics workflow tool [version 2; referees: 3 approved].},
journal = {F1000Research},
volume = {5},
pages = {2824},
year = {2016},
doi = {10.12688/f1000research.10335.2},
URL = { + http://dx.doi.org/10.12688/f1000research.10335.2}
}
```

## Contributions & Support
Contributions and suggestions for new features are welcome, as are bug reports!
Please create a new [issue](https://github.com/ewels/clusterflow/issues).
Cluster Flow has extensive
[documentation](https://ewels.github.io/clusterflow/docs) describing how to write new modules
and pipelines.

There is a chat room for the package hosted on Gitter where you can discuss
things with the package author and other developers:
https://gitter.im/ewels/clusterflow

If in doubt, feel free to get in touch with the author directly:
[@ewels](https://github.com/ewels) (phil.ewels@scilifelab.se)

## Contributors
Project lead and main author: [@ewels](https://github.com/ewels)

Code contributions from:
[@s-andrews](https://github.com/s-andrews),
[@FelixKrueger](https://github.com/FelixKrueger),
[@stu2](https://github.com/stu2),
[@orzechoj](https://github.com/orzechoj)
[@darogan](https://github.com/darogan)
and others. Thanks for your support!

## License
Cluster Flow is released with a GPL v3 licence. Cluster Flow is free software: you can
redistribute it and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the License, or (at your
option) any later version. For more information, see the licence that comes bundled with
Cluster Flow.

[bedtools]:          http://bedtools.readthedocs.io/en/latest/
[bismark]:           http://www.bioinformatics.babraham.ac.uk/projects/bismark/
[bowtie1]:           http://bowtie-bio.sourceforge.net/index.shtml
[bowtie2]:           http://bowtie-bio.sourceforge.net/bowtie2/index.shtml
[bwa]:               http://bio-bwa.sourceforge.net/
[deeptools]:         https://deeptools.github.io/
[fastqscreen]:       http://www.bioinformatics.babraham.ac.uk/projects/fastq_screen/
[fastqc]:            http://www.bioinformatics.babraham.ac.uk/projects/fastqc/
[featurecounts]:     http://bioinf.wehi.edu.au/featureCounts/
[hicup]:             http://www.bioinformatics.babraham.ac.uk/projects/hicup/
[hisat2]:            http://ccb.jhu.edu/software/hisat2/index.shtml
[htseq_count]:       http://www-huber.embl.de/HTSeq/doc/count.html
[kallisto]:          https://pachterlab.github.io/kallisto/
[multiqc]:           http://multiqc.info
[phantompeaktools]:  https://code.google.com/archive/p/phantompeakqualtools/
[picard]:            https://broadinstitute.github.io/picard/
[preseq]:            http://smithlabresearch.org/software/preseq/
[rseqc]:             http://rseqc.sourceforge.net/
[samtools]:          http://www.htslib.org/
[sratoolkit]:        https://github.com/ncbi/sra-tools
[star]:              https://github.com/alexdobin/STAR
[tophat]:            http://ccb.jhu.edu/software/tophat/index.shtml
[trimgalore]:        http://www.bioinformatics.babraham.ac.uk/projects/trim_galore/

