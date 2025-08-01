rule annotate__phylophlan:
    """
    Run phylophlan for the dereplicated genomes
    """
    input:
        DREP / "dereplicated_genomes",
    output:
        dir=directory(PHYLOPHLAN / "SGB"),
        result= PHYLOPHLAN / "SGB" / "SGB.tsv",
    log:
        PHYLOPHLAN / "phylophlan_sgb.log",
    benchmark:
        PHYLOPHLAN / "benchmark/phylophlan_sgb.tsv",
    threads: config["resources"]["cpu_per_task"]["multi_thread"]
    resources:
        cpu_per_task=config["resources"]["cpu_per_task"]["multi_thread"],
        mem_per_cpu=config["resources"]["mem_per_cpu"]["highmem"] // config["resources"]["cpu_per_task"]["multi_thread"],
        time=config["resources"]["time"]["longrun"],
        nvme=config["resources"]["nvme"]["large"]
    conda:
        "__environment__.yml"
    container:
        docker["annotate"]
    shell:
        """
            echo Running Phylophlan on $(hostname) 2>> {log} 1>&2

            mkdir -p {output.dir}
            if compgen -G "{input}/*.fa" > /dev/null; then
    
                phylophlan_assign_sgbs -i {input} \
                                    -d SGB.Jun23 \
                                    --database_folder resources/databases/phylophlan/ \
                                    -e fa.gz \
                                    -o {output.dir} \
                                    --nproc {threads} \
                                    --verbose \
                                    --overwrite \
                                    2>> {log} 1>&2 \
                                    || true
            else
                echo "[INFO] DREP dereplicated_genomes file '{input}' is empty or missing. Skipping phylophlan_assign_sgbs." >> {log}
                touch  {output.result}
                exit 0
            fi
      """
        
# THIS RULE IS BUGGY AND NEEDS REFINEMENT TO BUILD THE PHYLOGENY
#
#rule _annotate__phylophlan_run:
#    """
#    Run phylophlan for the dereplicated genomes
#    """
#    input:
#        contigs=DREP / "dereplicated_genomes",
#        maas=GTDBTK / "gtdbtk.summary.tsv",
#        database=lambda w: features["databases"]["phylophlan"][w.phylophlan_db],
#    output:
#        out_folder=directory(PHYLOPHLAN / "{phylophlan_db}"),
#    log:
#        PHYLOPHLAN / "{phylophlan_db}.log",
#    benchmark:
#        PHYLOPHLAN / "benchmark/{phylophlan_db}.tsv",
#    threads: config["resources"]["cpu_per_task"]["multi_thread"]
#    resources:
#        cpu_per_task=config["resources"]["cpu_per_task"]["multi_thread"],
#        mem_per_cpu=config["resources"]["mem_per_cpu"]["highmem"] // config["resources"]["cpu_per_task"]["multi_thread"],
#        time=config["resources"]["time"]["longrun"],
#        nvme=config["resources"]["nvme"]["large"]
#    params:
#        diversity=params["annotate"]["phylophlan"]["diversity"],
#        config_folder=config["phylophlan-config"],
#        out_folder=lambda w: PHYLOPHLAN / w.phylophlan_db,
#    conda:
#        "__environment__.yml"
#    container:
#        docker["annotate"]
#    shell:
#        """
#            echo Running Phylophlan on $(hostname) 2>> {log} 1>&2
#
#            mkdir -p {params.out_folder}
#
#            phylophlan -i {input.contigs} \
#                       -d {input.database} \
#                       -f {params.config_folder} \
#                       --maas {input.maas} \
#                       --genome_extension fa \
#                       --diversity {params.diversity} \
#                       --nproc {threads} \
#                       --output_folder {params.out_folder} \
#                       --verbose \
#                       2>> {log} 1>&2
#        """
#
#rule _annotate__phylophlan:
#    """Run phylophlan over all databases."""
#    input:
#        [
#            PHYLOPHLAN / phylophlan_db 
#            for phylophlan_db in features["databases"]["phylophlan"]
#        ],
