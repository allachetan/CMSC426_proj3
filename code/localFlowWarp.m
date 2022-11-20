function [NewLocalWindows] = localFlowWarp(WarpedPrevFrame, CurrentFrame, LocalWindows, Mask, Width)
% LOCALFLOWWARP Calculate local window movement based on optical flow between frames.

% TODO
opticFlow = opticalFlowHS;


roi_im1 = double(im2gray(WarpedPrevFrame));
roi_im2 = double(im2gray(CurrentFrame));

% roi_im1(Mask == 0) = 0;
% roi_im2(Mask == 0) = 0;
roi_im1 = roi_im1.*Mask;
roi_im2 = roi_im2.*Mask;

images = [roi_im1, roi_im2];
flow = 0;

for i = 1:2
    frameGray = im2gray(images(i));  
    flow = estimateFlow(opticFlow,frameGray);
end


flow_vect = [flow.Vx, flow.Vy];

NewLocalWindows = zeros(size(LocalWindows));

for i = 1:size(LocalWindows,1) 
    NewLocalWindows(i, 1) = LocalWindows(i, 1) + flow_vect(1);
    NewLocalWindows(i, 2) = LocalWindows(i, 2) + flow_vect(2);
end

end



