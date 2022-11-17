function [mask, LocalWindows, ColorModels, ShapeConfidences] = ...
    updateModels(...
        NewLocalWindows, ... %windows calculated from opt flow for this frame
        LocalWindows, ... %windows from prev frame
        CurrentFrame, ... %my guess is that this is frame at t+1
        warpedMask, ...
        warpedMaskOutline, ...
        WindowWidth, ... %width of windows (duh)
        ColorModels, ... %N*2 color models (foreground and background for each window)
        ShapeConfidences, ... %shape confidence per window
        ProbMaskThreshold, ... %combined color and shape confidence from prev frame
        fcutoff, ... %??? forground cutoff?
        SigmaMin, ... %minimum variance the window can have? ( we want small variance)
        R, ... %param used to update sigma
        A ... %param used to update sigma
    )
% UPDATEMODELS: update shape and color models, and apply the result to generate a new mask.
% Feel free to redefine this as several different functions if you prefer.
    if(fc > fcutoff)
       sigma = SigmaMin + A*((fc - fcutoff)^R);    
    end
    d = bwdist(ProbMaskThreshold);
    LocalWindows = getLocalWindows();

    ColorModels = getShapeModels(maskSize, LocalWindows, ColorConfidences,...
        window_d_matrices, WindowWidth, SigmaMin, A, fcutoff, R);
   
    mask = getMask(ColorModels,ShapeConfidences);
    
end

function models = getShapeModels(maskSize, LocalWindows, ColorConfidences, window_d_matrices, WindowWidth, SigmaMin, A, fcutoff, R)
    models = initShapeConfidences(maskSize, LocalWindows, ColorConfidences, window_d_matrices, WindowWidth, SigmaMin, A, fcutoff, R);
end

function models = getColorModels(ColorModels,warpedMask,warpedMaskOutline)
    FG_Theshold = .75;
    BG_Theshold = .25;
    %call the initializeColorModels method? fitgmdist
    
end

function windows = getLocalWindows(WindowWidth,LocalWindows)
    
end
function mask = getMask(ColorModels,ShapeConfidences,NewLocalWindows)
    
end

