rule _assemble__concoct:
    input:
        assembly=lambda wildcards: (
            MEGAHIT / f"{wildcards.assembly_id}.fa.gz" if config["assembler"] == "megahit" else
            METASPADES / f"{wildcards.assembly_id}.fa.gz"
        ),
        bams=get_bams_from_assembly_id,
    output:
        directory(CONCOCT / "{assembly_id}"),
    log:
        CONCOCT / "{assembly_id}.log",
    conda:
        "concoct.yml"
    container:
        docker["concoct"]
    threads: config["resources"]["cpu_per_task"]["multi_thread"]
    resources:
        cpu_per_task=config["resources"]["cpu_per_task"]["multi_thread"],
        mem_per_cpu=config["resources"]["mem_per_cpu"]["highmem"] // config["resources"]["cpu_per_task"]["multi_thread"],
        time =  config["resources"]["time"]["longrun"],
    params:
        workdir=lambda w: CONCOCT / w.assembly_id,
    shell:
        """
        mkdir --parents --verbose {params.workdir} 2> {log} 1>&2

        cut_up_fasta.py \
            <(gzip --decompress --stdout {input.assembly}) \
            --chunk_size 10000 \
            --overlap_size 0 \
            --merge_last \
            --bedfile {params.workdir}/cut.bed \
        > {params.workdir}/cut.fa \
        2>> {log}

        for bam in {input.bams} ; do
            dest_bam={params.workdir}/$(basename $bam)
            ln -s $(realpath $bam) $dest_bam
            samtools index $dest_bam
        done 2>> {log} 1>&2

        concoct_coverage_table.py \
            {params.workdir}/cut.bed \
            {params.workdir}/*.bam \
        > {params.workdir}/coverage.tsv \
        2>> {log}

        concoct \
            --threads {threads} \
            --composition_file {params.workdir}/cut.fa \
            --coverage_file {params.workdir}/coverage.tsv \
            --basename {params.workdir}/run \
        2>> {log} 1>&2

        merge_cutup_clustering.py \
            {params.workdir}/run_clustering_gt1000.csv \
        > {params.workdir}/merge.csv \
        2>> {log}

        extract_fasta_bins.py \
            <(gzip --decompress --stdout {input.assembly}) \
            {params.workdir}/merge.csv \
            --output_path {params.workdir} \
        2>> {log} 1>&2

        rm \
            --force \
            --verbose \
            {params.workdir}/cut.fa \
            {params.workdir}/cut.bed \
            {params.workdir}/coverage.tsv \
            {params.workdir}/*.csv \
            {params.workdir}/*.bam \
            {params.workdir}/*.bai \
            {params.workdir}/*.txt \
        2>> {log} 1>&2

        pigz \
            --best \
            --verbose \
            {params.workdir}/*.fa \
        2>> {log} 1>&2
        """


rule assemble__concoct:
    """Run concoct on all assemblies"""
    input:
        [CONCOCT / f"{assembly_id}" for assembly_id in ASSEMBLIES],
