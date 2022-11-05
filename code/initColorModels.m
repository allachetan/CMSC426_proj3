img = imread("../input/1.jpg");
mask = im2bw(imread("../input/Mask1.png"));
Num_windows = 20
Window_width = 30 
[MaskOutline, LocalWindows] = initLocalWindows(img, mask, Num_windows, Window_width, true);
boundry_width = 5; 
colorModel = initializeColorModels(img, mask, MaskOutline, LocalWindows, boundry_width, Window_width)

function ColorModels = initializeColorModels(Img, Mask, MaskOutline, LocalWindows, BoundaryWidth, WindowWidth)
% INITIALIZAECOLORMODELS Initialize color models.  ColorModels is a struct you should define yourself.
%
% Must define a field ColorModels.Confidences: a cell array of the color confidence map for each local window.
    d_matrix = bwdist(MaskOutline); % distances to the nearest pixel of the outline.
    sigma_c = round(WindowWidth / 2); % half window size
    sz = size(Mask);
    Img = im2double(Img); % necessary for fitgmdist
    p_c_matrix = zeros(sz); % foreground probability
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
    figure
    imshow(MaskOutline_with_BoundaryWidth)

    figure
    imshow(w_c_matrix)

    figure
    imshow(Mask)
    %}

    % for gmm models
    options = statset('MaxIter', 800);

    num_windows = length(LocalWindows);
    for i=1:num_windows
        center = LocalWindows(i,:);
        center = [center(2) center(1)]; % make it center(row, col)

        % create window
        window = zeros(WindowWidth, WindowWidth, 3);
        size(Img(1, 1, :))

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
        

        
        break


    end
    figure
    imshow(Mask)

    %colorModels = struct()

end

