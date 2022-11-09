function [WarpedFrame, WarpedMask, WarpedMaskOutline, WarpedLocalWindows] = calculateGlobalAffine(IMG1,IMG2,Mask,Windows)
% CALCULATEGLOBALAFFINE: finds affine transform between two frames, and applies it to frame1, the mask, and local windows.

% Detects feature in both frames 
im1Features  = detectSIFTFeatures(rgb2gray(IMG1));
im2Features = detectSIFTFeatures(rgb2gray(IMG2));

[ogFeatures,validim1Features] = extractFeatures(rgb2gray(IMG1),im1Features);

[distFeatures,validim2Features] = extractFeatures(rgb2gray(IMG2),im2Features);

% matches features between frames
index_pairs = matchFeatures(ogFeatures,distFeatures);

matchedim1Features  = validim1Features(index_pairs(:,1));
matchedim2Features = validim2Features(index_pairs(:,2));
% 
% figure 
% 
% showMatchedFeatures(IMG1,IMG2,matchedim1Features,matchedim2Features)
% title('Matched SURF Points With Outliers');

tform = estimateGeometricTransform(matchedim2Features,matchedim1Features,'affine');


% figure 
% showMatchedFeatures(original,distorted,inlierim1Features,inlierim2Features)
% title('Matched Inlier Points')

% applies affine transformation to first frame 
WarpedFrame = imwarp(IMG1,tform);

WarpedMask = imwarp(Mask, tform);

WarpedMaskOutline = bwperim(WarpedMask,4);

WarpedLocalWindows = imwarp(Windows);




    
end