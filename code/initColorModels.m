%{
%this is to illustrate how to use the 3 init files...
img = imread("../input/2.jpg");
mask = im2bw(imread("../input/Mask1.png"));
Num_windows = 20;
Window_width = 60;
[MaskOutline, LocalWindows] = initLocalWindows(img, mask, Num_windows, Window_width, true);
boundry_width = 4; 
colorModel = initializeColorModels(img, mask, MaskOutline, LocalWindows, boundry_width, Window_width)

ColorConfidences = colorModel.f_c_values;
window_d_matrices = colorModel.window_d_matrices;

% we specify these
SigmaMin = 20;
SigmaMax = Window_width + 1;
fcutoff = 0.2;  % from 0 to 1
R = 2;
A = (SigmaMax - SigmaMin) / (1 - fcutoff)^R;

ShapeConfidences = initShapeConfidences(size(mask), LocalWindows, ...
ColorConfidences, window_d_matrices, Window_width, SigmaMin, A, fcutoff, R);
%}

function ColorModels = initializeColorModels(Img, Mask, MaskOutline, LocalWindows, BoundaryWidth, WindowWidth)
% INITIALIZAECOLORMODELS Initialize color models.  ColorModels is a struct you should define yourself.
%
% Must define a field ColorModels.Confidences: a cell array of the color confidence map for each local window.
    d_matrix = bwdist(MaskOutline); % distances to the nearest pixel of the outline.
    sigma_c = round(WindowWidth / 2); % half window size
    sz = size(Mask);
    Img = im2double(Img); % necessary for fitgmdist
    w_c_matrix = zeros(sz); % weighing function
    MaskOutline_with_BoundaryWidth = zeros(sz);

    for row = 1:sz(1)
        for col = 1:sz(2)
            d_x = d_matrix(row, col);

            w_c_matrix(row, col) = exp(-1 * (d_x^2) / (sigma_c^2));

            if(d_x <= BoundaryWidth)
                MaskOutline_with_BoundaryWidth(row, col) = 1;
            end
        end
    end
    %{ 
    UNCOMMENT TO SHOW PLOTS
    figure
    imshow(MaskOutline)

    figure
    imshow(MaskOutline_with_BoundaryWidth)

    figure
    imshow(w_c_matrix)
    %}

    % for gmm models
    options = statset('MaxIter', 800);
    %{
    %%%% count pixels in background and pixels and foreground
    countB = 0;
    countF = 0;
    for row=1:sz(1)
        for col=1:sz(2)
            % decide whether it is foreground or background
            isNotOnBoundry = MaskOutline_with_BoundaryWidth(row, col) == 0;
            isBackground = Mask(row, col) == 0;
            if(isNotOnBoundry)
                if(isBackground)
                    countB = countB + 1;
                    %B_pixels = [B_pixels; Img(row, col, 1) Img(row, col, 2) Img(row, col, 3)];
                else
                    countF = countF + 1;

                    %F_pixels = [F_pixels; Img(row, col, 1) Img(row, col, 2) Img(row, col, 3)];
                    %F_pixels = [F_pixels; squeeze(Img(row, col, :))'];
                end
            end
        end
    end




    % init arrays based on the counts above^^
    % we do this, instead of appending, to have better performance(faster)
    B_pixels = zeros(countB, 3);
    F_pixels = zeros(countF, 3);
    B_idx = 1;
    F_idx = 1;
    for row=1:sz(1)
        for col=1:sz(2)
            % decide whether it is foreground or background
            isNotOnBoundry = MaskOutline_with_BoundaryWidth(row, col) == 0;
            isBackground = Mask(row, col) == 0;
            if(isNotOnBoundry)
                if(isBackground)
                    %countB = countB + 1;
                    B_pixels(B_idx, :) = [Img(row, col, 1) Img(row, col, 2) Img(row, col, 3)];
                    B_idx = B_idx + 1;
                else
                    %countF = countF + 1;

                    F_pixels(F_idx, :) = [Img(row, col, 1) Img(row, col, 2) Img(row, col, 3)];
                    F_idx = F_idx + 1;

                    %F_pixels = [F_pixels; squeeze(Img(row, col, :))'];
                end
            end
        end
    end

    F_gmm = fitgmdist(F_pixels, 3, 'RegularizationValue', 0.0006, 'Options', options);
    B_gmm = fitgmdist(B_pixels, 3, 'RegularizationValue', 0.0006, 'Options', options);
    %}


    num_windows = length(LocalWindows);
    window_F_gmms = cell(1, num_windows);
    window_B_gmms = cell(1, num_windows);
    window_masks = cell(1, num_windows);
    window_d_matrices = cell(1, num_windows);
    window_w_c_matrices = cell(1, num_windows);
    window_p_c_matrices = cell(1, num_windows);
    f_c_values = cell(1, num_windows);

    for i=1:num_windows
        center = LocalWindows(i,:);
        center = [center(2) center(1)]; % make it center(row, col)

        % create window
        window = zeros(WindowWidth, WindowWidth, 3);

        startRow = max([1, center(1) - sigma_c]);% added min/max to avoid out of range at image edges.
        endRow = (min([sz(1), center(1) + sigma_c])); 

        startCol = max([1, center(2) - sigma_c]);
        endCol = min([sz(2), center(2) + sigma_c]);
 
        window = Img(startRow:endRow,startCol:endCol, :);
        
        B_pixels = [];
        F_pixels = [];

        for row=startRow:endRow
            for col=startCol:endCol
                % decide whether it is foreground or background
                isNotOnBoundry = MaskOutline_with_BoundaryWidth(row, col) == 0;
                isBackground = Mask(row, col) == 0;
                if(isNotOnBoundry)
                    if(isBackground)
                        B_pixels = [B_pixels; Img(row, col, 1) Img(row, col, 2) Img(row, col, 3)];
                    else
                        F_pixels = [F_pixels; Img(row, col, 1) Img(row, col, 2) Img(row, col, 3)];
                        %F_pixels = [F_pixels; squeeze(Img(row, col, :))'];
                    end
                end
            end
        end

        F_gmm = fitgmdist(F_pixels, 3, 'RegularizationValue', 0.0006, 'Options', options);
        B_gmm = fitgmdist(B_pixels, 3, 'RegularizationValue', 0.0006, 'Options', options);
        
        window_p_c_matrix = zeros(WindowWidth, WindowWidth); % foreground probability
        windowSize = size(window);
        
        for row=1:windowSize(1)
            for col=1:windowSize(2)
                curr_pixel = squeeze(window(row, col, :))';
                 
                p_F_gmm = pdf(F_gmm, curr_pixel);
                p_B_gmm = pdf(B_gmm, curr_pixel);
                window_p_c_matrix(row, col) = p_F_gmm / (p_F_gmm + p_B_gmm);
            end
        end

        window_w_c_matrix = w_c_matrix(startRow:endRow,startCol:endCol);
        window_mask = Mask(startRow:endRow,startCol:endCol);
        window_d_matrix = d_matrix(startRow:endRow,startCol:endCol);

        up = sum(abs(window_mask - window_p_c_matrix) .* window_w_c_matrix);
        down = sum(window_w_c_matrix);
        f_c = 1 - up/down;

        % store the info so we can return them
        window_F_gmms{i} = F_gmm;
        window_B_gmms{i} = B_gmm;
        window_masks{i} = window_mask;
        window_d_matrices{i} = window_d_matrix;
        window_w_c_matrices{i} = window_w_c_matrix;
        window_p_c_matrices{i} = window_p_c_matrix;
        f_c_values{i} = f_c;
    end

    ColorModels = struct('window_F_gmms', {window_F_gmms}, 'window_B_gmms', {window_B_gmms}, ...
        'MaskOutline_with_BoundaryWidth', {MaskOutline_with_BoundaryWidth}, ...
        'window_masks', {window_masks}, 'window_d_matrices', {window_d_matrices}, 'window_w_c_matrices', {window_w_c_matrices}, ...
        'window_p_c_matrices', {window_p_c_matrices}, ...
        'f_c_values', {f_c_values});
end

