function [s_mc] = MDD_setup(path, subject)

    addpath(genpath('/Users/sharada/Documents/GitHub/MD-DMRI/'));

    %ps = define_paths(subject); %Get the names of files/folders that we will use


    %Set up folder details
    ps.bp = [path,subject,'/MDD/']
    ps.ip = fullfile(ps.bp, 'Inputs'); % <- actual input data
    ps.op = fullfile(ps.bp, 'processed/'); % <- store output here
    ps.zp = fullfile(ps.bp, 'tmp'); % <- store temporary files here

    if ((~exist(ps.bp, 'dir')) || ...
            (~exist(ps.ip, 'dir')))
        error('Data not found at specified folder. See instructions in header.')
    end

    msf_mkdir(ps.op); 
    msf_mkdir(ps.zp); 

    %Set up some basic options
    opt = mdm_opt;
    opt.do_overwrite = 1;
    opt.do_verbose = 1;

    b_delta_lte = 1; %These are sort of identifiers, but the value comes from how they define tensor shapes! See Topgaard 2017.
    b_delta_ste = 0;
    b_delta_pte = -0.5;

    %Load linear, planar and spherical data
    f = @(nii_fn, b_delta) mdm_s_from_nii(fullfile(ps.ip, nii_fn), b_delta); 

    %Build filenames based on subject name
    ste_filename = ['STE.nii.gz'] %['MDDE_', subject, '_STE.nii.gz']
    pte_filename = ['PTE.nii.gz'] %['MDDE_', subject, '_PTE.nii.gz']
    lte_filename = ['LTE.nii.gz'] %['MDDE_', subject, '_LTE.nii.gz']

    %This creates a cellarray of length=number of entries here.
    %Each element of s has an nii_fn and xps (structs)
    %xps also contains the tensor form of the tensor shapes we put in (I think)
    s = {...
        f(ste_filename, b_delta_ste), ...
        f(pte_filename, b_delta_pte), ...
        f(lte_filename, b_delta_lte), ...
        };

    s = mdm_s_merge(s, ps.op, 'FWF', opt); %Merge all these structs in s into a new s, save it as 'FWF.nii'

    %Now load in that saved FWF.nii (the merged and interleaved version)
    s = mdm_s_from_nii(fullfile(ps.op, 'FWF.nii.gz'));

    %Do motion correction 
    %Elastix is for non-rigid/rigid registration. Requires it to be downloaded
    %and installed separately! This was painful on Mac.
    p_fn = elastix_p_write(elastix_p_affine(200), fullfile(ps.op, 'p.txt'));
    s_mc = mdm_s_mec(s, p_fn, ps.op, opt);

end


