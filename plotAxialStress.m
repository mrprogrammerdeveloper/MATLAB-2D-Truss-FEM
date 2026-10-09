function plotAxialStress(node, element, S, outputPath, plotOptions)
% PLOTAXIALSTRESS Visualizes element axial stress distribution on the truss.
%
%   plotAxialStress(node, element, S, outputPath, plotOptions)
%
%   Inputs:
%       node       - Nx2 matrix of [x, y] nodal coordinates
%       element    - Mx2 matrix of [node_i, node_j] connectivity
%       S          - Mx1 vector of element axial stresses (Pa)
%       outputPath - Full path for output PNG file
%       plotOptions - Struct with field: imageDPI

    if nargin < 5 || isempty(plotOptions), plotOptions = struct(); end
    if ~isfield(plotOptions, 'imageDPI'), plotOptions.imageDPI = 300; end

    [fig, ax] = trussFigure(node, plotOptions);

    nElems = size(element, 1);

    % Convert to MPa for display
    S_MPa = S / 1e6;

    % Use actual asymmetric physical range while mapping zero to white.
    nColors = 256;
    [climits, cmap] = trussColorMap(S_MPa, nColors);

    % --- Draw elements with stress color ---
    for i = 1:nElems
        n1 = element(i, 1);
        n2 = element(i, 2);

        % Map stress to color index
        cIdx = round((S_MPa(i) - climits(1)) / (climits(2) - climits(1)) * (nColors - 1)) + 1;
        cIdx = max(1, min(nColors, cIdx));

        plot(ax, [node(n1,1) node(n2,1)], [node(n1,2) node(n2,2)], ...
            '-', 'Color', cmap(cIdx,:), 'LineWidth', 3);
    end

    % --- Draw nodes ---
    plot(ax, node(:,1), node(:,2), 'ko', 'MarkerSize', 3, ...
        'MarkerFaceColor', 'k');

    % --- Colorbar ---
    colormap(ax, cmap);
    clim(ax, climits);
    cb = colorbar(ax);
    cb.Label.String = 'Axial Stress (MPa)';
    cb.Label.FontSize = 11;

    % --- Annotate max tensile and compressive ---
    [maxTensile, maxTidx] = max(S_MPa);
    [maxCompressive, maxCidx] = min(S_MPa);
    xMid = mean([min(node(:,1)), max(node(:,1))]);

    if maxTensile > 0
        mid = (node(element(maxTidx,1),:) + node(element(maxTidx,2),:)) / 2;
        if mid(1) > xMid
            horizAlign = 'right';
            tStr = sprintf('Max Tension: %.2f MPa (e%d)  ', maxTensile, maxTidx);
        else
            horizAlign = 'left';
            tStr = sprintf('  Max Tension: %.2f MPa (e%d)', maxTensile, maxTidx);
        end
        text(ax, mid(1), mid(2), tStr, ...
            'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.7 0 0], ...
            'HorizontalAlignment', horizAlign, ...
            'BackgroundColor', [1 1 1 0.75], 'Margin', 2);
    end
    if maxCompressive < 0
        mid = (node(element(maxCidx,1),:) + node(element(maxCidx,2),:)) / 2;
        if mid(1) > xMid
            horizAlign = 'right';
            cStr = sprintf('Max Compression: %.2f MPa (e%d)  ', maxCompressive, maxCidx);
        else
            horizAlign = 'left';
            cStr = sprintf('  Max Compression: %.2f MPa (e%d)', maxCompressive, maxCidx);
        end
        text(ax, mid(1), mid(2), cStr, ...
            'FontSize', 9, 'FontWeight', 'bold', 'Color', [0 0 0.7], ...
            'HorizontalAlignment', horizAlign, ...
            'BackgroundColor', [1 1 1 0.75], 'Margin', 2);
    end

    % --- Formatting ---
    axis(ax, 'equal');
    grid(ax, 'on');
    ax.GridColor = [0.85 0.85 0.85];
    ax.GridAlpha = 0.5;
    xlabel(ax, 'X (m)', 'FontSize', 11);
    ylabel(ax, 'Y (m)', 'FontSize', 11);
    title(ax, 'Axial Stress Distribution', 'FontSize', 14, 'FontWeight', 'bold');
    ax.FontSize = 10;

    % Add stress summary to subtitle
    subtitle(ax, sprintf('Tension (+) / Compression (-)  |  Range: [%.2f, %.2f] MPa', ...
        min(S_MPa), max(S_MPa)), 'FontSize', 10, 'Color', [0.3 0.3 0.3]);

    % Add margins
    xl = xlim(ax); yl = ylim(ax);
    xMargin = 0.10 * max(diff(xl), 1);
    yMargin = 0.10 * max(diff(yl), 1);
    xlim(ax, [xl(1)-xMargin, xl(2)+xMargin]);
    ylim(ax, [yl(1)-yMargin, yl(2)+yMargin]);

    % --- Export ---
    set(ax, 'Color', 'w');
    exportgraphics(fig, outputPath, 'Resolution', plotOptions.imageDPI, 'BackgroundColor', 'w');
    close(fig);

end
