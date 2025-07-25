rule annotate__bakta:
    """Run Bakta over the dereplicated mags"""
    input:
        contigs=DREP / "dereplicated_genomes.fa.gz",
    output:
        tsv=BAKTA / "bakta.tsv",
        faa=BAKTA / "bakta.faa",
    log:
        BAKTA / "bakta.log",
    container:
        docker["annotate"]
    params:
        out_dir=BAKTA,
        db=features["databases"]["bakta"],
        options=params["annotate"]["bakta"]["additional_options"],
        tmpdir=config["tmp_storage"]
    threads: config["resources"]["cpu_per_task"]["multi_thread"]
    resources:
        cpu_per_task=config["resources"]["cpu_per_task"]["multi_thread"],
        mem_per_cpu=config["resources"]["mem_per_cpu"]["highmem"]//config["resources"]["cpu_per_task"]["multi_thread"],
        time =  config["resources"]["time"]["verylongrun"],
        nvme = config["resources"]["nvme"]["small"],
        partition = config["resources"]["partition"]["longrun"]
    shell:
        """
        if [ ! -s {input.contigs} ]; then
            mkdir -p {params.out_dir}
            echo "[INFO] DREP dereplicated_genomes file '{input.contigs}' is empty or missing. Skipping bakta." >> {log}
            touch {output.tsv}
            touch {output.faa}
            exit 0
        fi
        bakta --db {params.db} \
              --force \
              --verbose \
              --output {params.out_dir} \
              --prefix bakta \
              --threads {threads} \
              {params.options} \
              {input.contigs} \
              > {log} 2>&1
        """

rule annotate__bakta_mags_run:
    """Run Bakta over the dereplicated mags"""
    input:
        contigs=MAGSCOT / "{assembly_id}.fa.gz",
    output:
        tsv=BAKTAMAG / "bakta_{assembly_id}.tsv",
        faa=BAKTAMAG / "bakta_{assembly_id}.faa",
    log:
        BAKTAMAG / "bakta_{assembly_id}.log",
    container:
        docker["annotate"]
    params:
        out_dir=BAKTAMAG,
        db=features["databases"]["bakta"],
        options=params["annotate"]["bakta"]["additional_options"],
        tmpdir=config["tmp_storage"]
    threads: config["resources"]["cpu_per_task"]["multi_thread"]
    resources:
        cpu_per_task=config["resources"]["cpu_per_task"]["multi_thread"],
        mem_per_cpu=config["resources"]["mem_per_cpu"]["highmem"]//config["resources"]["cpu_per_task"]["multi_thread"],
        time =  config["resources"]["time"]["longrun"],
        nvme = config["resources"]["nvme"]["small"],
        partition = config["resources"]["partition"]["small"]
    shell:
        """
        if [ ! -s {input.contigs} ]; then
            echo "[INFO] contigs file '{input.contigs}' is empty or missing. Skipping bakta." >> {log}
            touch {output.tsv}
            touch {output.faa}
            exit 0
        fi
        bakta --db {params.db} \
              --force \
              --verbose \
              --output {params.out_dir} \
              --prefix bakta_{wildcards.assembly_id} \
              --threads {threads} \
              {params.options} \
              {input.contigs} \
              > {log} 2>&1
        """

rule annotate__bakta_mags:
    """Run Bakta over the dereplicated mags"""
     input:
        expand(BAKTAMAG / "bakta_{assembly_id}.faa", assembly_id=ASSEMBLIES),

