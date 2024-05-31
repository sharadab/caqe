#!/bin/bash

#########################################################################################################
# This script warps the atlas of tissue classification to each MS subject, so that we can then compare
# differences in tissue classification directly, voxel by voxel, between the MS person and the healthy atlas.
# Usage: ./atlas_warp.sh -p /full/path/to/main/datafolder -s subject_id
# Output: atlas_clustering_rebinarized.nii.gz in the clustering_outputs folder.
#########################################################################################################

##Use these flags to specify full path and subject ID.
while getopts p:s: flag 
do
    case "${flag}" in
        p) path=${OPTARG};;
        s) subject=${OPTARG};;
    esac 
done

echo ${subject}
echo ${path}
script_folder=$(cd -P -- "$(dirname -- "$0")" && pwd -P) #The location of this actual script. 

#Set up folder locations
#Make these folders as needed.
folder_base="${path}"
folder_mdd_base="${path}/${subject}/MDD"
folder_mdd="${path}/${subject}/MDD/processed"
folder_mdd_in="${path}/${subject}/MDD/Inputs"
folder_mwf="${path}/${subject}/CALIPR"
folder_ants="${path}/${subject}/ants"
folder_rois="${path}/${subject}/ants/ROIs"
folder_base_rois="${script_folder}/ROIs"
folder_nifti="${path}/${subject}/NIFTI"
folder_parrec="${path}/${subject}/PARREC"
folder_atlas="${path}/atlas"
folder_nifti="${path}/${subject}/NIFTI"
folder_parrec="${path}/${subject}/PARREC"
folder_clustering="${path}/${subject}/clustering_outputs"

#Register 3DT1 to atlas first
mkdir ${folder_ants}/atlas_reg
antsRegistrationSyNQuick.sh -d 3 -f ${folder_ants}/3DT1/3DT1.nii.gz -m ${folder_atlas}/template_3dt1.nii.gz -o ${folder_ants}/atlas_reg/atlas_3dt1_ -n 8

# #Chain together transforms to do atlas -> calipr space. This works for HCs, not so well for MS due to lesions. So we do another thing (see below)
# antsApplyTransforms -d 3 -o [${folder_ants}/atlas_reg/concatenated_atlas2calipr_warp.nii.gz,1] -t ${folder_ants}/CALIPR_3DT1/0GenericAffine.mat -t ${folder_ants}/atlas_reg/atlas_3dt1_1Warp.nii.gz -t ${folder_ants}/atlas_reg/atlas_3dt1_0GenericAffine.mat -r ${folder_ants}/CALIPR/${subject}_E1.nii.gz -v
# antsApplyTransforms -d 3 -i ${folder_atlas}/template_3dt1.nii.gz -t ${folder_ants}/atlas_reg/concatenated_atlas2calipr_warp.nii.gz -r ${folder_ants}/CALIPR/${subject}_E1.nii.gz -o ${folder_ants}/atlas_reg/atlas_to_calipr.nii.gz -v

####### MS ONLY: Since the 3DT1 causes issues with CSF warping in MS with periventricular lesions, let's try doing it with FLAIR instead. Like register directly to FLAIR.
antsApplyTransforms -d 3 -i ${folder_ants}/3DT1/BrainExtractionMask.nii.gz -t ${folder_ants}/CALIPR_3DT1/0GenericAffine.mat -r ${folder_ants}/CALIPR/${subject}_E1.nii.gz -o ${folder_ants}/CALIPR_3DT1/BrainExtractionMask.nii.gz -v
fslmaths ${folder_ants}/CALIPR_3DT1/BrainExtractionMask.nii.gz -thr 0.9 ${folder_ants}/CALIPR_3DT1/BrainExtractionMask.nii.gz
fslmaths ${folder_ants}/CALIPR_3DT1/BrainExtractionMask.nii.gz -mul ${folder_ants}/CALIPR_3DT1/Warped.nii.gz ${folder_ants}/CALIPR_3DT1/3DT1_brain.nii.gz

## Now a tricky bit. Registration works better if FLAIR is multiplied by T1w, so that lesions don't get missed out and ventricles warp properly, and registering with FLAIR on its own isn't amazing.
## FLAIR and T1w have different intensities, so first rescale (normalize) each image and then multiply to keep important properties of both.
max=(`fslstats ${folder_ants}/CALIPR_FLAIR/FLAIR_brain.nii.gz -R`)
#echo ${max[1]} ##This is the max, to multiply images by to get a FLAIR*3DT1 that is better for atlas registration.
fslmaths ${folder_ants}/CALIPR_FLAIR/FLAIR_brain.nii.gz -div ${max[1]} ${folder_ants}/CALIPR_FLAIR/FLAIR_scaled.nii.gz
max=(`fslstats ${folder_ants}/CALIPR_3DT1/3DT1_brain.nii.gz -R`)
#echo ${max[1]} ##This is the max, to multiply images by to get a FLAIR*3DT1 that is better for atlas registration.
fslmaths ${folder_ants}/CALIPR_3DT1/3DT1_brain.nii.gz -div ${max[1]} ${folder_ants}/CALIPR_3DT1/3DT1_scaled.nii.gz
fslmaths ${folder_ants}/CALIPR_FLAIR/FLAIR_scaled.nii.gz -mul ${folder_ants}/CALIPR_3DT1/3DT1_scaled.nii.gz ${folder_ants}/atlas_reg/FLAIR_3DT1.nii.gz

