# bash script to take pipeline output and construct files for browser as well as comprehensive/basic gene sets
set -e
version=v5
work_dir=/hive/users/ifiddes/ihategit/pipeline/mouse_work_${version}
output_dir=/hive/users/ifiddes/ihategit/pipeline/mouse_output_${version}
cgp_dir=${output_dir}/CGP_consensus
pacbio_gene_set_dir=/hive/users/ifiddes/ihategit/pipeline/mouse_pacbio_${version}/CGP_consensus
pacbio_genomes=(CAST_EiJ PWK_PhJ SPRET_EiJ)
genomes=(C57BL_6NJ NZO_HlLtJ 129S1_SvImJ FVB_NJ NOD_ShiLtJ LP_J A_J AKR_J BALB_cJ DBA_2J C3H_HeJ CBA_J WSB_EiJ  CAROLI_EiJ Pahari_EiJ)
tmr_dir=${output_dir}/C57B6J/GencodeCompVM8/AugustusTMR_consensus_gene_set
raw_tmr_dir=${work_dir}/C57B6J/GencodeCompVM8/AugustusTMR/
combined_gene_set_dir=${output_dir}/combined_gene_sets

#TMR consensus
mkdir -p ${tmr_dir}/for_browser
cd ${tmr_dir}
for g in *; do
    if [ $g != 'for_browser' ]; then
        find $g -name '*.gp' ! -name 'combined.gp' | xargs -n 1 cat | ~/ifiddes_hive/ihategit/pipeline/bin/fixGenePredScore /dev/stdin > for_browser/$g.gp
    fi
done


# Raw TMR
mkdir -p ${raw_tmr_dir}/for_browser
cd ${raw_tmr_dir}
for gp in *.gp; do
    if [[  $gp != *"vector"* ]]; then
        ~/ifiddes_hive/ihategit/pipeline/bin/fixGenePredScore $gp > for_browser/$gp
    fi
done

cd /hive/users/ifiddes/ihategit/pipeline/


