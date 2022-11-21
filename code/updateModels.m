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
   BoundaryWidth = 5;
  
   LocalWindows = round(NewLocalWindows);
  
   ColorModels = getColorModels(CurrentFrame, warpedMask, warpedMaskOutline,...
            LocalWindows, BoundaryWidth, WindowWidth, ColorModels);  

   ColorConfidences = ColorModels.f_c_values;
   window_d_matrices = ColorModels.window_d_matrices;
   
   ShapeConfidences = initShapeConfidences(maskSize, LocalWindows, ColorConfidences,...
       window_d_matrices, WindowWidth, SigmaMin, A, fcutoff, R);

   mask = getMask(ColorModels,ShapeConfidences,NewLocalWindows,warpedMask,WindowWidth,CurrentFrame);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% COLOR MODEL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%This is the main function that updates the color models for the current
%frame. It is tasked with
%1) Calculating the new color models for the current frame
%2) Determining if the new color model is better than the old one for each
%frame
%3)
function ColorModels = getColorModels(CurrentFrame, warpedMask, warpedMaskOutline,...
   LocalWindows, BoundaryWidth, WindowWidth, oldColorModels)
   %%%% Hyper Parameter %%%%
   threshold = .75;   

   %Getting color models for the current frame
   newColorModels = initColorModels(CurrentFrame, warpedMask, ...
       warpedMaskOutline, LocalWindows, BoundaryWidth, WindowWidth);

   %getting the foreground GMMS
   oldFGMMS = oldColorModels.window_F_gmms;
   newFGMMS = newColorModels.window_F_gmms;
   %getting the Background GMMS
   oldBGMMS = oldColorModels.window_B_gmms;
   newBGMMS = newColorModels.window_B_gmms;
   %getting the Confidence values
   oldColorConf = oldColorModels.f_c_values;
   newColorConf = newColorModels.f_c_values;

   num_windows = size(LocalWindows)*[1;0];

   %Initializing empty GMMs and color confidence cells to be filled in
   %with the correct (new vs old) data
   updatedFGMMs = cell(1, num_windows);
   updatedBGMMs = cell(1, num_windows);
   updatedColorConf = cell(1, num_windows);
   
   %For each window calculate the number of foreground pixels for the new
   %and old models. If the new model has a an area <= old model then
   %update the GMMs to use the new model, else use the old model. If the
   %new model is used then you must update the corresponding confidences
   %for the new frame.
   sz = size(warpedMask);
   sigma_c = round(WindowWidth / 2);
   for i = 1:num_windows
       center = LocalWindows(i,:);
       %getting the forground pixel count for each model set
       oldCount = foregroundPixelCount(Img,center,oldBGMMS{i},oldFGMMS{i},threshold,WindowWidth,sz,sigma_c);
       newCount = foregroundPixelCount(Img,center,newBGMMS{i},newFGMMS{i},threshold,WindowWidth,sz,sigma_c);
       %if the old models have a smaller area use the old models and
       %color confidence
       if newCount > oldCount
           updatedFGMMs{i} = oldFGMMS{i};
           updatedBGMMs{i} = oldBGMMS{i};
           updatedColorConf{i} = oldColorConf{i};
       else
           updatedFGMMs{i} = newFGMMS{i};
           updatedBGMMs{i} = newBGMMS{i};
           %recomputed color confidence values
           updatedColorConf{i} = newColorConf{i};
       end
   end
   ColorModels = struct( ...
       'window_F_gmms', {updatedFGMMs},...
       'window_B_gmms', {updatedBGMMs},...
       'f_c_values', {updatedColorConf},...
       'window_d_matrices', {newColorModels.window_d_matrices});
end

function count = foregroundPixelCount(Img,center,B_GMM,F_GMM,threshold,WindowWidth,sz,sigma_c)       
   foreground_count = 0;
   win_pc = applyColorModels(Img,center,B_GMM,F_GMM,WindowWidth,sz,sigma_c);
   for i = 1:WindowWidth
       for j = 1:WindowWidth
           foreground_count = foreground_count + (win_pc >= threshold);
       end
   end
   count = foreground_count;
end

function win_pc = applyColorModels(Img,center,B_gmm,F_gmm,WindowWidth,sz,sigma_c)
   startRow = max([1, center(1) - sigma_c]);% added min/max to avoid out of range at image edges.
   endRow = (min([sz(1), center(1) + sigma_c]));
   startCol = max([1, center(2) - sigma_c]);
   endCol = min([sz(2), center(2) + sigma_c]);

   window = Img(startRow:endRow,startCol:endCol, :);
   win_pc = cell(WindowWidth);

   windowSize = size(window);
   for row=1:windowSize(1)
       for col=1:windowSize(2)
           curr_pixel = squeeze(window(row, col, :))';
           
           p_F_gmm = pdf(F_gmm, curr_pixel);
           p_B_gmm = pdf(B_gmm, curr_pixel);
                      
           win_pc(row,col) = p_F_gmm / (p_F_gmm + p_B_gmm);           
       end
   end        
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MASK %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function mask = getMask(ColorModels,ShapeConfidences,NewLocalWindows,warpedMask,WindowWidth,Img)
   fs = ShapeConfidences;
   num_windows = (size(NewLocalWindows))*[1;0];   
   sigma_c = round(WindowWidth / 2);
   pF = cell(1,num_windows);
   sz = size(warpedMask);
   %I think that I need to segment the warpedMask since it seems to be for
   %the entire frame and not just for the individual windows
   for i = 1:num_windows
       center = NewLocalWindows(i,:);
       startRow = max([1, center(1) - sigma_c]);% added min/max to avoid out of range at image edges.
       endRow = (min([sz(1), center(1) + sigma_c]));
  
       startCol = max([1, center(2) - sigma_c]);
       endCol = min([sz(2), center(2) + sigma_c]);
  
       L = warpedMask(startRow:endRow,startCol:endCol, :);       
       pC = applyColorModels(Img,center,ColorModels.window_B_gmms,ColorModels.window_F_gmms,WindowWidth,sz);

       pF(i) = fs{i}.*L + (1-fs{i}).*pC;
   end   
   mask = pF;
end

