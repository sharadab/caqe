#!/bin/bash

#################################################################################
## This shows an example pipeline on a set of sample data, starting with data in
## PARREC format (NIFTI for CALIPR). Note that at the beginning, there are only 
## 2 folders: CALIPR and PARREC. The CALIPR folder contains data that was already processed using 
## the pipeline in https://github.com/avdvorak/CALIPR which includes consolidating 
## 56 echoes of the T2 decay curve, creating a MWF map and brain extraction.
## The PARREC folder contains data in PAR/REC format.
#################################################################################

#List of subjects to process one by one
declare -a subjectlist=("SAMPLE")

#Folder where subjects will each have sub-folders
main_folder="/Users/sharada/Documents/Projects/MDDE/V3/SAMPLE"

#Folder where processing scripts live
script_folder="/Users/sharada/Documents/GitHub/caqe/processing"

## Make diffusion metric maps from QTI+, do some MWI logistics, register images together, create CSF mask.
for subject in "${subjectlist[@]}"; do
## For healthy subjects.
bash ${script_folder}/initial_processing_hc.sh -p ${main_folder} -s ${subject}

## The same but for MS (the difference is in how CSF masking is done)
#bash ${script_folder}/initial_processing_ms.sh -p ${main_folder} -s ${subject}
done

## Create metric atlases (i.e. atlases of MWF, µFA, C_MD) from the healthy subjects. 
## Input the list of healthy subjects into subjects.txt. At the moment it has placeholder names.
bash metric_atlas_creation.sh -p ${main_folder} -f subjects.txt


## Once the atlas of tissue classification is made (see Jupyter notebooks on training and testing), warp 
## the atlas of tissue classification to each MS subject to later create difference maps.
for subject in "${subjectlist[@]}"; do
bash ${script_folder}/atlas_warp.sh -p ${main_folder} -s ${subject}
done

