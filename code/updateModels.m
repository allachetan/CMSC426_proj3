function [mask, LocalWindows, ColorModels, ShapeConfidences] = ...
   updateModels(...
       NewLocalWindows, ... %windows calculated from opt flow for this frame
       LocalWindows, ... %windows from prev frame
       CurrentFrame, ... %my guess is that this is frame at t+1
       warpedMask, ...
       warpedMaskOutline, ...
       WindowWidth, ... 
       ColorModels, ... 
       ShapeConfidences, ... %shape confidence per window
       ProbMaskThreshold, ... %combined color and shape confidence from prev frame
       fcutoff, ... %??? forground cutoff?
       SigmaMin, ... %minimum variance the window can have? ( we want small variance)
       R, ... %param used to update sigma
       A ... %param used to update sigma
   )
   BoundaryWidth = 5;
  
   LocalWindows = round(NewLocalWindows);
  
   NewColorModels = getColorModels(CurrentFrame, warpedMask, warpedMaskOutline,...
            LocalWindows, BoundaryWidth, WindowWidth, ColorModels);  

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SHAPE MODEL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   ColorConfidences = ColorModels.f_c_values;
   window_d_matrices = ColorModels.window_d_matrices; 
   NewShapeConfidences = initShapeConfidences(size(warpedMask), LocalWindows, ColorConfidences,...
       window_d_matrices, WindowWidth, SigmaMin, A, fcutoff, R);
    
   mask = getMask(NewColorModels,NewShapeConfidences,LocalWindows,...
       warpedMask,WindowWidth,CurrentFrame, LocalWindows, ProbMaskThreshold);
   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Local Windows %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   [~, LocalWindows] = initLocalWindows(CurrentFrame, mask, ...
 %      size(LocalWindows,1), WindowWidth, false);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% COLOR MODEL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%This is the main function that updates the color models for the current
