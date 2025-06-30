rule report__preprocess:
    """
    Create the pipeline report for the preproces module (R).
    """
    input:
        rules.preprocess.input,
    output:
        html=PIPELINE_REPORT / "preprocess.html",
    log:
        PIPELINE_REPORT / "preprocess.log",
    benchmark:
        PIPELINE_REPORT / "preprocess_benchmark.tsv",
    conda:
        "__environment__.yml"
    container:
        docker["r_report"]
    params:
       script=PREPROCESS_R,
       features=config["features-file"],
       project=WD,
       pipeline_report=PIPELINE_REPORT
    threads: config["resources"]["cpu_per_task"]["single_thread"]
    resources:
        cpu_per_task=config["resources"]["cpu_per_task"]["single_thread"],
        mem_per_cpu=config["resources"]["mem_per_cpu"]["highmem"],
        time=config["resources"]["time"]["longrun"],
    shell:"""
       cp {params.script} {params.pipeline_report}/report_preprocess_copy.Rmd
       R -e "setwd('{params.project}'); \
             working_dir <- '{params.project}'; \
             features_file <- '{params.features}'; \
             project_folder <- '{params.project}' ; \
             snakemake <- TRUE ; \
             rmarkdown::render('{params.pipeline_report}/report_preprocess_copy.Rmd',output_file=file.path('{params.project}','{output}'))" &> {log}
    """