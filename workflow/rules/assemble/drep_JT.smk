rule _assemble__drep__separate_bins:
    input:
        assemblies=[MAGSCOT / f"{assembly_id}.fa.gz" for assembly_id in ASSEMBLIES],
    output:
        out_dir=directory(DREP / "separated_bins"),
    log:
        DREP / "separate_bins.log",
    conda:
        "__environment__.yml"
    container:
        docker["assemble"]
    resources:
        mem_per_cpu=config["resources"]["mem_per_cpu"]["highmem"],
        time =  config["resources"]["time"]["shortrun"],
    shell:
        """
        mkdir --parents {output.out_dir} 2> {log} 1>&2

       # Check if files exist and are not empty before processing
        for assembly in {input.assemblies}; do
            if [ -s "$assembly" ]; then
                # Process the assembly if it's not empty
                gzip --decompress --stdout "$assembly" \
        | paste - - \
        | tr -d ">" \
        | tr "@" "\t" \
                | awk '{{print ">" $1 "@" $2 "\\n" $3 > "{output.out_dir}/" $1 ".fa" }}' \
                >> {log} 2>&1
            else
                echo "Warning: File $assembly is empty or missing, skipping." >> {log}
            fi
        done
        """


rule _assemble__drep__run:
    """Dereplicate all the bins using dRep."""
    input:
        genomes=DREP / "separated_bins",
    output:
        dereplicated_genomes=directory(DREP / "dereplicated_genomes"),
        data=DREP / "data.tar.gz",
        data_tables=DREP / "data_tables.tar.gz",
    log:
        DREP / "drep.log",
    conda:
        "__environment__.yml"
    container:
        docker["assemble"]
    threads: config["resources"]["cpu_per_task"]["multi_thread"]
    resources:
        cpu_per_task=config["resources"]["cpu_per_task"]["multi_thread"],
        mem_per_cpu=config["resources"]["mem_per_cpu"]["highmem"] // config["resources"]["cpu_per_task"]["multi_thread"],
        time =  config["resources"]["time"]["longrun"],
        nvme = config["resources"]["nvme"]["small"],
        attempt=get_attempt,
    params:
        out_dir=DREP,
        completeness=params["assemble"]["drep"]["completeness"],
        contamination=params["assemble"]["drep"]["contamination"],
        P_ani=params["assemble"]["drep"]["P_ani"],
        S_ani=params["assemble"]["drep"]["S_ani"],
        nc=params["assemble"]["drep"]["nc"],
        extra=params["assemble"]["drep"]["extra"]
    shell:
        """
        if compgen -G "{input.genomes}/*.fa" > /dev/null; then
            rm \
                --recursive \
                --force \
                {params.out_dir}/data_tables \
                {params.out_dir}/data \
                {params.out_dir}/dereplicated_genomes \
                {params.out_dir}/figures \
                {params.out_dir}/log \
            2> {log}.{resources.attempt} 1>&2

            echo "This is the current TMPDIR: " 2>> {log}.{resources.attempt} 1>&2
            echo $TMPDIR 2>> {log}.{resources.attempt} 1>&2
            
            dRep dereplicate \
                {params.out_dir} \
                --processors {threads} \
                --completeness {params.completeness} \
                --contamination {params.contamination} \
                --P_ani {params.P_ani} \
                --S_ani {params.S_ani} \
                -nc {params.nc} \
                {params.extra} \
                --genomes {input.genomes}/*.fa \
            2>> {log}.{resources.attempt} 1>&2

            for folder in data data_tables ; do
                tar \
                    --create \
                    --directory {params.out_dir} \
                    --file {params.out_dir}/${{folder}}.tar.gz \
                    --remove-files \
                    --use-compress-program="pigz --processes {threads}" \
                    --verbose \
                    ${{folder}} \
                2>> {log} 1>&2
            done

            files=$(find {output.dereplicated_genomes} -type f ! -name "*.gz")
            for file in $files; do
                gzip "$file"
            done
        else
            echo "No .fa files in {input.genomes}, skipping dRep" >> {log}
            mkdir -p {output.dereplicated_genomes}
            touch {output.data}
            touch {output.data_tables}
        fi
        mv {log}.{resources.attempt} {log}
        """


rule _assemble__drep__join_genomes:
    """Join all the dereplicated genomes into a single file."""
    input:
        DREP / "dereplicated_genomes",
    output:
        DREP / "dereplicated_genomes.fa.gz",
    log:
        DREP / "dereplicated_genomes.log",
    conda:
        "__environment__.yml"
    container:
        docker["assemble"]
    threads: config["resources"]["cpu_per_task"]["multi_thread"]
    resources:
        cpu_per_task=config["resources"]["cpu_per_task"]["multi_thread"],
        mem_per_cpu=config["resources"]["mem_per_cpu"]["highmem"] // config["resources"]["cpu_per_task"]["multi_thread"],
        time =  config["resources"]["time"]["shortrun"],
        nvme = config["resources"]["nvme"]["small"]
    shell:
        """
        if compgen -G "{input}/*.fa.gz" > /dev/null; then
            ( zcat {input}/*.fa.gz \
              | bgzip --compress-level 9 --threads {threads} \
              > {output} ) 2> {log}
        else
            echo "No .fa.gz files found, creating empty output file." > {log}
            touch {output}
        fi
        """


rule assemble__drep:
    input:
        DREP / "dereplicated_genomes.fa.gz",
