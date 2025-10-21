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
    container:
        docker["r_report"]
    params:
       script=PREPROCESS_R,
       features=config["features-file"],
       project=WD,
       pipeline_report=PIPELINE_REPORT
    threads: esc("cpus", "report__preprocess")
    resources:
        runtime=esc("runtime", "report__preprocess"),
        mem_mb=esc("mem_mb", "report__preprocess"),
        cpus_per_task=esc("cpus", "report__preprocess"),
        partition=esc("partition", "report__preprocess"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'report__preprocess')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("report__preprocess"))
    shell:"""
       cp {params.script} {params.pipeline_report}/report_preprocess_copy.Rmd
       R -e "setwd('{params.project}'); \
             working_dir <- '{params.project}'; \
             features_file <- '{params.features}'; \
             project_folder <- '{params.project}' ; \
             snakemake <- TRUE ; \
             rmarkdown::render('{params.pipeline_report}/report_preprocess_copy.Rmd',output_file=file.path('{params.project}','{output}'))" &> {log}             
    """
