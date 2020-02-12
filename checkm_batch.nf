#!/usr/bin/env nextflow
// Copyright (C) 2018 Sur Herrera Paredes

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

// Nextflow pipeline that runs a directory of genomes through checkm.
// Combines results in single table

// Parameters:
// --indir
// --outdir
// Name of output directory
// --contamination, --completeness
// Thresholds for checkM statistics
// --batch_size
// Number of genomes to analyze by batch
// --threads, --memory, --time, --queue, --max_forks
// Parameters for checkm jobs.

// Configuration and dependencies:
// The processes here might require access to python 3, checkm, and R.
// Use the labeles 'py3', 'checkm', and 'r' in your nextflow.config
// file to provide access. See the end of this pipeline for an example file.

// Params
params.indir = 'genomes/'
params.outdir = 'output/'
params.contamination = 2
params.completeness = 98

params.batch_size = 200
params.threads = 8
params.memory = '40GB'
params.time = '2:00:00'
params.queue = 'owners,hbfraser,hns'
params.max_forks = 200


// Process params
indir = file(params.indir)
GZGENOMES = Channel.fromPath("$indir/**.fna.gz")
// GENOMES.subscribe{println it}

process gunzip{
  stageInMode 'copy'

  input:
  file gzgenomes from GZGENOMES.collate(params.batch_size)

  output:
  file "genomes/" into FNAGENOMES

  """
  mkdir genomes/
  mv $gzgenomes genomes/
  gzip -d genomes/*
  """

}

FNAGENOMES.subscribe{println it}

process run_checkm{
  label 'checkm'
  cpus params.threads
  memory params.memory
  time params.time
  maxForks params.max_forks

  queue params.queue

  input:
  file genomes_dir from FNAGENOMES

  output:
  file "checkm_results.txt" into CHECKMTABS

  """
  checkm lineage_wf \
    -t ${params.threads} \
    -f checkm_results.txt \
    --tab_table \
    $genomes_dir \
    results
  """
}


process collect_results{
  label 'py3'
  memory '1GB'
  time '00:30:00'
  publishDir params.outdir

  input:
  file checkm_tabs from CHECKMTABS.collect()

  output:
  file "full_checkm_results.txt" into CHECKM

  """
  ${workflow.projectDir}/cat_tables.py \
    $checkm_tabs \
    --outfile full_checkm_results.txt
  """
}
//
// process filter_checkm{
//   label 'r'
//   cpus 1
//   memory '2GB'
//   time '00:30:00'
//   queue params.queue
//   publishDir params.outdir, pattern: "output/all_completeness_histogram.svg",
//     saveAs: {"checkm/all_completeness_histogram.svg"}
//   publishDir params.outdir, pattern: "output/all_contamination_histogram.svg",
//     saveAs: {"checkm/all_contamination_histogram.svg"}
//   publishDir params.outdir, pattern: "output/all_heterogeneity_histogram.svg",
//     saveAs: {"checkm/all_heterogeneity_histogram.svg"}
//   publishDir params.outdir,
//     pattern: "output/all_completeness_vs_contamination.svg",
//     saveAs: {"checkm/all_completeness_vs_contamination.svg"}
//   publishDir params.outdir,
//     pattern: "output/chosen_completeness_histogram.svg",
//     saveAs: {"checkm/chosen_completeness_histogram.svg"}
//   publishDir params.outdir,
//     pattern: "output/chosen_contamination_histogram.svg",
//     saveAs: {"checkm/chosen_contamination_histogram.svg"}
//   publishDir params.outdir,
//     pattern: "output/chosen_heterogeneity_histogram.svg",
//     saveAs: {"checkm/chosen_heterogeneity_histogram.svg"}
//   publishDir params.outdir,
//     pattern: "output/chosen_completeness_vs_contamination.svg",
//     saveAs: {"checkm/chosen_completeness_vs_contamination.svg"}
//   publishDir params.outdir, pattern: "output/chosen_checkm_results.txt",
//   saveAs: {"checkm/chosen_checkm_results.txt"}
//
//   input:
//   file "checkm_results.txt" from CHECKM
//
//   output:
//   file "output/all_completeness_histogram.svg"
//   file "output/all_contamination_histogram.svg"
//   file "output/all_heterogeneity_histogram.svg"
//   file "output/all_completeness_vs_contamination.svg"
//   file "output/chosen_completeness_histogram.svg"
//   file "output/chosen_contamination_histogram.svg"
//   file "output/chosen_heterogeneity_histogram.svg"
//   file "output/chosen_completeness_vs_contamination.svg"
//   file "output/chosen_checkm_results.txt" into CHOSEN
//
//   """
//   ${workflow.projectDir}/process_checkm_results.r \
//     checkm_results.txt \
//     --contamination ${params.contamination} \
//     --completeness ${params.completeness}
//   """
// }
//
// process clean_genome_dirs{
//   label 'py3'
//   cpus 1
//   memory '2GB'
//   // If copying, need to increase time
//   time '00:45:00'
//   queue params.queue
//   publishDir params.outdir,
//     pattern: "clean",
//     saveAs: {"clean"}
//
//   input:
//   file indir
//   file 'checkm_results.txt' from CHOSEN
//
//   output:
//   file 'clean'
//
//   """
//   grep -v "# genomes" checkm_results.txt | cut -f 1 > keep.txt
//
//   ${workflow.projectDir}/clean_genome_dirs.py ${params.indir} \
//     --outdir clean/ \
//     --keep keep.txt
//   """
// }


// Example nextflow.config
/*
process {
  errorStrategy = 'finish'
  queue = 'hbfraser,hns'
  maxFors = 300
  stageInMode = 'rellink'
  withLabel: py3 {
    module = 'fraserconda'
  }
  withLabel: checkm {
    module = 'prodigal:hmmer:pplacer:anaconda'
    conda = '/opt/modules/pkgs/anaconda/3.6/envs/python2'
  }
  withLabel: r {
    module = 'R/3.5.1server'
  }
}
executor{
  name = 'slurm'
  queueSize = 500
  submitRateLitmit = '1 sec'
}
*/
