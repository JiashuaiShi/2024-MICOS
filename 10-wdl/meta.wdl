version development

workflow combined_kraken_workflow {
    input {
        Array[File] input_files_r1
        Array[File] input_files_r2
        Directory kraken2_db
        Int threads
        Float confidence
        Int min_base_quality
        Int min_hit_groups
        Array[String] output_tsv_names
        Array[String] report_txt_names
        String biom_output_filename
        Array[String] krona_output_html_names
        File qiime2_metagenome_biom
        File qiime2_merged_taxonomy_tsv
        File qiime2_sample_metadata
        Int qiime2_min_frequency = 10
        Int qiime2_min_samples = 2
        Int qiime2_sampling_depth = 10
        File taxonomy_convert_script
    }

    scatter (i in range(length(input_files_r1))) {
        call Kraken2Task {
            input:
                input_file_r1 = input_files_r1[i],
                input_file_r2 = input_files_r2[i],
                kraken2_db = kraken2_db,
                threads = threads,
                confidence = confidence,
                min_base_quality = min_base_quality,
                min_hit_groups = min_hit_groups,
                output_tsv_name = output_tsv_names[i],
                report_txt_name = report_txt_names[i]
        }
    }

    call MergeTSVTask {
        input:
            input_files = Kraken2Task.output_tsv_file
    }

    call kraken_biom {
        input:
            input_files = Kraken2Task.report_txt_file,
            output_filename = biom_output_filename
    }

    scatter (idx in range(length(Kraken2Task.report_txt_file))) {
        call krona {
            input:
                input_file = Kraken2Task.report_txt_file[idx],
                output_filename = krona_output_html_names[idx]
        }
    }

    call ImportFeatureTable {
        input:
            input_biom = qiime2_metagenome_biom
    }

    call ConvertKraken2Tsv {
        input:
            qiime2_merged_taxonomy_tsv = qiime2_merged_taxonomy_tsv,
            taxonomy_convert_script = taxonomy_convert_script
    }

    call ImportTaxonomy {
        input:
            input_tsv = ConvertKraken2Tsv.merge_converted_taxonomy
    }

    call FilterLowAbundanceFeatures {
        input:
            input_table = ImportFeatureTable.output_qza,
            qiime2_min_frequency = qiime2_min_frequency
    }

    call FilterRareFeatures {
        input:
            input_table = FilterLowAbundanceFeatures.filtered_table,
            qiime2_min_samples = qiime2_min_samples
    }

    call RarefyTable {
        input:
            input_table = FilterRareFeatures.filtered_table,
            qiime2_sampling_depth = qiime2_sampling_depth
    }

    call CalculateAlphaDiversity {
        input:
            input_table = RarefyTable.rarefied_table
    }

    call ExportAlphaDiversity {
        input:
            input_qza = CalculateAlphaDiversity.alpha_diversity
    }

    call CalculateBetaDiversity {
        input:
            input_table = RarefyTable.rarefied_table
    }

    call PerformPCoA {
        input:
            distance_matrix = CalculateBetaDiversity.distance_matrix
    }

    call AddPseudocount {
        input:
            input_table = RarefyTable.rarefied_table
    }

    output {
        File merged_tsv = MergeTSVTask.merged_tsv
        Array[File] kraken2_report_txt = Kraken2Task.report_txt_file
        File output_biom = kraken_biom.output_biom
        Array[File] krona_html_reports = krona.output_html
        File filtered_table = FilterRareFeatures.filtered_table
        File rarefied_table = RarefyTable.rarefied_table
        File distance_matrix = CalculateBetaDiversity.distance_matrix
        File pcoa = PerformPCoA.pcoa
        File comp_table = AddPseudocount.comp_table
        File shannon_diversity = ExportAlphaDiversity.exported_diversity
    }
}

task Kraken2Task {
    input {
        File input_file_r1
        File input_file_r2
        Directory kraken2_db
        Int threads
        Float confidence
        Int min_base_quality
        Int min_hit_groups
        String output_tsv_name
        String report_txt_name
    }

    command {
        kraken2 --db ${kraken2_db} \
                --threads ${threads} \
                --confidence ${confidence} \
                --minimum-base-quality ${min_base_quality} \
                --minimum-hit-groups ${min_hit_groups} \
                --output ${output_tsv_name} \
                --report ${report_txt_name} \
                --paired ${input_file_r1} ${input_file_r2} \
                --use-names --memory-mapping
    }

    output {
        File output_tsv_file = output_tsv_name
        File report_txt_file = report_txt_name
    }

    runtime {
        docker: "shuai/kraken2:2.1.3"
    }
}

task MergeTSVTask {
    input {
        Array[File] input_files
    }

    command {
        cat ${sep=" " input_files} | awk '!seen[$0]++' > merged_taxonomy.tsv
    }

    output {
        File merged_tsv = "merged_taxonomy.tsv"
    }

    runtime {
        docker: "ubuntu:latest"
        cpu: 1
        memory: "1 GB"
    }
}

