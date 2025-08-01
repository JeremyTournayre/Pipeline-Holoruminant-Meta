rule report__step__reads:
    """Collect all reports for the reads step"""
    input:
        rules.reads__fastqc.input,
    output:
        html=REPORT_STEP / "reads.html",
    log:
        REPORT_STEP / "reads.log",
    conda:
        "__environment__.yml"
    container:
        docker["report"]
    params:
        dir=REPORT_STEP,
    resources:
        mem_mb=8 * 1024,
        attempt=get_attempt,
    shell:
        """
        multiqc \
            --filename reads \
            --title reads \
            --force \
            --outdir {params.dir} \
            {input} \
        2> {log} 1>&2
        """


rule report__step__preprocess:
    """Collect all reports for the preprocessing step"""
    input:
        rules.preprocess__fastp.input.json,
        rules.preprocess__fastqc.input,
        rules.preprocess__samtools.input,
        rules.preprocess__kraken2.input,
    output:
        html=REPORT_STEP / "preprocess.html",
    log:
        REPORT_STEP / "preprocess.log",
    conda:
        "__environment__.yml"
    container:
        docker["report"]
    params:
        dir=REPORT_STEP,
    resources:
        mem_mb=double_ram(4),
        runtime=6 * 60,
        attempt=get_attempt,
    retries: 5
    shell:
        """
        multiqc \
            --title preprocess \
            --force \
            --filename preprocess \
            --outdir {params.dir} \
            --dirs \
            --dirs-depth 1 \
            {input} \
        2> {log}.{resources.attempt} 1>&2

        mv {log}.{resources.attempt} {log}
        """


rule report__step__assemble:
    """Collect all reports from the assemble step"""
    input:
        QUAST,
    output:
        REPORT_STEP / "assemble.html",
    log:
        REPORT_STEP / "assemble.log",
    conda:
        "__environment__.yml"
    container:
        docker["report"]
    params:
        dir=REPORT_STEP,
    resources:
        mem_mb=8 * 1024,
    shell:
        """
        # Recherche de fichiers non vides mais sans ligne avec un message d'erreur connu
        valid_files=$(grep -L "empty or missing" $(find {input} -type f -size +0 2>/dev/null) 2>/dev/null)

        if [ -z "$valid_files" ]; then
            echo "[INFO] Aucun fichier MultiQC valide trouvé dans '{input}'." >> {log}
            mkdir -p {params.dir}
            touch {output}
            exit 0
        fi
   
        multiqc \
            --title assemble \
            --force \
            --filename assemble \
            --outdir {params.dir} \
            {input} \
        2> {log} 1>&2
        """


rule report__step__quantify:
    """Collect all reports from the quantify step"""
    input:
        rules.quantify__samtools.input,
    output:
        REPORT_STEP / "quantify.html",
    log:
        REPORT_STEP / "quantify.log",
    conda:
        "__environment__.yml"
    container:
        docker["report"]
    params:
        dir=REPORT_STEP,
    resources:
        mem_mb=8 * 1024,
    shell:
        r"""
        # Récupère les fichiers non vides sans ligne commençant par [INFO]
        valid_files=$(find results/quantify/bowtie2 -type f -size +0 | xargs -r grep -L '^\[INFO\]' 2>/dev/null)

        if [ -z "$valid_files" ]; then
            echo "[INFO] Aucun fichier MultiQC valide trouvé dans 'results/quantify/bowtie2'." >> {log}
            mkdir -p {params.dir}
            touch {output}
            exit 0
        fi

        multiqc \
            --title quantify \
            --force \
            --filename quantify \
            --outdir {params.dir} \
            {input} \
        2> {log} 1>&2
        """


rule report__step:
    """Report for all steps"""
    input:
        REPORT_STEP / "reads.html",
        REPORT_STEP / "preprocess.html",
        REPORT_STEP / "assemble.html",
        REPORT_STEP / "quantify.html",
