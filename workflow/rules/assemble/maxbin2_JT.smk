rule _assemble__maxbin2__run:
    """Run MaxBin2 over a single assembly"""
    input:
        assembly=lambda wildcards: (
            MEGAHIT / f"{wildcards.assembly_id}.fa.gz" if config["assembler"] == "megahit" else
            METASPADES / f"{wildcards.assembly_id}.fa.gz"
        ),
        crams=get_crams_from_assembly_id,
    output:
        workdir=directory(MAXBIN2 / "{assembly_id}"),
    log:
        MAXBIN2 / "{assembly_id}.log",
    conda:
        "__environment__.yml"
    container:
        docker["assemble"]
    threads: config["resources"]["cpu_per_task"]["multi_thread"]
    resources:
        cpu_per_task=config["resources"]["cpu_per_task"]["multi_thread"],
        mem_per_cpu=config["resources"]["mem_per_cpu"]["highmem"] // config["resources"]["cpu_per_task"]["multi_thread"],
        time =  config["resources"]["time"]["verylongrun"],
        partition = config["resources"]["partition"]["longrun"],
    params:
        seed=1,
        coverage=lambda w: MAXBIN2 / f"{w.assembly_id}/maxbin2.coverage",
        minLen=params["assemble"]["maxbin"]["min_contig_len"],
    shell:
        """
        mkdir --parents {output.workdir}

        ( samtools coverage {input.crams} \
        | awk '{{print $1"\\t"$5}}' \
        | grep -v '^#' \
        ) > {params.coverage} \
        2> {log}

        run_MaxBin.pl \
            -thread {threads} \
            -contig {input.assembly} \
            -out {output.workdir}/maxbin2 \
            -abund {params.coverage} \
            -min_contig_length {params.minLen} \
        2>> {log} 1>&2 || echo "MaxBin2 did not produce output, continuing."

        if ! ls {output.workdir}/maxbin2*.fasta >/dev/null 2>&1; then
            echo "MaxBin2 did not produce output, continuing." >> {log}
            touch {output.workdir}/.maxbin2.done
            exit 0
        fi

        rename \
            's/\\.fasta$/.fa/' \
            {output.workdir}/*.fasta \
        2>> {log}

        fa_files=$(find {output.workdir} -name "*.fa")
        for fa in $fa_files; do
            pigz --best --verbose "$fa"
        done 2>> {log} 1>&2

        rm \
            --recursive \
            --force \
            {output.workdir}/maxbin.{{coverage,log,marker,noclass,summary,tooshort}} \
            {output.workdir}/maxbin2.marker_of_each_bin.tar.gz \
        2>> {log} 1>&2
        """


rule assemble__maxbin2:
    """Run MaxBin2 over all assemblies"""
    input:
        [MAXBIN2 / assembly_id for assembly_id in ASSEMBLIES],
