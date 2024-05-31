function [invariants] = QTIPlus(path, subject)
    addpath('../NIfTI_20140122/');
    addpath(genpath('/Users/sharada/Documents/GitHub/QTIPlus/'));

    %Testing out using QTI+ on my data
    %Just change the subject name
    %Requires brain mask from bet
    %subject = {'REPRO_C05'};

    % load the data and the experimental parameters (xps) and brain mask
    data_filename = [path , subject , '/MDD/processed/FWF_mc.nii.gz'];
    xps_filename = [path , subject, '/MDD/processed/FWF_mc_xps.mat'];
    mask_filename = [path , subject, '/MDD/Inputs/mask.nii.gz'];
    data = niftiread(data_filename);
    load(xps_filename);
    mask = niftiread(mask_filename);

    % extract the b-tensors from the xps structure
    btens = xps.bt;


    % fit the various protocols with SDP(dcm)
    % use the 'ind' keyword to specify which volumes to use for the fit
    % use the 'pipeline' keyword to specify which steps of the QTI+ framemork
    % to perform
    % use the 'mask' keyword to pass the mask to the function                                                                                                                                              
    [model, invariants] = qtiplus_fit(data, btens,...
                                       'mask', mask, ...
                                       'pipeline', 0);

    
                                    
    %Available metrics are: MD, RD, AD, V_iso, V_shear, V_MD, C_MD, C_mu, C_M, C_c, uFA, OP2, OP, K_bulk, K_shear, K_mu, MK, MKt
    %Might as well rerun and get all? Or at least DTI ones, C_, K_, uFA.

    %%%%%%%Conventional DTI
    %FA                                   
    fa = make_nii(invariants.FA);
    fa_filename = [path, subject, '/MDD/processed/qti_fa.nii'];
    save_nii(fa, fa_filename);

    %AD
    ad = make_nii(invariants.AD);
    ad_filename = [path, subject, '/MDD/processed/qti_ad.nii'];
    save_nii(ad, ad_filename);

    %RD
    rd = make_nii(invariants.RD);
    rd_filename = [path, subject, '/MDD/processed/qti_rd.nii'];
    save_nii(rd, rd_filename);

    %MD
    md = make_nii(invariants.MD);
    md_filename = [path, subject, '/MDD/processed/qti_md.nii'];
    save_nii(md, md_filename);

    %%%%%%%%%Measures from Covariance tensor
    %C_MD
    c_md = make_nii(invariants.C_MD);
    c_md_filename = [path, subject, '/MDD/processed/qti_c_md.nii'];
    save_nii(c_md, c_md_filename);

    %C_c
    c_c = make_nii(invariants.C_c);
    c_c_filename = [path, subject, '/MDD/processed/qti_c_c.nii'];
    save_nii(c_c, c_c_filename);

    %C_mu
    c_mu = make_nii(invariants.C_mu);
    c_mu_filename = [path, subject, '/MDD/processed/qti_c_mu.nii'];
    save_nii(c_mu, c_mu_filename);

    %uFA
    ufa = make_nii(invariants.uFA);
    ufa_filename = [path, subject, '/MDD/processed/qti_ufa.nii'];
    save_nii(ufa, ufa_filename);

    %OP 
    op = make_nii(invariants.OP);
    op_filename = [path, subject, '/MDD/processed/qti_op.nii'];
    save_nii(op, op_filename);

    %MK
    mk = make_nii(invariants.MK);
    mk_filename = [path, subject, '/MDD/processed/qti_mk.nii'];
    save_nii(mk, mk_filename);

    %K_bulk
    kbulk = make_nii(invariants.K_bulk);
    kbulk_filename = [path, subject, '/MDD/processed/qti_kbulk.nii'];
    save_nii(kbulk, kbulk_filename);

    %K_shear
    kshear = make_nii(invariants.K_shear);
    kshear_filename = [path, subject, '/MDD/processed/qti_kshear.nii'];
    save_nii(kshear, kshear_filename);

    %K_mu
    kmu = make_nii(invariants.K_mu);
    kmu_filename = [path, subject, '/MDD/processed/qti_kmu.nii'];
    save_nii(kmu, kmu_filename);

end