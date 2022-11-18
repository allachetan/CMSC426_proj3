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
    
    LocalWindows = getLocalWindows();

    ColorModels = getShapeModels(maskSize, LocalWindows, ColorConfidences,...
        window_d_matrices, WindowWidth, SigmaMin, A, fcutoff, R);
   
    mask = getMask(ColorModels,ShapeConfidences);
    
    
end

function models = getShapeConfidences()
    %updating the shape confidences by recalculating it with the new color
    %confidences and windows
    models = initShapeConfidences(maskSize, LocalWindows, ColorConfidences, window_d_matrices, WindowWidth, SigmaMin, A, fcutoff, R);
end

function models = getShapeModels(maskSize, LocalWindows, ColorConfidences, window_d_matrices, WindowWidth, SigmaMin, A, fcutoff, R)
    %Encorporates the foreground mask and the new shape confidence 
end

function ColorModels = getColorModels(CurrentFrame, warpedMask, warpedMaskOutline,...
    NewLocalWindows, BoundaryWidth, WindowWidth, ColorModels)
    %need figure out how to apply old GMMS to new windows
    num_windows = size(NewLocalWindows);
    newColorModels = initializeColorModels(CurrentFrame, warpedMask, warpedMaskOutline, NewLocalWindows, BoundaryWidth, WindowWidth);

    %getting the masks for the windows
    oldMasks = getfield( ColorModels , "window_masks" );
    newMasks = getfield( newColorModels , "window_masks" );

    %getting the foreground GMMS
    oldFGMMS = getfield( ColorModels , "window_F_gmms" );
    newFGMMS = getfield( newColorModels , "window_F_gmms" );

    %getting the Background GMMS
    oldBGMMS = getfield( ColorModels , "window_B_gmms" );
    newBGMMS = getfield( newColorModels , "window_B_gmms" );

    updatedFGMMs = cell(1, num_windows);
    updatedBGMMs = cell(1, num_windows);
    updatedColorConf = cell(1, num_windows);
    %getting the forground prob matricies for old gmms on new windows
    p_c_matrices = applyColorModels(oldFGMMS,oldBGMMS, num_windows,...
        WindowWidth,Img,sigma_c,NewLocalWindows);
    for i = [1:num_windows(1)]
        oldArea = sum(oldMasks{i},"all");
        newArea = sum(newMasks{i},"all");
        if newArea > oldArea
            %newColorModels = setfield(ColorModels,"f_c_values",0);
            updatedFGMMs{i} = oldFGMMS{i};
            updatedBGMMs{i} = oldBGMMS{i};
            %updatedColorConf = oldconfidence
        else
            updatedFGMMs{i} = newFGMMS{i};
            updatedBGMMs{i} = newBGMMS{i};
            %recompute color confidence values
            %updatedColorConf = getColorConfidenceValue();
        end
    end
    %figure out how to compare the areas between the two models
    %if newcolormodel area <= old colormodel area then recompute color
    %confidence values
    ColorModels = struct('window_F_gmms', {updatedFGMMs},...
        'window_B_gmms', {updatedBGMMs},...
        'f_c_values', {updatedColorConf},...
        'window_masks', {window_masks});
end

function masks = applyColorModels(FGMMs,BGMMs, num_windows,WindowWidth,...
    Img,sigma_c,LocalWindows)

    window_p_c_matrices = cell(1, num_windows);
    for i=1:num_windows
        center = LocalWindows(i,:);
        center = [center(2) center(1)];
        window = zeros(WindowWidth, WindowWidth, 3);
        window = Img(startRow:endRow,startCol:endCol, :);
        startRow = max([1, center(1) - sigma_c]);
        endRow = (min([sz(1), center(1) + sigma_c])); 
        for row=1:WindowWidth
                for col=1:WindowWidth                    
                    curr_pixel = squeeze(window(row, col, :))';                     
                    p_F_gmm = pdf(F_gmm, curr_pixel);
                    p_B_gmm = pdf(B_gmm, curr_pixel);
                    window_p_c_matrix(row, col) = p_F_gmm / (p_F_gmm + p_B_gmm);
                end
        end
        window_p_c_matrices{i} = window_p_c_matrix;
    end
    masks = window_p_c_matrices;
end

function confidences = getColorConfidenceValue(wind_num,window_p_c_matrix)    
    window_w_c_matrix = w_c_matrix(startRow:endRow,startCol:endCol);
    window_mask = Mask(startRow:endRow,startCol:endCol);
    window_d_matrix = d_matrix(startRow:endRow,startCol:endCol);

    up = sum(abs(window_mask - window_p_c_matrix) .* window_w_c_matrix);
    down = sum(window_w_c_matrix);
    f_c = 1 - up/down;    
end

%not sure how I am supposed to update the local windows
function windows = getLocalWindows(WindowWidth,LocalWindows)
    
end
function mask = getMask(ColorModels,ShapeConfidences,NewLocalWindows)
    
end

