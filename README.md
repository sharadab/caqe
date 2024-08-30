# CAQE
Clustering for Anatomical Quantification and Evaluation (CAQE)

Code supporting the paper "Microstructure-informed brain tissue classification using clustering of quantitative magnetic resonance imaging measures". The atlas of tissue classification and classifier model can be found at: https://zenodo.org/records/11399015.

The "processing" folder contains code that assumes myelin water imaging data has already been processed. It contains code to process tensor-valued diffusion data from PAR/REC format, register myelin water imaging and diffusion data, and create CSF masks.
It also contains code to create metric atlases, and warp the atlas of tissue classification (once it is made) to each MS subject.

There are several Jupyter notebooks for different purposes that can be used after initial processing:
- training.ipynb: helps determine the optimal number of clusters and save classifiers.

- testing.ipynb: runs the optimal classifier on MS data to classify MS tissue, and on the metric atlases to create the atlas of tissue classification.

- metric_stats.ipynb: calculates the mean metric values in each cluster, in each person.

- cluster_stats.ipynb: calculates the cluster sizes of each cluster in each person.

- difference_maps.ipynb: creates white matter difference maps between each MS subject and the atlas of tissue classification, and calculates severity scores for each person.

- dataset_pca.ipynb: used to assess the overall healthy dataset to see if metrics are largely complemenetary or if any are redundant.

Requires:
- https://github.com/avdvorak/CALIPR for converting myelin water imaging data into myelin water fraction maps.
- https://github.com/markus-nilsson/md-dmri for some of the tensor-valued diffusion image processing.
- https://github.com/ElsevierSoftwareX/SOFTX-D-21-00175 for converting tensor-valued diffusion images into metric maps.
- MRTrix3, ANTs, FSL for some image pre-processing and registration.
- scikit-fuzzy, sklearn and skops for clustering, classification and saving models.
- NiBabel, NumPy, pandas, seaborn, matplotlib for general use.
