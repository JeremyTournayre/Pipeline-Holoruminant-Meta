rule annotate__eggnog:
    """Run eggnog over the dereplicated mags"""
    input:
        contigs=DREP / "dereplicated_genomes.fa.gz",
    output:
        directory(EGGNOG) ,
    log:
        protected(EGGNOG / "eggnog.log"),
    container:
        docker["eggnog"]
    params:
        out_dir=EGGNOG,
        db=features["databases"]["eggnog"],
        prefix="eggnog"
    threads: config["resources"]["cpu_per_task"]["multi_thread"]
    resources:
        cpu_per_task=config["resources"]["cpu_per_task"]["multi_thread"],
        mem_per_cpu=config["resources"]["mem_per_cpu"]["highmem"]//config["resources"]["cpu_per_task"]["multi_thread"],
        time =  config["resources"]["time"]["longrun"],
        nvme = config["resources"]["nvme"]["verylarge"]
    shell:
        """
        if [ ! -s {input.contigs} ]; then
            echo "[INFO] DREP dereplicated_genomes file '{input.contigs}' is empty or missing. Skipping emapper." >> {log}
            mkdir -p {params.out_dir}
            touch  {params.out_dir}/{params.prefix}
            exit 0
        fi
        emapper.py -m diamond \
                   --data_dir {params.db} \
                   --itype metagenome \
                   --genepred prodigal \
                   --dbmem \
                   --no_annot \
                   --no_file_comments \
                   --cpu {threads} \
                   -i {input.contigs} \
                   --output_dir {params.out_dir} \
                   -o {params.prefix}  \
                   2>> {log} 1>&2;
        """
