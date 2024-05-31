#!/bin/bash

#########################################################################################################
# This script creates metric maps from diffusion data and assumes MWF maps have already been generated.
# It registers CALIPR and TVDE images for clustering, and creates a CSF and no-CSF mask.
# This version is for healthy controls. The MS script is for MS subjects, as their CSF masking is trickier.
# Usage: ./initial_processing.sh -p /full/path/to/main/datafolder -s subject_id
# Output: QTI+ metrics in MDD/processed/qti_degibbs; Registered images in ants/. 
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


##First convert PARRECs to NIFTIs##########################
echo "Converting data to NIFTI"
mkdir ${folder_nifti}
dcm2niix -o ${folder_nifti} -f %p ${folder_parrec}
gzip ${folder_nifti}/*.nii 

##At this point, let's also fix the 3DT1s to overlay in a standard way with MNI (because it's a sagittal acquisition it looks weird)
echo "Fixing 3DT1 orientation"
fslreorient2std ${folder_nifti}/*T1*.nii.gz ${folder_nifti}/3DT1.nii.gz


#####################Doing tensor-valued diffusion Processing#######################
#Next, copy MDD files into an MDD folder
mkdir ${folder_mdd_base}
mkdir ${folder_mdd_in}

#Move in the data into input folder for processing
echo "Copying in TVDE data"
cp ${folder_nifti}/*LTE*.* ${folder_mdd_in}/
cp ${folder_nifti}/*PTE*.* ${folder_mdd_in}/
cp ${folder_nifti}/*STE*.* ${folder_mdd_in}/
cp ${folder_nifti}/*MDD*.nii.gz ${folder_mdd_in}/Rev_B0.nii.gz

#####Now all the diffusion pre-processing. 
cd ${folder_base}

#Next, do topup for susceptibility correction on each type of encoding data
declare -a diffusion_type=("LTE" "PTE" "STE")
for encoding in "${diffusion_type[@]}"; do

    echo "Denoising and Degibbsing ${encoding}"
    #First denoise the data
    dwidenoise ${folder_mdd_in}/${encoding}.nii.gz ${folder_mdd_in}/${encoding}_processed1.nii.gz -noise ${folder_mdd_in}/${encoding}_noise.nii.gz -force
    #Then degibbs the data
    mrdegibbs ${folder_mdd_in}/${encoding}_processed1.nii.gz ${folder_mdd_in}/${encoding}_processed.nii.gz -force 
    #Some naming logistics to preserve the original data separately and call the denoised, degibbsed data the original name
    cp ${folder_mdd_in}/${encoding}.nii.gz ${folder_mdd_in}/${encoding}_og.nii.gz 
    cp ${folder_mdd_in}/${encoding}_processed.nii.gz ${folder_mdd_in}/${encoding}.nii.gz

    #Now topup for susceptibility correction
    echo "Topup with ${encoding} data"
    mkdir ${folder_mdd_in}/TOPUP_${encoding} 
    fslroi ${folder_mdd_in}/${encoding}.nii.gz ${folder_mdd_in}/TOPUP_${encoding}/b0.nii.gz 0 1

    ##Move acqparams.txt from here into the MDD folder (needed for topup)
    cp ${script_folder}/acqparams.txt ${folder_mdd_in}/TOPUP_${encoding}/acqparams.txt 
    cp ${folder_mdd_in}/Rev_B0.nii.gz ${folder_mdd_in}/TOPUP_${encoding}/rev_b0.nii.gz

    ##Now run topup 
    cd ${folder_mdd_in}/TOPUP_${encoding}
    fslmerge -t AP_PA b0 rev_b0
    topup --imain=AP_PA --datain=acqparams.txt --config=b02b0.cnf --out=my_topup --iout=my_topup_iout --fout=my_topup_fout
    fslmaths my_topup_iout.nii.gz -Tmean ${encoding}_b0_topup.nii.gz
    cd ${folder_base}
    applytopup --imain=${folder_mdd_in}/${encoding}.nii.gz --topup=${folder_mdd_in}/TOPUP_${encoding}/my_topup --inindex=1 --method=jac --interp=spline --out=${folder_mdd_in}/${encoding}_TOPUP --datain=${folder_mdd_in}/TOPUP_${encoding}/acqparams.txt --verbose

    ##And rename the TOPUP file back as LTE/STE/PTE for next steps.
    cp ${folder_mdd_in}/${encoding}_TOPUP.nii.gz ${folder_mdd_in}/${encoding}.nii.gz

done


#Brain extract the LTE image using dwi2mask since that seems to work best (way better than bet or ANTs). Use this as the mask for next steps.
dwi2mask ${folder_mdd_in}/LTE.nii.gz -fslgrad ${folder_mdd_in}/LTE.bvec ${folder_mdd_in}/LTE.bval -info -nthreads 8 ${folder_mdd_in}/mask.nii.gz


##Go back to the folder of this script
cd ${script_folder} 


#Now we need to do motion and eddy current correction. Using md-DMRI's ElastiX wrapper for that, and compile data into their format first.
matlab -nodisplay -nodesktop -nosplash -r "MDD_setup('${path}/', '${subject}');exit();"


#And run the actual QTI+ pipeline now for each subject to generate a bunch of metric maps.
matlab -nodisplay -nodesktop -nosplash -r "QTIPlus('${path}/', '${subject}');exit();"


#And fix the geometries/move into useful folder.
mkdir ${folder_mdd}/qti 
mv ${folder_mdd}/qti_* ${folder_mdd}/qti/


#Within QTI folder, copy geometry from other files and zip everything
gzip ${folder_mdd}/qti/qti_*.nii

fslcpgeom ${folder_mdd_in}/mask.nii.gz ${folder_mdd}/qti/qti_fa.nii.gz 
fslcpgeom ${folder_mdd_in}/mask.nii.gz ${folder_mdd}/qti/qti_md.nii.gz 
fslcpgeom ${folder_mdd_in}/mask.nii.gz ${folder_mdd}/qti/qti_rd.nii.gz 
fslcpgeom ${folder_mdd_in}/mask.nii.gz ${folder_mdd}/qti/qti_ad.nii.gz 

fslcpgeom ${folder_mdd_in}/mask.nii.gz ${folder_mdd}/qti/qti_ufa.nii.gz 
fslcpgeom ${folder_mdd_in}/mask.nii.gz ${folder_mdd}/qti/qti_c_c.nii.gz
fslcpgeom ${folder_mdd_in}/mask.nii.gz ${folder_mdd}/qti/qti_c_mu.nii.gz
fslcpgeom ${folder_mdd_in}/mask.nii.gz ${folder_mdd}/qti/qti_c_md.nii.gz 

fslcpgeom ${folder_mdd_in}/mask.nii.gz ${folder_mdd}/qti/qti_op.nii.gz
fslcpgeom ${folder_mdd_in}/mask.nii.gz ${folder_mdd}/qti/qti_mk.nii.gz  
fslcpgeom ${folder_mdd_in}/mask.nii.gz ${folder_mdd}/qti/qti_kbulk.nii.gz
fslcpgeom ${folder_mdd_in}/mask.nii.gz ${folder_mdd}/qti/qti_kshear.nii.gz
fslcpgeom ${folder_mdd_in}/mask.nii.gz ${folder_mdd}/qti/qti_kmu.nii.gz




######Now deal with MWF####################################
###This assumes CALIPR with images already made into 56 volume set, MWF maps are made,
#brain is extracted, and all of it is in CALIPR folder#####
echo "Working on MWF logistics"
cd ${script_folder}
mkdir ${folder_ants}
mkdir ${folder_ants}/CALIPR

#Take 1st echo for registration to T1-w, and 28th echo for registration to diffusion space
fslroi ${folder_mwf}/${subject}_CALIPR.nii.gz ${folder_ants}/CALIPR/${subject}_E28.nii.gz 27 1
fslroi ${folder_mwf}/${subject}_CALIPR.nii.gz ${folder_ants}/CALIPR/${subject}_E1.nii.gz 0 1
cp ${folder_mwf}/${subject}_BrainExtractionMask.nii.gz ${folder_ants}/CALIPR/BrainExtractionMask.nii.gz #Copy in the brainExtractionMask.

#Copy over the rest into ants folder, multiplied by mask
fslmaths ${folder_mwf}/${subject}_CALIPR_MWF.nii.gz -mul ${folder_ants}/CALIPR/BrainExtractionMask.nii.gz ${folder_ants}/CALIPR/MWF_brain.nii.gz
fslmaths ${folder_ants}/CALIPR/${subject}_E1.nii.gz -mul ${folder_ants}/CALIPR/BrainExtractionMask.nii.gz ${folder_ants}/CALIPR/${subject}_E1_brain.nii.gz
fslmaths ${folder_ants}/CALIPR/${subject}_E28.nii.gz -mul ${folder_ants}/CALIPR/BrainExtractionMask.nii.gz ${folder_ants}/CALIPR/${subject}_E28_brain.nii.gz
fslcpgeom ${folder_ants}/CALIPR/${subject}_E1.nii.gz ${folder_ants}/CALIPR/MWF_brain.nii.gz ##Fix geom if needed

##As a final little bit, MWF is often very high on the outer brain edge which throws off clustering (artifact). Erode the mask for just that.
fslmaths ${folder_ants}/CALIPR/BrainExtractionMask.nii.gz -eroF ${folder_ants}/CALIPR/BrainExtractionMask_ero.nii.gz
fslmaths ${folder_mwf}/${subject}_CALIPR_MWF.nii.gz -mul ${folder_ants}/CALIPR/BrainExtractionMask_ero.nii.gz ${folder_ants}/CALIPR/MWF_brain_ero.nii.gz
fslcpgeom ${folder_ants}/CALIPR/${subject}_E1.nii.gz ${folder_ants}/CALIPR/MWF_brain_ero.nii.gz
fslcpgeom ${folder_ants}/CALIPR/${subject}_E1.nii.gz ${folder_ants}/CALIPR/BrainExtractionMask_ero.nii.gz




############ Now deal with registration. At the end of this, we want MWF, uFA and C_MD maps all registered together. ######

####Extract T1w brain. This takes a little time. Make the directory for it first.
##Extract brain and register to MNI template. This takes a little time. Make the directory for it first.
echo "T1w brain extraction"
cd ${script_folder}
mkdir ${folder_ants}/3DT1
antsBrainExtraction.sh -d 3 -a ${folder_nifti}/3DT1.nii.gz -e ../NKI_Template/T_template.nii.gz -m ../NKI_Template/T_template_BrainCerebellumProbabilityMask.nii.gz -o ${folder_ants}/3DT1/
mv ${folder_ants}/3DT1/BrainExtractionBrain.nii.gz ${folder_ants}/3DT1/3DT1.nii.gz 
cp ${folder_nifti}/3DT1.nii.gz ${folder_ants}/3DT1/3DT1_whole.nii.gz

##Register T1w to MNI 1mm template for future use.
antsRegistrationSyNQuick.sh -d 3 -f ${folder_ants}/3DT1/3DT1.nii.gz -m MNI152_T1_1mm_brain.nii.gz -o ${folder_ants}/3DT1/ -n 6


############TVDE setting up stuff###################
#Make directories to store TVDE data in ants folder
echo "Setting up Diffusion ANTs folder"
mkdir ${folder_ants}/MDD
fslroi ${folder_mdd}/FWF_mc.nii.gz ${folder_ants}/MDD/FWF_mc_b0.nii.gz 0 1


####################### Register everything to 3DT1, ie CALIPR->3DT1, TVDE->3DT1; this is useful for atlas building, and just kind of in general #######
##First register diffusion b0 to T1w, and also move over images into T1 space (useful later on for atlas building)
echo "Registering Diffusion b0 to T1w"
mkdir ${folder_ants}/MDD_3DT1
epi_reg --epi=${folder_ants}/MDD/FWF_mc_b0 --t1=${folder_ants}/3DT1/3DT1_whole --t1brain=${folder_ants}/3DT1/3DT1 --out=${folder_ants}/MDD_3DT1/b0_to_3DT1
flirt -in ${folder_mdd}/qti/qti_ufa.nii.gz -ref ${folder_ants}/3DT1/3DT1 -out ${folder_ants}/MDD_3DT1/ufa -init ${folder_ants}/MDD_3DT1/b0_to_3DT1.mat -applyxfm
flirt -in ${folder_mdd}/qti/qti_c_md.nii.gz -ref ${folder_ants}/3DT1/3DT1 -out ${folder_ants}/MDD_3DT1/cmd -init ${folder_ants}/MDD_3DT1/b0_to_3DT1.mat -applyxfm

##In case it works better for atlas building, an ANTs version as well
fslmaths ${folder_ants}/MDD/FWF_mc_b0.nii.gz -mul ${folder_mdd_in}/mask.nii.gz ${folder_ants}/MDD/FWF_mc_b0_masked.nii.gz
antsRegistrationSyN.sh -d 3 -f ${folder_ants}/MDD/FWF_mc_b0_masked.nii.gz -m ${folder_ants}/3DT1/3DT1.nii.gz -r 1 -g 0.05 -o ${folder_ants}/MDD_3DT1/


##Register CALIPR to T1w, affine reg only. Also move over MWF for atlas building later on.
echo "Registering CALIPR E1 to T1w"
mkdir ${folder_ants}/CALIPR_3DT1
antsRegistrationSyNQuick.sh -d 3 -f ${folder_ants}/CALIPR/${subject}_E1.nii.gz -m ${folder_ants}/3DT1/3DT1_whole.nii.gz -o ${folder_ants}/CALIPR_3DT1/ -n 8 -t a
antsApplyTransforms -d 3 -e 0 -i ${folder_ants}/CALIPR/MWF_brain_ero.nii.gz -r ${folder_ants}/3DT1/3DT1_whole.nii.gz -o ${folder_ants}/CALIPR_3DT1/MWF.nii.gz -t ${folder_ants}/CALIPR_3DT1/0GenericAffine.mat

##In case it works out better to use SyN for atlas building later on, have it on hand.
mkdir ${folder_ants}/CALIPR_3DT1/SyN
antsRegistrationSyNQuick.sh -d 3 -f ${folder_ants}/CALIPR/${subject}_E1_brain.nii.gz -m ${folder_ants}/3DT1/3DT1.nii.gz -o ${folder_ants}/CALIPR_3DT1/SyN/ -n 8 


#################### Register TVDE to CALIPR space for clustering #####################################
##Also register CALIPR and TVDE for clustering. Warp all TVDE images to CALIPR space.
##epi_reg works well because E1 is sort of similar to T1w.
mkdir ${folder_ants}/CALIPR_MDD
echo "Registering TVDE to CALIPR space"
epi_reg --epi=${folder_ants}/MDD/FWF_mc_b0 --t1=${folder_ants}/CALIPR/${subject}_E1 --t1brain=${folder_ants}/CALIPR/${subject}_E1_brain --out=${folder_ants}/CALIPR_MDD/b0_to_E1
flirt -in ${folder_mdd}/qti/qti_ufa.nii.gz -ref ${folder_ants}/CALIPR/${subject}_E1 -out ${folder_ants}/CALIPR_MDD/ufa -init ${folder_ants}/CALIPR_MDD/b0_to_E1.mat -applyxfm
flirt -in ${folder_mdd}/qti/qti_fa.nii.gz -ref ${folder_ants}/CALIPR/${subject}_E1 -out ${folder_ants}/CALIPR_MDD/fa -init ${folder_ants}/CALIPR_MDD/b0_to_E1.mat -applyxfm
flirt -in ${folder_mdd}/qti/qti_c_md.nii.gz -ref ${folder_ants}/CALIPR/${subject}_E1 -out ${folder_ants}/CALIPR_MDD/cmd -init ${folder_ants}/CALIPR_MDD/b0_to_E1.mat -applyxfm
flirt -in ${folder_mdd}/qti/qti_md.nii.gz -ref ${folder_ants}/CALIPR/${subject}_E1 -out ${folder_ants}/CALIPR_MDD/md -init ${folder_ants}/CALIPR_MDD/b0_to_E1.mat -applyxfm


############### Making a non-CSF and CSF-specific mask #####################
#For clustering-- everything in CALIPR space. Just for HCs, and it's so complicated just for dealing with CSF.
Atropos -d 3 -a ${folder_ants}/3DT1/3DT1.nii.gz -i Otsu[3] -x ${folder_ants}/3DT1/BrainExtractionMask.nii.gz -o ${folder_ants}/3DT1/segmented.nii.gz
fslmaths ${folder_ants}/3DT1/segmented.nii.gz -thr 2 -uthr 3 -bin ${folder_ants}/3DT1/no_csf_mask.nii.gz
fslmaths ${folder_ants}/3DT1/segmented.nii.gz -uthr 1 -bin ${folder_ants}/3DT1/csf_mask.nii.gz
antsApplyTransforms -d 3 -e 0 -i ${folder_ants}/3DT1/no_csf_mask.nii.gz -r ${folder_ants}/CALIPR/${subject}_E1.nii.gz -t ${folder_ants}/CALIPR_3DT1/0GenericAffine.mat -o ${folder_ants}/CALIPR/mask_no_csf.nii.gz
fslmaths ${folder_ants}/CALIPR/mask_no_csf.nii.gz -thr 0.8 -bin ${folder_ants}/CALIPR/mask_no_csf.nii.gz


#Also warp over the CSF mask and keep it that way. Here it is a pretty generous mask! Make sure there is no overlap with tissue.
antsApplyTransforms -d 3 -e 0 -i ${folder_ants}/3DT1/csf_mask.nii.gz -r ${folder_ants}/CALIPR/${subject}_E1.nii.gz -t ${folder_ants}/CALIPR_3DT1/0GenericAffine.mat -o ${folder_ants}/CALIPR/csf_mask.nii.gz
fslmaths ${folder_ants}/CALIPR/csf_mask.nii.gz -thr 0.1 -bin ${folder_ants}/CALIPR/csf_mask.nii.gz
#This csf_mask and mask_no_csf have a bit of overlap so lets get rid of that, since it will hamper the clustering visualization by adding numbers.
#Since there is no "and", we will add the two and wherever there is 2 that is the overlap, so we turn that into a separate mask, and then subtract it from csf_mask.
fslmaths ${folder_ants}/CALIPR/csf_mask.nii.gz -add ${folder_ants}/CALIPR/mask_no_csf.nii.gz -thr 2 -uthr 2 -bin ${folder_ants}/CALIPR/csf_overlap.nii.gz
#Remove overlap from main mask rather than CSF.
fslmaths ${folder_ants}/CALIPR/mask_no_csf.nii.gz -sub ${folder_ants}/CALIPR/csf_overlap.nii.gz ${folder_ants}/CALIPR/mask_no_csf.nii.gz
##And then multiply with the slightly eroded brain mask to keep just the good, well-within-tissue MWF bits.
fslmaths ${folder_ants}/CALIPR/mask_no_csf.nii.gz -mul ${folder_ants}/CALIPR/BrainExtractionMask_ero.nii.gz ${folder_ants}/CALIPR/mask_no_csf.nii.gz

