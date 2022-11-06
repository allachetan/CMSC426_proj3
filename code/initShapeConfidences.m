% returns   1×20 cell array of shape confidence matrix for each window.
function ShapeConfidences = initShapeConfidences(maskSize, LocalWindows, ColorConfidences, window_d_matrices, WindowWidth, SigmaMin, A, fcutoff, R)
% INITSHAPECONFIDENCES Initialize shape confidences.  ShapeConfidences is a struct you should define yourself.
    num_windows = length(LocalWindows);
    f_c_values = ColorConfidences;
    sigma_c = round(WindowWidth/2);
    image_painted_with_f_s = zeros(maskSize);

    ShapeConfidences = {};
    for i=1:num_windows
        f_c = f_c_values{i};
        if(f_c <= fcutoff)
            sigma_s = SigmaMin;
        else
            sigma_s = SigmaMin + A * (f_c - fcutoff)^R;
        end

        window_d_matrix = window_d_matrices{i};
        window_f_s_matrix = 1 - exp(-1 .* (window_d_matrix.^2)./(sigma_s.^2));

        ShapeConfidences{i} = window_f_s_matrix; % for the return value


        % below is just for the illustration after the loop.
        center = LocalWindows(i,:);
        center = [center(2) center(1)]; % make it center(row, col)

        startRow = max([1, center(1) - sigma_c]);% added min/max to avoid out of range at image edges.
        startCol = max([1, center(2) - sigma_c]);
        
        for row=1:WindowWidth
            for col=1:WindowWidth
                image_painted_with_f_s(row + startRow - 1, col + startCol - 1) = window_f_s_matrix(row, col);
            end
        end


    end
    
    figure
    imshow(image_painted_with_f_s)

end
