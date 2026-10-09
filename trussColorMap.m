function [limits, cmap] = trussColorMap(values, nColors)
% TRUSSCOLORMAP Signed blue-white-red map with zero correctly located.
% Unlike symmetric color limits, this uses the full color dynamic range
% on both sides even when compression and tension differ in magnitude.
    if nargin < 2, nColors = 256; end
    dataMin = min(values(:));
    dataMax = max(values(:));
    if ~isfinite(dataMin) || ~isfinite(dataMax)
        error('Truss:PlotData', 'Color-mapped values must be finite.');
    end
    if dataMin == dataMax
        if dataMin == 0
            limits = [-1 1];
            cmap = repmat([0.40 0.48 0.58], nColors, 1);
            return;
        else
            limits = [min(dataMin, 0), max(dataMax, 0)];
        end
    else
        limits = [min(dataMin, 0), max(dataMax, 0)];
    end
    if limits(1) == limits(2), limits = limits + [-1 1]; end
    negFraction = -limits(1) / (limits(2) - limits(1));
    index = (0:nColors-1)' / (nColors-1);
    cmap = zeros(nColors,3);
    blue = [0.08 0.20 0.95]; white = [1 1 1]; red = [0.98 0.16 0.12];
    for j = 1:nColors
        if index(j) <= negFraction
            t = index(j) / max(negFraction, eps);
            cmap(j,:) = blue*(1-t) + white*t;
        else
            t = (index(j)-negFraction) / max(1-negFraction, eps);
            cmap(j,:) = white*(1-t) + red*t;
        end
    end
    % Keep the map valid for one-sign fields as well.
end
