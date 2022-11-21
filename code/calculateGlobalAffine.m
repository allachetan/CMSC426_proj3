
function [WarpedFrame, WarpedMask, WarpedMaskOutline, WarpedLocalWindows] = calculateGlobalAffine(IMG1,IMG2,Mask,Windows)
% CALCULATEGLOBALAFFINE: finds affine transform between two frames, and applies it to frame1, the mask, and local windows.

% Detects feature in both frames (maybe add vision. before the sift feat)
im1Features  = detectSIFTFeatures(rgb2gray(IMG1), Sigma = 0.5);
im2Features = detectSIFTFeatures(rgb2gray(IMG2), Sigma = 0.5);
% 
% im1Features = im1Features.selectStrongest(20);
% im2Features = im2Features.selectStrongest(20);



[ogFeatures,validim1Features] = extractFeatures(rgb2gray(IMG1),im1Features);

[distFeatures,validim2Features] = extractFeatures(rgb2gray(IMG2),im2Features);

% matches features between frames
A = (matchFeatures(ogFeatures,distFeatures));
% index_pairs = index_pairs(1:20,:);

n = ceil(size(A, 1)/2);
B = A(1:n,:);
C = A(n+1:end,:);



k = randperm(size(B, 1));

new_indB = B(k(1:15),:);
new_indC = C(k(1:15),:);

new_ind = [new_indB;new_indC];


matchedim1Features  = validim1Features(new_ind(:,1));
matchedim2Features = validim2Features(new_ind(:,2));

showMatchedFeatures(IMG1,IMG2,matchedim1Features,matchedim2Features);

% 
% figure 
% 
% showMatchedFeatures(IMG1,IMG2,matchedim1Features,matchedim2Features)
% title('Matched SURF Points With Outliers');

[tform,inlierIdx] = estimateGeometricTransform(matchedim2Features,matchedim1Features,'affine');
% 
% outputView = imref2d(size(original));
% Ir = imwarp(distorted,tform,'OutputView',outputView);
% figure 
% imshow(Ir); 
% title('Recovered Image');
% 


% figure 
% showMatchedFeatures(original,distorted,inlierim1Features,inlierim2Features)
% title('Matched Inlier Points')


% applies affine transformation to first frame 
[WarpedFrame, RA] = imwarp(IMG1, tform, OutputView=imref2d(size(IMG1)));

[WarpedMask, RB] = imwarp(Mask, tform, OutputView=imref2d(size(Mask)));

WarpedMaskOutline = bwperim(WarpedMask,4);

% WarpedLocalWindows = imwarp(Windows, tform, OutputView=imref2d(size(Windows)));    
WarpedLocalWindows = inlierIdx.Location;




end