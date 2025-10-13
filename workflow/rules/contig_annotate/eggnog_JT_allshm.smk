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
    """
    Annotate eggnog hits table per chunk (EGGNOG) entirely in /dev/shm for speed,
    with usage counter to ensure DB is only deleted once all jobs are finished.
    """
    input:
        seed=CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.seed_orthologs"
    output:
        CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.annotations"
    log:
        CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.annotations.log"
    params:
        fa = features["databases"]["eggnog"],
        out = lambda wc: f"prodigal.chunk.{wc.i}",
    threads: config["resources"]["cpu_per_task"]["multi_thread"]
    container:
        docker["annotate"]
    shell: """
        DATA_DIR="/dev/shm/eggnog_data_holorumin"
        WORK_DIR="/dev/shm/eggnog_work_{wildcards.assembly_id}_{wildcards.i}"
        LOCK_FILE="$DATA_DIR/.lock"
        DONE_FILE="$DATA_DIR/.done"
        COUNTER_FILE="$DATA_DIR/.counter"

        mkdir -p $DATA_DIR
        mkdir -p $WORK_DIR

        # === Increment counter safely ===
        (
            flock -x 200
            COUNT=0
            if [ -f "$COUNTER_FILE" ]; then
                COUNT=$(cat "$COUNTER_FILE")
            fi
            COUNT=$((COUNT + 1))
            echo $COUNT > "$COUNTER_FILE"
            echo "Incremented counter: $COUNT jobs using DB" >> {log}
        ) 200>"$COUNTER_FILE.lock"

        # === Copy DB if not already done ===
        if [ ! -f "$DONE_FILE" ]; then
            if mkdir "$LOCK_FILE" 2>/dev/null; then
                echo "This job has the lock, copying DB..." >> {log}
                cp -r {params.fa}/* $DATA_DIR/ >> {log} 2>&1
                touch "$DONE_FILE"
                rmdir "$LOCK_FILE"
            else
                echo "Another job is copying the DB, waiting..." >> {log}
                while [ ! -f "$DONE_FILE" ]; do
                    sleep 30
                done
            fi
        fi
        cp {input.seed} $WORK_DIR/

        emapper.py --data_dir $DATA_DIR \
                --annotate_hits_table $WORK_DIR/$(basename {input.seed}) \
                --no_file_comments \
                -o {params.out} \
                --output_dir $WORK_DIR \
                --override \
                --cpu {threads} >> {log} 2>&1

        # === Move result back to disk ===
        mkdir -p $(dirname {output})
        mv $WORK_DIR/{params.out}.emapper.annotations {output}

        # === Cleanup WORK_DIR ===
        rm -rf $WORK_DIR

        # === Decrement counter and cleanup if last job ===
        (
            flock -x 200
            COUNT=$(cat "$COUNTER_FILE")
            COUNT=$((COUNT - 1))
            if [ $COUNT -le 0 ]; then
                echo 0 > "$COUNTER_FILE"
                echo "No more jobs using DB, cleaning $DATA_DIR" >> {log}
                rm -rf "$DATA_DIR"
                rm -f "$DONE_FILE"
            else
                echo $COUNT > "$COUNTER_FILE"
                echo "Remaining jobs using DB: $COUNT" >> {log}
            fi
        ) 200>"$COUNTER_FILE.lock"
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
