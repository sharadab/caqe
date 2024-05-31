# CAQE

The code here assumes myelin water imaging data has already been processed. It contains code to process tensor-valued diffusion data from PAR/REC format, register myelin water imaging and diffusion data, and create CSF masks.

There is also code to create metric atlases, and warp the atlas of tissue classification (once it is made) to each MS subject.

Uses:
- https://github.com/avdvorak/CALIPR for converting myelin water imaging data into myelin water fraction maps
- https://github.com/markus-nilsson/md-dmri for some of the tensor-valued diffusion image processing
- https://github.com/ElsevierSoftwareX/SOFTX-D-21-00175 for converting tensor-valued diffusion images into metric maps
- MRTrix3, ANTs, FSL for diffusion image pre-processing and image registration.

There are a few processing shell scripts for different purposes:
- initial_processing_hc.sh and initial_processing_ms.sh: initial steps to convert PAR/REC diffusion data into metric maps, register myelin water imaging and diffusion data, and generate CSF masks for healthy controls (HC) and MS subjects. The difference for MS subjects lies in CSF masking.

- metric_atlas_creation.sh: creates metric atlases using the data from subjects listed in subjects.txt.

- atlas_warp.sh: once the atlas of tissue classification is created (see testing.ipynb), warp the atlas to each MS participant's MWI space to directly compare the atlas and the participant's tissue classifications.

See example_processing_usage.sh for examples of how these scripts can be used for processing data.


