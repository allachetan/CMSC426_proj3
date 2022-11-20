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
%     if(fc > fcutoff)
%        sigma = SigmaMin + A*((fc - fcutoff)^R);    
%     end
    
    LocalWindows = NewLocalWindows;
    BoundaryWidth = 5;
    ColorModels = getColorModels(CurrentFrame, warpedMask, warpedMaskOutline,...
    LocalWindows, BoundaryWidth, WindowWidth, ColorModels);   
    
    ShapeConfidences = getShapeConfidences(maskSize, LocalWindows, ColorConfidences,...
        window_d_matrices, WindowWidth, SigmaMin, A, fcutoff, R); %#ok<NASGU> 

    mask = getMask(ColorModels,ShapeConfidences,NewLocalWindows);
end

%%%%%%%%%%%%%%%%%%%%%%%% COLOR MODEL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%This is the main function that updates the color models for the current
%frame. It is tasked with 
%1) Calculating the new color models for the current frame 
%2) Determining if the new color model is better than the old one for each
%frame
%3) 
function ColorModels = getColorModels(CurrentFrame, warpedMask, warpedMaskOutline,...
    LocalWindows, BoundaryWidth, WindowWidth, oldColorModels)

    num_windows = size(LocalWindows);

    %Getting color models for the current frame
    newColorModels = initColorModels(CurrentFrame, warpedMask, ...
        warpedMaskOutline, LocalWindows, BoundaryWidth, WindowWidth);

    %getting the masks for the windows
%     oldMasks = getfield( oldColorModels , "window_masks" );
%     newMasks = getfield( newColorModels , "window_masks" );

    %getting the foreground GMMS
    oldFGMMS = oldColorModels.window_F_gmms;
    newFGMMS = newColorModels.window_F_gmms;

    %getting the Background GMMS
    oldBGMMS = oldColorModels.window_B_gmms;
    newBGMMS = newColorModels.window_B_gmms;

    oldColorConf = oldColorModels.f_c_values;
    newColorConf = newColorModels.f_c_values;
    
    %Initializing empty GMMs and color confidence cells to be filled in
    %with the correct (new vs old) data
    updatedFGMMs = cell(1, num_windows);
    updatedBGMMs = cell(1, num_windows);
    updatedColorConf = cell(1, num_windows);

    %getting the forground prob matricies for old gmms on new windows
    p_c_matrices = applyColorModels(oldFGMMS,oldBGMMS, num_windows,...
        WindowWidth,Img,sigma_c,LocalWindows);

    newForegroundPixelCount = newColorModels.f_pixel_count;
    %For each window calculate the number of foreground pixels for the new
    %and old models. If the new model has a an area <= old model then
    %update the GMMs to use the new model, else use the old model. If the
    %new model is used then you must update the corresponding confidences
    %for the new frame.
    sz = size(Mask);
    sigma_c = round(WindowWidth / 2);
    for i = 1:num_windows(1)
        center = LocalWindows(1,:);
        %getting the forground pixel count for each model set
        oldCount = foregroundPixelCount(center,sz,sigma_c,MaskWithBoundary,Mask);
        newCount = newForegroundPixelCount{i}(1);
        %if the old models have a smaller area use the old models and
        %color confidence
        if newCount > oldCount
            updatedFGMMs{i} = oldFGMMS{i};
            updatedBGMMs{i} = oldBGMMS{i};
            updatedColorConf = oldColorConf{i};
        else
            updatedFGMMs{i} = newFGMMS{i};
            updatedBGMMs{i} = newBGMMS{i};
            %recompute color confidence values
            updatedColorConf = newColorConf{i};%getColorConfidenceValue();
        end
    end
    %if newcolormodel area <= old colormodel area then recompute color
    %confidence values
    ColorModels = struct( ...
        'window_F_gmms', {updatedFGMMs},...
        'window_B_gmms', {updatedBGMMs},...
        'f_c_values', {updatedColorConf},...
        'window_masks', {window_masks});
end

function count = foregroundPixelCount(center,sz,sigma_c,MaskWithBoundary,Mask)
    % added min/max to avoid out of range at image edges.
    startRow = max([1, center(1) - sigma_c]);
    endRow = (min([sz(1), center(1) + sigma_c])); 

    startCol = max([1, center(2) - sigma_c]);
    endCol = min([sz(2), center(2) + sigma_c]);

    foreground_count = 0;
    for row=startRow:endRow
        for col=startCol:endCol
            % decide whether it is foreground or background
            isNotOnBoundry = MaskWithBoundary(row, col) == 0;
            isBackground = Mask(row, col) == 0;
            if(isNotOnBoundry)
                if(isBackground)
                    
                else
                   foreground_count = foreground_count + 1;                    
                end
            end
        end
    end
    count = foreground_count;
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

% function f_c = getColorConfidenceValue(window_mask,window_w_c_matrix,window_p_c_matrix)    
%     up = sum(abs(window_mask - window_p_c_matrix) .* window_w_c_matrix);
%     down = sum(window_w_c_matrix);
%     f_c = 1 - up/down;    
% end

%%%%%%%%%%%%%%%%%%%%%%%% SHAPE CONFIDENCE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function models = getShapeConfidences(maskSize, LocalWindows, ColorConfidences,...
        window_d_matrices, WindowWidth, SigmaMin, A, fcutoff, R)
    %updating the shape confidences by recalculating it with the new color
    %confidences and windows
    models = initShapeConfidences(maskSize, LocalWindows, ColorConfidences,...
        window_d_matrices, WindowWidth, SigmaMin, A, fcutoff, R);
end

function models = getShapeModels(maskSize, LocalWindows, ColorConfidences,...
    window_d_matrices, WindowWidth, SigmaMin, A, fcutoff, R)
    %Encorporates the foreground mask and the new shape confidence 
end

%%%%%%%%%%%%%%%%%%%%%%%% MASK %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function mask = getMask(ColorModels,ShapeConfidences,NewLocalWindows)
    
end

