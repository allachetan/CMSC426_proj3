function [NewLocalWindows] = localFlowWarp(WarpedPrevFrame, CurrentFrame, LocalWindows, Mask, Width)
% LOCALFLOWWARP Calculate local window movement based on optical flow between frames.

% TODO
opticFlow = opticalFlowHS('Smoothness',0.5);


roi_im1 = im2double((WarpedPrevFrame));
roi_im2 = im2double((CurrentFrame));



% roi_im1(Mask == 0) = 0;
% roi_im2(Mask == 0) = 0;

% double() is causing issues. 
% roi_im1 = roi_im1.*Mask;
% roi_im2 = roi_im2.*Mask;

images{1} = roi_im1.*Mask;
images{2} = roi_im2;

imshow(images{1})

imshow(images{2})

% flow = 0;

% h = figure;
% movegui(h);
% hViewPanel = uipanel(h,'Position',[0 0 1 1],'Title','Plot of Optical Flow Vectors');
% hPlot = axes(hViewPanel);

% imshow(roi_im1)
% imshow(roi_im2)

flow_vect = [];

for i = 1:2
    frameGray = im2gray(images{i}); 
    imshow(frameGray)
    flow = estimateFlow(opticFlow,frameGray);

%     imshow(CurrentFrame)
%     hold on
%     plot(flow,'DecimationFactor',[5 5],'ScaleFactor',60,'Parent',hPlot);
%     hold off
%     pause(10^-3)
    flow_vect{1} = flow.Vx;
    flow_vect{2} = flow.Vy;

end




NewLocalWindows = zeros(size(LocalWindows));

for i = 1:size(LocalWindows,1) 
    NewLocalWindows(i, 1) = LocalWindows(i, 1) + mean(flow_vect{1}, 'all');
    NewLocalWindows(i, 2) = LocalWindows(i, 2) + mean(flow_vect{2}, 'all');
end

end



