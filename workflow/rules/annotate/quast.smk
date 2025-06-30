rule annotate__quast:
    """Run quast over one the dereplicated mags"""
    input:
        DREP / "dereplicated_genomes.fa.gz",
    output:
        directory(QUAST),
    log:
        QUAST / "quast.log",
    conda:
        "__environment__.yml"
    container:
        docker["annotate"]
    threads: config["resources"]["cpu_per_task"]["multi_thread"]
    resources:
        cpu_per_task=config["resources"]["cpu_per_task"]["multi_thread"],
        mem_per_cpu=config["resources"]["mem_per_cpu"]["highmem"] // config["resources"]["cpu_per_task"]["multi_thread"],
        time =  config["resources"]["time"]["longrun"],
    shell:
        """
        if [ ! -s {input} ]; then
            mkdir -p {output}
            echo "[INFO] DREP dereplicated_genomes file '{input}' is empty or missing. Skipping quast." >> {log}
            exit 0
        fi
        quast \
            --output-dir {output} \
            --threads {threads} \
            {input} \
        2> {log} 1>&2
        """
