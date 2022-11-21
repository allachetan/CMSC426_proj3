% MyRotobrush.m  - UMD CMSC426, Fall 2018
% This is the main script of your rotobrush project.
% We've included an outline of what you should be doing, and some helful visualizations.
% However many of the most important functions are left for you to implement.
% Feel free to modify this code as you see fit.

% Some parameters you need to tune:
WindowWidth = 80;  
ProbMaskThreshold = .5; %need to look at the paper to see what to set this to
NumWindows= 30; 
BoundaryWidth = 5;


% Load images:
fpath = '../input';
files = dir(fullfile(fpath, '*.jpg'));
imageNames = zeros(length(files),1);
images = cell(length(files),1);

for i=1:length(files)
    imageNames(i) = str2double(strtok(files(i).name,'.jpg'));
end


imageNames = sort(imageNames);
imageNames = num2str(imageNames);
imageNames = strcat(imageNames, '.jpg');

for i=1:length(files)
    images{i} = im2double(imread(fullfile(fpath, strip(imageNames(i,:)))));
end
img = imread("../input/2.jpg");
images{1} = img;

% NOTE: to save time during development, you should save/load your mask rather than use ROIPoly every time.
% mask = roipoly(images{1});
mask = im2bw(imread("../input/Mask1.png"));

im_copy = images{1};

B = imoverlay(im_copy, boundarymask(mask,8),'red');

imshow(B);

set(gca,'position',[0 0 1 1],'units','normalized')
F = getframe(gcf);
[I,~] = frame2im(F);
imwrite(I, fullfile(fpath, strip(imageNames(1,:))));
try
    close(outputVideo);
catch
end
outputVideo = VideoWriter(fullfile(fpath,'video.mp4'),'MPEG-4');
open(outputVideo);
writeVideo(outputVideo,I);

% Sample local windows and initialize shape+color models:
[mask_outline, LocalWindows] = initLocalWindows(images{1},mask,NumWindows,WindowWidth,true);

ColorModels = ...
    initColorModels(images{1},mask,mask_outline,LocalWindows,BoundaryWidth,WindowWidth);

% You should set these parameters yourself:
fcutoff = 0.2;
SigmaMin = 20;
SigmaMax = WindowWidth + 1;
R = 2;
A = (SigmaMax - SigmaMin) / (1 - fcutoff)^R;


ColorConfidences = ColorModels.f_c_values;
window_d_matrices = ColorModels.window_d_matrices;

ShapeConfidences = initShapeConfidences(size(mask), LocalWindows,...
ColorConfidences, window_d_matrices, WindowWidth, SigmaMin, A, fcutoff, R);



% Show initial local windows and output of the color model:
imshow(images{1})
hold on
showLocalWindows(LocalWindows,WindowWidth,'r.');
hold off
set(gca,'position',[0 0 1 1],'units','normalized')
F = getframe(gcf);
[I,~] = frame2im(F);

showColorConfidences(images{1},mask_outline,ColorConfidences,LocalWindows,WindowWidth);

%%% MAIN LOOP %%%
% Process each frame in the video.
for prev=1:(length(files)-1)
    curr = prev+1;
    fprintf('Current frame: %i\n', curr)
    
    %%% Global affine transform between previous and current frames:
    [warpedFrame, warpedMask, warpedMaskOutline, warpedLocalWindows] = ...
        calculateGlobalAffine(images{prev}, images{curr}, mask, LocalWindows);
    
    %%% Calculate and apply local warping based on optical flow:
    NewLocalWindows = ...
        localFlowWarp(warpedFrame,images{curr},warpedLocalWindows,warpedMask,WindowWidth);
    
    NewLocalWindows = ceil(NewLocalWindows);
    paintZerosWithWindowMasks(warpedMask, round(NewLocalWindows), WindowWidth);
    % Show windows before and after optical flow-based warp:
    imshow(images{curr});
    hold on
%     showLocalWindows(LocalWindows,WindowWidth,'r.');
    showLocalWindows(NewLocalWindows,WindowWidth,'b.');
    hold off
    
    %%% UPDATE SHAPE AND COLOR MODELS:
    % This is where most things happen.
    % Feel free to redefine this as several different functions if you prefer.
    [ ...
        mask, ...
        LocalWindows, ...
        ColorModels, ...
        ShapeConfidences ...
    ] = ...
    updateModels(...
        NewLocalWindows, ...
        LocalWindows, ...
        images{curr}, ...
        warpedMask, ...
        warpedMaskOutline, ...
        WindowWidth, ...
        ColorModels, ...
        ShapeConfidences, ...
        ProbMaskThreshold, ... 
        fcutoff, ... 
        SigmaMin, ...
        R, ... 
        A);

    mask_outline = bwperim(mask,4);

    % Write video frame:
    imshow(imoverlay(images{curr}, boundarymask(mask,8), 'red'));
    set(gca,'position',[0 0 1 1],'units','normalized')
    F = getframe(gcf);
    [I,~] = frame2im(F);
    imwrite(I, fullfile(fpath, strip(imageNames(curr,:))));
    writeVideo(outputVideo,I);

    imshow(images{curr})
    hold on
    showLocalWindows(LocalWindows,WindowWidth,'r.');
    hold off
    set(gca,'position',[0 0 1 1],'units','normalized')
    F = getframe(gcf);
    [I,~] = frame2im(F);
end

close(outputVideo);









function paintZerosWithWindowMasks(Mask, LocalWindows, WindowWidth)
        sz = size(Mask);
        image_painted = zeros(sz);
        num_windows = length(LocalWindows);
        sigma_c = round(WindowWidth / 2); % half window size
        figure;

        for i=1:num_windows
            center = LocalWindows(i,:);
            center = [center(2) center(1)]; % make it center(row, col)

            % below is just for the illustration after the loop.
            center = LocalWindows(i,:);
            center = [center(2) center(1)]; % make it center(row, col)
    

            startRow = max([1, center(1) - sigma_c]);% added min/max to avoid out of range at image edges.
            endRow = (min([sz(1), center(1) + sigma_c])); 
    
            startCol = max([1, center(2) - sigma_c]);
            endCol = min([sz(2), center(2) + sigma_c]);

            window_mask = Mask(startRow:endRow,startCol:endCol);
            for row=1:WindowWidth
                for col=1:WindowWidth
                    image_painted(row + startRow - 1, col + startCol - 1) = window_mask(row, col) + 0.5;
                end
            end
            imshow(image_painted);

        end
end