%frame. It is tasked with
%1) Calculating the new color models for the current frame
%2) Determining if the new color model is better than the old one for each
%   window 
function ColorModels = getColorModels(Img, warpedMask, warpedMaskOutline,...
   LocalWindows, BoundaryWidth, WindowWidth, oldColorModels)
   %%%% Hyper Parameter %%%%
   threshold = .5;   

   %Getting color models for the current frame
   newColorModels = initColorModels(Img, warpedMask, ...
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
   for i = 1:num_windows
       center = LocalWindows(i,:);
       %getting the forground pixel count for each model set
       oldCount = foregroundPixelCount(Img,center,oldBGMMS{i},oldFGMMS{i},threshold,WindowWidth,sz); 
       newCount = foregroundPixelCount(Img,center,newBGMMS{i},newFGMMS{i},threshold,WindowWidth,sz);
       %if the old models have a smaller area use the old models and color confidence
       if newCount > oldCount
           updatedFGMMs{i} = oldFGMMS{i};
           updatedBGMMs{i} = oldBGMMS{i};
           updatedColorConf{i} = oldColorConf{i};
       else
           updatedFGMMs{i} = newFGMMS{i};
           updatedBGMMs{i} = newBGMMS{i};           
           updatedColorConf{i} = newColorConf{i};
       end
   end
   ColorModels = struct( 'window_F_gmms', {updatedFGMMs},...
       'window_B_gmms', {updatedBGMMs},...
       'f_c_values', {updatedColorConf},...
       'window_d_matrices', {newColorModels.window_d_matrices});
end

function count = foregroundPixelCount(Img,center,B_GMM,F_GMM,threshold,WindowWidth,sz)          
    win_pc = applyColorModels(Img,center,B_GMM,F_GMM,WindowWidth,sz);
    count = sum(win_pc>=threshold,"all"); 
end

function win_pc = applyColorModels(Img,center,B_gmm,F_gmm,WindowWidth,sz)
    sigma_c = round(WindowWidth / 2);    
    startRow = max([1, center(1) - sigma_c]);% added min/max to avoid out of range at image edges.
    endRow = (min([sz(1), center(1) + sigma_c]));
    startCol = max([1, center(2) - sigma_c]);
    endCol = min([sz(2), center(2) + sigma_c]);   
    
    window = Img(startRow:endRow,startCol:endCol, :);

%     A = reshape(window,[size(window,1)*size(window,2) 3]); 
%     try %for some unknown reason F_gmm and B_gmm return multiple cells of GMM dists (so i just use the first one given)
%     p_F_gmm = pdf(F_gmm, A);
%     p_B_gmm = pdf(B_gmm, A);    
%     catch
%     p_F_gmm = pdf(F_gmm{1}, A);
%     p_B_gmm = pdf(B_gmm{1}, A); 
%     end   
%     p_F_gmm = reshape(p_F_gmm,[size(window,1) size(window,2)]);
%     p_B_gmm = reshape(p_B_gmm,[size(window,1) size(window,2)]);
%     
%     win_pc = p_F_gmm./(p_F_gmm+p_B_gmm);
    windowSize = size(window);
    win_pc = zeros(windowSize(1),windowSize(2));
    for row=1:windowSize(1)
       for col=1:windowSize(2)
           curr_pixel = transpose(double(squeeze(window(row, col, :))));
           curr_pixel = curr_pixel./255;
           try
               p_F_gmm = pdf(F_gmm, curr_pixel);
               p_B_gmm = pdf(B_gmm, curr_pixel);
           catch
               p_F_gmm = pdf(F_gmm{1}, curr_pixel);
               p_B_gmm = pdf(B_gmm{1}, curr_pixel);
           end                     
           win_pc(row,col) = p_F_gmm / (p_F_gmm + p_B_gmm);           
       end
    end        
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MASK %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function mask = getMask(ColorModels,ShapeConfidences,NewLocalWindows,warpedMask,WindowWidth,Img, LocalWindows, ProbMaskThreshold)
   fs = ShapeConfidences;
   num_windows = size(NewLocalWindows,1);   
   sigma_c = round(WindowWidth / 2);      
   sz = size(warpedMask);
   pF = [];
   mask = zeros(size(Img,1),size(Img,2));

   mergeLocalWindowsTop = zeros(size(Img(:, :, 1)));
   mergeLocalWindowsBot = zeros(size(Img(:, :, 1)));
   %Need to segment the warpedMask because it gives the mask for the entire frame and
   %not just for the individual windows
   for i = 1:num_windows
       center = NewLocalWindows(i,:);
       center = [center(2) center(1)];
       startRow = max([1, center(1) - sigma_c]);% added min/max to avoid out of range at image edges.
       endRow = (min([sz(1), center(1) + sigma_c]));
  
       startCol = max([1, center(2) - sigma_c]);
       endCol = min([sz(2), center(2) + sigma_c]);
  
       L = warpedMask(startRow:endRow,startCol:endCol, :);       
       pC = applyColorModels(Img,center,ColorModels.window_B_gmms,ColorModels.window_F_gmms,WindowWidth,sz);   
       currWindow = fs{i}.*L + (1-fs{i}).*pC;   
       mask(startRow:endRow,startCol:endCol, :) = currWindow >= ProbMaskThreshold;
       pF = [pF ; currWindow ];

       x = repmat(1:ceil(WindowWidth/2)*2 + 1, ceil(WindowWidth/2)*2 + 1, 1);
       y = repmat(transpose(ceil(WindowWidth/2)*2 + 1:-1:1), 1, ceil(WindowWidth/2)*2 + 1);
       c = [ceil(WindowWidth/2) ceil(WindowWidth/2)];
       centerDistanceMatrix = sqrt((y - c(1)) .^ 2 + (x - c(2)) .^ 2) + 0.1;
       invCenterDistanceMatrix = 1./centerDistanceMatrix;
 
       xl = center(1) - ceil(WindowWidth/2);
       xr = center(1) + ceil(WindowWidth/2);
       yl = center(2) - ceil(WindowWidth/2);
       yr = center(2) + ceil(WindowWidth/2);
       mergeLocalWindowsTop(xl:xr, yl:yr) = mergeLocalWindowsTop(xl:xr, yl:yr) + currWindow .* invCenterDistanceMatrix;
       mergeLocalWindowsBot(xl:xr, yl:yr) = mergeLocalWindowsBot(xl:xr, yl:yr) + invCenterDistanceMatrix;
   end   
   mergedLocalWindows = mergeLocalWindowsTop./mergeLocalWindowsBot;
   mask = mergedLocalWindows > 0.9;
   mask = imfill(mask, 'holes');
   mask = bwareaopen(mask, 25);
   [maskOutline, LocalWindows] = initLocalWindows(Img, mask, length(LocalWindows(:,1)), WindowWidth, false);
   mask = imfill(maskOutline, 'holes');
   imshow(mask)
end