# combined gene sets
mkdir -p ${combined_gene_set_dir}
cp -rs ${tmr_dir}/* ${combined_gene_set_dir}/
# remove protein coding
find ${combined_gene_set_dir} | grep 'protein' | xargs rm
for p in ${cgp_dir}/*; do
    f=`basename $p`
    g=`echo $f | cut -d '.' -f 1`
    e=${f##*.}
    ln -s $p ${combined_gene_set_dir}/${g}/protein_coding.${e}
done

# remove combined if exists
find ${combined_gene_set_dir} ! -type d -name '*combined*' | xargs rm

# incorporate pacbio
for g in "${pacbio_genomes[@]}"; do
    rm ${combined_gene_set_dir}/${g}/protein*
    ln -s ${pacbio_gene_set_dir}/${g}.CGP_consensus.gp ${combined_gene_set_dir}/${g}/protein_coding.gp
    ln -s ${pacbio_gene_set_dir}/${g}.CGP_consensus.gtf ${combined_gene_set_dir}/${g}/protein_coding.gtf
done

# Make new combined. make link for browser. make genePred parseable.
mkdir -p ${combined_gene_set_dir}/for_browser
for p in ${combined_gene_set_dir}/*; do
    g=`basename $p`
    if [ $g != 'for_browser' ]; then
        cat ${combined_gene_set_dir}/${g}/*.gp >| ${combined_gene_set_dir}/${g}/combined.gp
        cat ${combined_gene_set_dir}/${g}/*.gtf >| ${combined_gene_set_dir}/${g}/combined.gtf
        python ~/ifiddes_hive/ihategit/pipeline/bin/fixGenePredScore ${combined_gene_set_dir}/${g}/combined.gp >| ${combined_gene_set_dir}/for_browser/${g}.gp
        ln -s ${combined_gene_set_dir}/${g}/combined.gtf ${combined_gene_set_dir}/for_browser/$g.gtf
    fi
done


# Common name GP/GTF for RNAseq analysis
for p in ${combined_gene_set_dir}/*; do
    g=`basename $p`
    if [ $g != 'for_browser' ]; then
        python fix_common_name_gtf.py $p/combined.gtf > ${combined_gene_set_dir}/${g}/combined_common_name.gtf
        gtfToGenePred -genePredExt ${combined_gene_set_dir}/${g}/combined_common_name.gtf ${combined_gene_set_dir}/${g}/combined_common_name.gp
    fi
done



# generate basic/comprehensive split
for g in ${genomes[@]}; do
    python submodules/comparativeAnnotator/scripts/generate_basic_comprehensive.py --db ${work_dir}/C57B6J/GencodeCompVM8/comparativeAnnotator/classification.db \
    --refGff3 /hive/users/ifiddes/Comparative-Annotation-Toolkit/CAT/gencode.vM8.annotation.gff3 \
    --refGp /hive/users/ifiddes/ihategit/pipeline/gencode_vm8/C57B6J_with_pseudogenes.gp \
    --augustusGtf ${work_dir}/C57B6J/GencodeCompVM8/AugustusTMR/${g}.gtf \
    --cgpGp /hive/users/ifiddes/ihategit/pipeline/cgp_predictions_v3_overlaps/${g}.gp \
    --transMapGp ${work_dir}/C57B6J/GencodeCompVM8/transMap/${g}.gp \
    --transMapPsl ${work_dir}/C57B6J/GencodeCompVM8/transMap/${g}.psl \
    --consensus ${output_dir}/combined_gene_sets/${g}/combined.gp \
    --outBasic ${output_dir}/basic_gene_sets/${g}.basic.gp
done


for g in ${pacbio_genomes[@]}; do
    python submodules/comparativeAnnotator/scripts/generate_basic_comprehensive.py --db ${work_dir}/C57B6J/GencodeCompVM8/comparativeAnnotator/classification.db \
    --refGff3 /hive/users/ifiddes/Comparative-Annotation-Toolkit/CAT/gencode.vM8.annotation.gff3 \
    --refGp /hive/users/ifiddes/ihategit/pipeline/gencode_vm8/C57B6J_with_pseudogenes.gp \
    --augustusGtf ${work_dir}/C57B6J/GencodeCompVM8/AugustusTMR/${g}.gtf \
    --cgpGp /hive/users/ifiddes/ihategit/pipeline/cgp_predictions_v3_overlaps/${g}.gp \
    --transMapGp ${work_dir}/C57B6J/GencodeCompVM8/transMap/${g}.gp \
    --transMapPsl ${work_dir}/C57B6J/GencodeCompVM8/transMap/${g}.psl \
    --consensus ${output_dir}/combined_gene_sets/${g}/combined.gp \
    --pacbioGtf pacbio_cast_spret/chr_${g}.gff_no_softmasking.gff \
    --outBasic ${output_dir}/basic_gene_sets/${g}.basic.gp
done



mkdir -p ${output_dir}/comprehensive_gene_sets
for p in ${combined_gene_set_dir}/for_browser/*.gtf; do
    n=$(basename $p)
    python ~/ifiddes_hive/ihategit/pipeline/fix_common_name_gtf.py $p > ${output_dir}/comprehensive_gene_sets/$n
    gtfToGenePred -genePredExt ${output_dir}/comprehensive_gene_sets/$n ${output_dir}/comprehensive_gene_sets/${n%.gtf}.gp
done


for p in ${output_dir}/basic_gene_sets/*gp; do
    n=$(basename $p)
    python ~/ifiddes_hive/ihategit/pipeline/bin/fixGenePredScore $p | \
    genePredToGtf -utr -honorCdsStat file /dev/stdin /dev/stdout | \
    python ~/ifiddes_hive/ihategit/pipeline/fix_common_name_gtf.py /dev/stdin > ${output_dir}/basic_gene_sets/${n%.gp}.gtf
done


mkdir -p ${output_dir}/basic_gene_sets/for_browser
for p in ${output_dir}/basic_gene_sets/*; do
    g=$(basename $p)
    if [ $g != 'for_browser' ]; then
        python ~/ifiddes_hive/ihategit/pipeline/bin/fixGenePredScore $p > ${output_dir}/basic_gene_sets/for_browser/$g
    fi
done

mkdir -p ${output_dir}/comprehensive_gene_sets/for_browser
for p in ${output_dir}/comprehensive_gene_sets/*; do
    g=`basename $p`
    if [ $g != 'for_browser' ]; then
        python ~/ifiddes_hive/ihategit/pipeline/bin/fixGenePredScore $p > ${output_dir}/comprehensive_gene_sets/for_browser/$g
    fi
done

for f in ${output_dir}/basic_gene_sets/*gp; do
    python ~/ifiddes_hive/ihategit/pipeline/bin/fixGenePredScore $f | genePredToGtf -utr -honorCdsStat -source=GencodeVM8 file /dev/stdin ${f%.gp}.gtf
done


for f in ${output_dir}/basic_gene_sets/*gtf; do
    python ~/ifiddes_hive/ihategit/pipeline/fix_common_name_gtf.py $f > $f.fixed
    mv -f $f.fixed $f
done

for f in ${output_dir}/{basic_gene_sets,comprehensive_gene_sets}/*gtf; do
    g=$(basename $f)
    g=`echo $g | cut -d '.' -f 1`
    python submodules/comparativeAnnotator/scripts/generate_unique_ids.py \
    ${f} ${g} ${work_dir}/C57B6J/GencodeCompVM8/comparativeAnnotator/classification.db \
    ${f}.fixed ${f}.gp_info
    mv -f $f.fixed $f
done


