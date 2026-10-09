function [fig, ax] = trussFigure(node, plotOptions)
% TRUSSFIGURE Create a readable white, landscape figure for any aspect ratio.
    if nargin < 2, plotOptions = struct(); end
    visible = 'off';
    if isfield(plotOptions, 'showFigures') && plotOptions.showFigures
        visible = 'on';
    end
    xrange = max(node(:,1)) - min(node(:,1));
    yrange = max(node(:,2)) - min(node(:,2));
    if xrange < eps && yrange < eps, xrange = 1; yrange = 1; end
    ratio = xrange / max(yrange, max(xrange, 1) * 0.02);
    width = 1400;
    height = min(950, max(440, round(width / max(ratio, 1.5))));
    fig = figure('Visible', visible, 'Color', 'w', 'Position', [100 100 width height]);
    try
        theme(fig, 'light');
    catch
        % Older versions may not expose theme().
    end
    ax = axes('Parent', fig, 'Color', 'w');
    hold(ax, 'on');
end
