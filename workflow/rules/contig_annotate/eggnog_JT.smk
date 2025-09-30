from glob import glob
from os.path import join

rule contig_annotate__eggnog_find_homology:
    """
    Find homolog genes in data (EGGNOG).
    """
    input:
        folder = CONTIG_PRODIGAL / "{assembly_id}/Chunks/",
        files = CONTIG_PRODIGAL / "{assembly_id}/Chunks/prodigal.chunk.{i}"
    output:
        file=CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.seed_orthologs"
    log:
        CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.log"
    params:
        folder = lambda wildcards: CONTIG_EGGNOG / f"{wildcards.assembly_id}/Chunks/",
        tmp=config["nvme_storage"],
        out="prodigal.chunk.{i}",
        fa=features["databases"]["eggnog"]
    threads: config["resources"]["cpu_per_task"]["multi_thread"]
    resources:
        cpu_per_task=config["resources"]["cpu_per_task"]["multi_thread"],
        mem_per_cpu=config["resources"]["mem_per_cpu"]["highmem"] // config["resources"]["cpu_per_task"]["multi_thread"],
        time =  config["resources"]["time"]["longrun"],
        nvme = config["resources"]["nvme"]["large"]
    container:
        docker["annotate"]
    shell:""" 
        DATA_DIR="{params.tmp}"

        if [ -z "$DATA_DIR" ]; then
            DATA_DIR="{params.fa}"
        else
            cp {params.fa}/eggnog* {params.tmp} &> {log};
        fi;

         emapper.py -m diamond --override --data_dir $DATA_DIR --no_annot --no_file_comments --cpu {threads} -i {input.files} --output_dir {params.folder} -o {params.out}  2>> {log} 1>&2;
    """
    

rule contig_annotate__eggnog_orthology_chunk:
    input:
        seed=CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.seed_orthologs"
    output:
        CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.annotations"
    log:
        CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.annotations.log"
    params:
        fa = features["databases"]["eggnog"],
        out = lambda wc: f"prodigal.chunk.{wc.i}",
        outdir = lambda wc: CONTIG_EGGNOG / f"{wc.assembly_id}/Chunks"
    threads: config["resources"]["cpu_per_task"]["multi_thread"]
    container:
        docker["annotate"]
    shell: """
        DATA_DIR="/dev/shm/eggnog_data_holorumin"
        mkdir -p $DATA_DIR

        # Lock mechanism pour copier la DB dans /dev/shm une seule fois
        LOCK_FILE="$DATA_DIR/.lock"
        DONE_FILE="$DATA_DIR/.done"
        MAX_WAIT=1800  
        WAIT_TIME=0

        until [ -f "$DONE_FILE" ]; do
            if mkdir "$LOCK_FILE" 2>/dev/null; then
                echo "This job has the lock, copying DB..." &>> {log}
                cp -r {params.fa}/* $DATA_DIR/ &>> {log}
                touch "$DONE_FILE"
                rmdir "$LOCK_FILE"
            else
                echo "Another job is copying the DB, waiting..." &>> {log}
                sleep 30
                WAIT_TIME=$((WAIT_TIME + 30))
                if [ $WAIT_TIME -ge $MAX_WAIT ]; then
                    echo "Lock timeout reached, taking over the copy..." &>> {log}
                    rm -rf "$DATA_DIR"/*
                    rmdir "$LOCK_FILE" 2>/dev/null
                    WAIT_TIME=0
                fi
            fi
        done

        mkdir -p {params.outdir}
        emapper.py --data_dir $DATA_DIR \
                   --annotate_hits_table {input.seed} \
                   --no_file_comments \
                   -o {params.out} \
                   --output_dir {params.outdir} \
                   --override \
                   --cpu {threads} &>> {log}
    """

rule contig_annotate__eggnog_merge_annotations:
    input:
        contig_annotate_aggregate_annotations_eggnog_search,
    output:
        CONTIG_EGGNOG / "{assembly_id}/eggnog_output.emapper.annotations"
    log:
        CONTIG_EGGNOG / "{assembly_id}/eggnog_output.emapper.annotations.log"
    shell:"""
       cat {input} > {output} 2> {log}
    """

rule contig_annotate__eggnog:
    """Run eggnog on all assemblies"""
    input:
        [CONTIG_EGGNOG / "{assembly_id}/eggnog_output.emapper.annotations" for assembly_id in ASSEMBLIES],