## Register FLAIR_3DT1 image to atlas, registration works better.
antsRegistrationSyNQuick.sh -d 3 -f ${folder_ants}/atlas_reg/FLAIR_3DT1.nii.gz -m ${folder_atlas}/template_3dt1.nii.gz -o ${folder_ants}/atlas_reg/atlas_calipr_ -n 8 

## Apply the total transform.
antsApplyTransforms -d 3 -i ${folder_atlas}/clustering_outputs/recoloured_6cluster.nii.gz -t ${folder_ants}/atlas_reg/atlas_calipr_1Warp.nii.gz -t ${folder_ants}/atlas_reg/atlas_calipr_0GenericAffine.mat -r ${folder_ants}/CALIPR_FLAIR/FLAIR_brain.nii.gz -o ${folder_clustering}/atlas_clustering.nii.gz -v

##Threshold each cluster so that it's binarized, no float values just all int. Put it all back together to get a clustered atlas in subject space.
fslmaths ${folder_clustering}/atlas_clustering.nii.gz -thr 0 -uthr 1.5 -bin -mul 1 ${folder_clustering}/atlas_clustering_c1.nii.gz
fslmaths ${folder_clustering}/atlas_clustering.nii.gz -thr 1.5 -uthr 2.5 -bin -mul 2 ${folder_clustering}/atlas_clustering_c2.nii.gz
fslmaths ${folder_clustering}/atlas_clustering.nii.gz -thr 2.5 -uthr 3.5 -bin -mul 3 ${folder_clustering}/atlas_clustering_c3.nii.gz
fslmaths ${folder_clustering}/atlas_clustering.nii.gz -thr 3.5 -uthr 4.5 -bin -mul 4 ${folder_clustering}/atlas_clustering_c4.nii.gz
fslmaths ${folder_clustering}/atlas_clustering.nii.gz -thr 4.5 -uthr 5.5 -bin -mul 5 ${folder_clustering}/atlas_clustering_c5.nii.gz
fslmaths ${folder_clustering}/atlas_clustering.nii.gz -thr 5.5 -uthr 6.5 -bin -mul 6 ${folder_clustering}/atlas_clustering_c6.nii.gz
fslmaths ${folder_clustering}/atlas_clustering.nii.gz -thr 6.5 -uthr 7.5 -bin -mul 7 ${folder_clustering}/atlas_clustering_c7.nii.gz
fslmaths ${folder_clustering}/atlas_clustering_c1.nii.gz -add ${folder_clustering}/atlas_clustering_c2.nii.gz -add ${folder_clustering}/atlas_clustering_c3.nii.gz -add ${folder_clustering}/atlas_clustering_c4.nii.gz -add ${folder_clustering}/atlas_clustering_c5.nii.gz -add ${folder_clustering}/atlas_clustering_c6.nii.gz -add ${folder_clustering}/atlas_clustering_c7.nii.gz ${folder_clustering}/atlas_clustering_rebinarized.nii.gz
#fslmaths ${folder_clustering}/atlas_clustering_c2.nii.gz -add ${folder_clustering}/atlas_clustering_c3.nii.gz -add ${folder_clustering}/atlas_clustering_c4.nii.gz -add ${folder_clustering}/atlas_clustering_c5.nii.gz -add ${folder_clustering}/atlas_clustering_c6.nii.gz -add ${folder_clustering}/atlas_clustering_c7.nii.gz ${folder_clustering}/atlas_clustering_rebinarized.nii.gz
rm ${folder_clustering}/atlas_clustering_c1.nii.gz
rm ${folder_clustering}/atlas_clustering_c2.nii.gz
rm ${folder_clustering}/atlas_clustering_c3.nii.gz
rm ${folder_clustering}/atlas_clustering_c4.nii.gz
rm ${folder_clustering}/atlas_clustering_c5.nii.gz
rm ${folder_clustering}/atlas_clustering_c6.nii.gz
rm ${folder_clustering}/atlas_clustering_c7.nii.gz

## Multiply by CSF mask and then re-fill in the CSF bits so that difference maps don't include CSF edge bits.
## For that, first invert the mask_no_csf to make a mask_just_csf and add it to atlas_clustering_rebinarized.
fslmaths ${folder_ants}/CALIPR/mask_no_csf.nii.gz -mul -1 -add 1 -mul ${folder_ants}/CALIPR/BrainExtractionMask_ero.nii.gz ${folder_ants}/CALIPR/mask_just_csf.nii.gz
fslmaths ${folder_clustering}/atlas_clustering_rebinarized.nii.gz -mul ${folder_ants}/CALIPR/mask_no_csf.nii.gz ${folder_clustering}/atlas_clustering_rebinarized.nii.gz
fslmaths ${folder_clustering}/atlas_clustering_rebinarized.nii.gz -add ${folder_ants}/CALIPR/mask_just_csf.nii.gz ${folder_clustering}/atlas_clustering_rebinarized.nii.gz

## Copy over CALIPR_FLAIR to atlas folder for easier comparisons
cp ${folder_ants}/CALIPR_FLAIR/FLAIR_brain.nii.gz ${folder_clustering}/FLAIR.nii.gz








