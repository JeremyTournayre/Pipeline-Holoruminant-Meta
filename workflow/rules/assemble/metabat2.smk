rule _assemble__metabat2__run:
    """Run metabat2 end-to-end on a single assembly"""
    input:
        bams=get_bams_from_assembly_id,
        bais=get_bais_from_assembly_id,
        assembly=lambda wildcards: (
            MEGAHIT / f"{wildcards.assembly_id}.fa.gz" if config["assembler"] == "megahit" else
            METASPADES / f"{wildcards.assembly_id}.fa.gz"
        ),
    output:
        bins=directory(METABAT2 / "{assembly_id}"),
    log:
        METABAT2 / "{assembly_id}.log",
    conda:
        "__environment__.yml"
    container:
        docker["assemble"]
    params:
        bins_prefix=lambda w: METABAT2 / f"{w.assembly_id}/bin",
        bams=compose_bams_for_metabat2_run,
        depth=lambda w: METABAT2 / f"{w.assembly_id}.depth",
        paired=lambda w: METABAT2 / f"{w.assembly_id}.paired",
        workdir=METABAT2,
        minLen=params["assemble"]["metabat"]["min_contig_len"],
    threads: config["resources"]["cpu_per_task"]["multi_thread"]
    resources:
        cpu_per_task=config["resources"]["cpu_per_task"]["multi_thread"],
        mem_per_cpu=config["resources"]["mem_per_cpu"]["highmem"] // config["resources"]["cpu_per_task"]["multi_thread"],
        time =  config["resources"]["time"]["longrun"],
    shell:
        """

        for bam in {input.bams} ; do
            dest_bam={params.workdir}/$(basename $bam)
            ln -s $(realpath $bam) $dest_bam
        done 2>> {log} 1>&2
            
        jgi_summarize_bam_contig_depths \
            --outputDepth {params.depth} \
            --pairedContigs {params.paired} \
            {params.bams} \
        2>> {log} 1>&2

        metabat2 \
            --inFile {input.assembly} \
            --abdFile {params.depth} \
            --outFile {params.bins_prefix} \
            --numThreads {threads} \
            --minContig {params.minLen} \
            --verbose \
        2> {log} 1>&2

        rm \
            --force \
            --verbose \
            {params.bams} \
            {params.depth} \
            {params.paired} \
        2>> {log} 1>&2

        fa_files=$(find {output.bins} -name "*.fa")
        for fa in $fa_files; do
            pigz --best --verbose "$fa"
        done 2>> {log} 1>&2
        """


rule assemble__metabat2:
    """Run metabat2 over all assemblies"""
    input:
        [METABAT2 / assembly_id for assembly_id in ASSEMBLIES],
