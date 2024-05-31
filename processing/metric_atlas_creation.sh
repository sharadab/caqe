#!/bin/bash 

##################################################################################################################
# This script generates an metric atlases using all the healthy subjects (provided in a separate text file).
# This requires all metric maps to already be created, and 3DT1s to be registered to MNI 1mm space.
# The atlases will all live in atlas/, a new folder.
# Usage: ./atlas.sh -p path/to/folder/of/all_subject_folders -f filename_of_subject_list.txt
# Output: In atlas/ folder, mean and stdev atlases for all metrics and warps to go from each subject's 3DT1 to atlas space.
# ..contd: In each subject's ants/CALIPR/ and ants/MDD/ space, metric maps in atlas space.
##################################################################################################################

#Use these flags to specify full path to folder containing all data, and a file containing all subjects that should go into the tract atlas.
while getopts p:f: flag 
do
    case "${flag}" in
        p) path=${OPTARG};;
        f) filename=${OPTARG};;
    esac 
done

#Inspiration: https://stackoverflow.com/questions/24628076/convert-multiline-string-to-array
some_data=$(<"$filename") #Read in the file
SAVEIFS=$IFS   # Save current IFS (Internal Field Separator)
IFS=$'\n'      # Change IFS to newline char
subject=($some_data) # split the `names` string into an array by the same name
IFS=$SAVEIFS   # Restore original IFS
for (( i=0; i<${#subject[@]}; i++ )) #As a sanity check, just print out all the subjects. It should be an array.
do
    echo "$i: ${subject[$i]}"
done

script_folder=$(cd -P -- "$(dirname -- "$0")" && pwd -P) #Keep track of where this actual file tractography_atlas.sh lives

#Set up folder locations
#Make these folders as needed.
folder_base="${path}"
folder_atlas="${path}/atlas"

mkdir ${folder_atlas}

cd ${folder_base} #Get into the base folder for the next few things

#3DT1s are already registered to MNI T1 1mm brain. Use 2 of these to create a target for the atlas making process. Arbitrarily picking the first 2 in the list.
target_MNI_space=( "${subject[@]/%//ants/3DT1/InverseWarped.nii.gz}" ) #Just appending some things to each entry in subject_list.txt
fslmaths ${target_MNI_space[0]} -add ${target_MNI_space[1]} -div 2 ${folder_atlas}/avg_2_T1s.nii.gz

#Copy in all subjects' 3DT1s into the atlas folder
mkdir ${folder_atlas}/inputs
for i in "${subject[@]}"; do
echo "Copying in files"
cp ${i}/ants/3DT1/3DT1.nii.gz ${folder_atlas}/inputs/${i}.nii.gz
done 

#Make the atlas-- took about 1.5 hours for 6 subjects.
#This uses 10 cores (-j 10), change as necessary.
cd ${folder_atlas}
echo "Template construction, may take a while"
antsMultivariateTemplateConstruction.sh -d 3 -o template_ -c 2 -j 10 -g 0.2 -z avg_2_T1s.nii.gz inputs/*.nii.gz
cp template_template0.nii.gz template_3dt1.nii.gz #Naming it nicer for later use.

cd ${folder_base}
# #Now for each subject, concatenate the warps from template -> 3DT1 -> CALIPR/MDD and apply it to a CALIPR/MDD image to check
j=0 #j is needed for some naming conventions that use numbers instead of subject ID
for i in "${subject[@]}"; do
echo ${j}
#CALIPR first. 
#Concatenate warps to do CALIPR -> template
antsApplyTransforms -d 3 -o [${i}/ants/CALIPR/concatenated_caliprtoatlas_warp.nii.gz,1] -t ${folder_atlas}/template_${i}${j}Warp.nii.gz -t ${folder_atlas}/template_${i}${j}Affine.txt -t ${i}/ants/CALIPR_3DT1/SyN/1InverseWarp.nii.gz -t [${i}/ants/CALIPR_3DT1/SyN/0GenericAffine.mat,1] -r ${folder_atlas}/template_template0.nii.gz -v
#Test it on E1 of CALIPR
antsApplyTransforms -d 3 -i ${i}/ants/CALIPR/${i}_E1.nii.gz -t ${i}/ants/CALIPR/concatenated_caliprtoatlas_warp.nii.gz -r ${folder_atlas}/template_template0.nii.gz -o ${i}/ants/CALIPR/e1_atlas_space.nii.gz -v
#Also warp MWF and IET2 (to make an MWF atlas eventually).
antsApplyTransforms -d 3 -i ${i}/ants/CALIPR/MWF_brain.nii.gz -t ${i}/ants/CALIPR/concatenated_caliprtoatlas_warp.nii.gz -r ${folder_atlas}/template_template0.nii.gz -o ${i}/ants/CALIPR/mwf_atlas_space.nii.gz -v

#Next do MDD metric maps
#Concatenate warps to do MDD -> template
antsApplyTransforms -d 3 -o [${i}/ants/MDD/concatenated_mddtoatlas_warp.nii.gz,1] -t ${folder_atlas}/template_${i}${j}Warp.nii.gz -t ${folder_atlas}/template_${i}${j}Affine.txt -t ${i}/ants/MDD_3DT1/1InverseWarp.nii.gz -t [${i}/ants/MDD_3DT1/0GenericAffine.mat,1] -r ${folder_atlas}/template_template0.nii.gz -v
#Apply to the b0 image to test it out
antsApplyTransforms -d 3 -i ${i}/ants/MDD/FWF_mc_b0.nii.gz -t ${i}/ants/MDD/concatenated_mddtoatlas_warp.nii.gz -r ${folder_atlas}/template_template0.nii.gz -o ${i}/ants/MDD/b0_atlas_space.nii.gz -v
#Apply to all metric maps of interest
antsApplyTransforms -d 3 -i ${i}/MDD/processed/qti/qti_ufa.nii.gz -t ${i}/ants/MDD/concatenated_mddtoatlas_warp.nii.gz -r ${folder_atlas}/template_template0.nii.gz -o ${i}/ants/MDD/ufa_atlas_space.nii.gz -v
antsApplyTransforms -d 3 -i ${i}/MDD/processed/qti/qti_c_md.nii.gz -t ${i}/ants/MDD/concatenated_mddtoatlas_warp.nii.gz -r ${folder_atlas}/template_template0.nii.gz -o ${i}/ants/MDD/cmd_atlas_space.nii.gz -v
#Move on
j=$((j+1))
done 


#Now make a 4D volume of each metric in atlas space and stick it in the atlas folder, then create a mean and std image for each metric to then use for z-score purposes
#Pre-build some strings to make it easier to use
mwf_atlas_space=( "${subject[@]/%//ants/CALIPR/mwf_atlas_space.nii.gz}" )
ufa_atlas_space=( "${subject[@]/%//ants/MDD/ufa_atlas_space.nii.gz}" )
cmd_atlas_space=( "${subject[@]/%//ants/MDD/cmd_atlas_space.nii.gz}" )

#Merge all these into separate 4D volumes to then create mean/std of atlases
echo "Creating atlases for each metric"

#First MWF
fslmerge -t ${folder_atlas}/mwf_4d.nii.gz ${mwf_atlas_space[@]}
fslmaths ${folder_atlas}/mwf_4d.nii.gz -Tmean  ${folder_atlas}/mwf_atlas.nii.gz
fslmaths ${folder_atlas}/mwf_4d.nii.gz -Tstd  ${folder_atlas}/mwf_std_atlas.nii.gz
#Remove areas of high natural variation and/or misregistration (usually ends up being edges)
fslmaths ${folder_atlas}/mwf_std_atlas.nii.gz -div ${folder_atlas}/mwf_atlas.nii.gz ${folder_atlas}/mwf_cov.nii.gz
fslmaths ${folder_atlas}/mwf_cov.nii.gz -uthr 0.75 -bin ${folder_atlas}/mwf_cov_mask.nii.gz

fslmerge -t ${folder_atlas}/ufa_4d.nii.gz ${ufa_atlas_space[@]}
fslmaths ${folder_atlas}/ufa_4d.nii.gz -Tmean  ${folder_atlas}/ufa_atlas.nii.gz
fslmaths ${folder_atlas}/ufa_4d.nii.gz -Tstd  ${folder_atlas}/ufa_std_atlas.nii.gz
fslmaths ${folder_atlas}/ufa_std_atlas.nii.gz -div ${folder_atlas}/ufa_atlas.nii.gz ${folder_atlas}/ufa_cov.nii.gz
fslmaths ${folder_atlas}/ufa_cov.nii.gz -uthr 0.75 -bin ${folder_atlas}/ufa_cov_mask.nii.gz

fslmerge -t ${folder_atlas}/cmd_4d.nii.gz ${cmd_atlas_space[@]}
fslmaths ${folder_atlas}/cmd_4d.nii.gz -Tmean  ${folder_atlas}/cmd_atlas.nii.gz
fslmaths ${folder_atlas}/cmd_4d.nii.gz -Tstd  ${folder_atlas}/cmd_std_atlas.nii.gz
fslmaths ${folder_atlas}/cmd_std_atlas.nii.gz -div ${folder_atlas}/cmd_atlas.nii.gz ${folder_atlas}/cmd_cov.nii.gz
fslmaths ${folder_atlas}/cmd_cov.nii.gz -uthr 0.75 -bin ${folder_atlas}/cmd_cov_mask.nii.gz

echo "Atlases created!"
#Now we have nice mean and stdev metric atlases!

##Create a no-CSF and yes-CSF mask
fslmaths ${folder_atlas}/mwf_atlas.nii.gz -bin ${folder_atlas}/template_mwf_mask.nii.gz ## Since MWF has the lowest FOV
####### At this point, open up template_mwf_mask and clean up the slices at the bottom of the brain that look garbled (up to slice 57-58?) #####
fslmaths ${folder_atlas}/template_3dt1.nii.gz -bin ${folder_atlas}/template_mask.nii.gz ## Better template mask
## Multiply the two to keep only the mask where MWF also exists (ie isn't cut off due to FOV range)
fslmaths ${folder_atlas}/template_mask.nii.gz -mul ${folder_atlas}/template_mwf_mask -eroF ${folder_atlas}/template_mask_common 

## Segment the tissue
echo "Segmenting atlas tissue"
Atropos -d 3 -a ${folder_atlas}/template_template0.nii.gz -i Otsu[3] -x ${folder_atlas}/template_mask.nii.gz -o ${folder_atlas}/segmented.nii.gz
fslmaths ${folder_atlas}/segmented.nii.gz -thr 1 -uthr 1 ${folder_atlas}/csf_mask
##Multiply CSF mask by overall brain mask to keep only useful range (head-food)
fslmaths ${folder_atlas}/template_mask_common.nii.gz -mul ${folder_atlas}/csf_mask ${folder_atlas}/csf_mask
##Create a no-CSF mask by removing CSF mask from overall mask
fslmaths ${folder_atlas}/template_mask_common.nii.gz -sub ${folder_atlas}/csf_mask ${folder_atlas}/csf_removed_mask
cp ${folder_atlas}/csf_removed_mask ${folder_atlas}/mask_no_csf