task kraken_biom {
    input {
        Array[File] input_files
        String output_filename
    }

    command {
        kraken-biom ${sep=" " input_files} --fmt hdf5 -o ${output_filename}
    }

    runtime {
        docker: "shuai/kraken-biom:1.0.0"
        memory: "4 GB"
        cpu: 1
    }

    output {
        File output_biom = "${output_filename}"
    }
}

task krona {
    input {
        File input_file
        String output_filename
    }

    command {
        ktImportTaxonomy \
        -o ${output_filename} \
        ${input_file}
    }

    runtime {
        docker: "shuai/krona:2.8.1"
        cpu: 1
        memory: "4 GB"
    }

    output {
        File output_html = "${output_filename}"
    }
}

task ConvertKraken2Tsv {
    input {
        File qiime2_merged_taxonomy_tsv
        File taxonomy_convert_script
    }

    command {
        python3 ${taxonomy_convert_script} ${qiime2_merged_taxonomy_tsv} merge_converted_taxonomy.tsv
    }

    output {
        File merge_converted_taxonomy = "merge_converted_taxonomy.tsv"
    }

    runtime {
        docker: "amancevice/pandas:1.1.5"
    }
}

task ImportFeatureTable {
    input {
        File input_biom
    }

    command {
        qiime tools import \
            --type 'FeatureTable[Frequency]' \
            --input-path ${input_biom} \
            --output-path feature-table.qza
    }

    output {
        File output_qza = "feature-table.qza"
    }

    runtime {
        docker: "quay.io/qiime2/core:2022.2"
    }
}

task ImportTaxonomy {
    input {
        File input_tsv
    }

    command {
        qiime tools import \
            --type 'FeatureData[Taxonomy]' \
            --input-format HeaderlessTSVTaxonomyFormat \
            --input-path ${input_tsv} \
            --output-path taxonomy.qza
    }

    output {
        File output_qza = "taxonomy.qza"
    }

    runtime {
        docker: "quay.io/qiime2/core:2022.2"
    }
}

task FilterLowAbundanceFeatures {
    input {
        File input_table
        Int qiime2_min_frequency
    }

    command {
        qiime feature-table filter-features \
            --i-table ${input_table} \
            --p-min-frequency ${qiime2_min_frequency} \
            --o-filtered-table filtered-table.qza
    }

    output {
        File filtered_table = "filtered-table.qza"
    }

    runtime {
        docker: "quay.io/qiime2/core:2022.2"
    }
}

task FilterRareFeatures {
    input {
        File input_table
        Int qiime2_min_samples
    }

    command {
        qiime feature-table filter-features \
            --i-table ${input_table} \
            --p-min-samples ${qiime2_min_samples} \
            --o-filtered-table filtered-table.qza
    }

    output {
        File filtered_table = "filtered-table.qza"
    }

    runtime {
        docker: "quay.io/qiime2/core:2022.2"
    }
}

task RarefyTable {
    input {
        File input_table
        Int qiime2_sampling_depth
    }

    command {
        qiime feature-table rarefy \
            --i-table ${input_table} \
            --p-sampling-depth ${qiime2_sampling_depth} \
            --o-rarefied-table rarefied-table.qza
    }

    output {
        File rarefied_table = "rarefied-table.qza"
    }

    runtime {
        docker: "quay.io/qiime2/core:2022.2"
    }
}

task CalculateAlphaDiversity {
    input {
        File input_table
    }

    command {
        qiime diversity alpha \
            --i-table ${input_table} \
            --p-metric shannon \
            --o-alpha-diversity alpha-diversity.qza
    }

    output {
        File alpha_diversity = "alpha-diversity.qza"
    }

    runtime {
        docker: "quay.io/qiime2/core:2022.2"
    }
}

task ExportAlphaDiversity {
    input {
        File input_qza
    }

    command {
        qiime tools export \
            --input-path ${input_qza} \
            --output-path exported-diversity
    }

    output {
        File exported_diversity = "exported-diversity/alpha-diversity.tsv"
    }

    runtime {
        docker: "quay.io/qiime2/core:2022.2"
    }
}

task CalculateBetaDiversity {
    input {
        File input_table
    }

    command {
        qiime diversity beta \
            --i-table ${input_table} \
            --p-metric braycurtis \
            --o-distance-matrix distance-matrix.qza
    }

    output {
        File distance_matrix = "distance-matrix.qza"
    }

    runtime {
        docker: "quay.io/qiime2/core:2022.2"
    }
}

task PerformPCoA {
    input {
        File distance_matrix
    }

    command {
        qiime diversity pcoa \
            --i-distance-matrix ${distance_matrix} \
            --o-pcoa pcoa.qza
    }

    output {
        File pcoa = "pcoa.qza"
    }

    runtime {
        docker: "quay.io/qiime2/core:2022.2"
    }
}

task AddPseudocount {
    input {
        File input_table
    }

    command {
        qiime composition add-pseudocount \
            --i-table ${input_table} \
            --o-composition-table comp-table.qza
    }

    output {
        File comp_table = "comp-table.qza"
    }

    runtime {
        docker: "quay.io/qiime2/core:2022.2"
    }
}