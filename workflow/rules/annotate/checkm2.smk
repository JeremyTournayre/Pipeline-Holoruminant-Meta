rule annotate__checkm2__predict:
    """Run CheckM2 over the dereplicated mags"""
    input:
        mags=DREP / "dereplicated_genomes",
        db=features["databases"]["checkm2"],
    output:
        CHECKM / "quality_report.tsv",
    log:
        CHECKM / "quality_report.log",
    conda:
        "checkm2.yml"
    container:
        docker["checkm2"]
    params:
        out_dir=CHECKM / "predict",
    threads: config["resources"]["cpu_per_task"]["multi_thread"]
    resources:
        cpu_per_task=config["resources"]["cpu_per_task"]["multi_thread"],
        mem_per_cpu=config["resources"]["mem_per_cpu"]["highmem"]//config["resources"]["cpu_per_task"]["multi_thread"],
        time =  config["resources"]["time"]["longrun"],
        nvme = config["resources"]["nvme"]["large"],
    shell:
        """
        if compgen -G "{input.mags}/*.fa" > /dev/null; then
            rm -rfv {params.out_dir} 2> {log} 1>&2

            checkm2 predict \
                --threads {threads} \
                --input {input.mags} \
                --extension .fa.gz \
                --output-directory {params.out_dir} \
                --database_path {input.db} \
                --remove_intermediates \
            2>> {log} 1>&2

            mv {params.out_dir}/quality_report.tsv {output} 2>> {log} 1>&2
            rm --recursive --verbose --force {params.out_dir} 2>> {log} 1>&2
        else
            mkdir -p {params.out_dir}
            echo "[INFO] DREP dereplicated_genomes file '{input.mags}' is empty or missing. Skipping checkm2." >> {log}
            touch {output}
            exit 0
        fi
        """


rule annotate__checkm2:
    """Run CheckM2"""
    input:
        rules.annotate__checkm2__predict.output,
