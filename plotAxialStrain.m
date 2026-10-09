function plotAxialStrain(node, element, strain_total, strain_mechanical, strain_thermal, outputPath, plotOptions)
% PLOTAXIALSTRAIN Visualizes element axial strain distribution on the truss.
%
%   plotAxialStrain(node, element, strain_total, strain_mechanical, strain_thermal, outputPath, plotOptions)
%
%   Inputs:
%       node              - Nx2 matrix of [x, y] nodal coordinates
%       element           - Mx2 matrix of [node_i, node_j] connectivity
%       strain_total      - Mx1 vector of total element strains
%       strain_mechanical - Mx1 vector of mechanical element strains
%       strain_thermal    - Mx1 vector of thermal element strains
%       outputPath        - Full path for output PNG file
%       plotOptions       - Struct with fields: imageDPI, strainType

    if nargin < 7 || isempty(plotOptions), plotOptions = struct(); end
    if ~isfield(plotOptions, 'strainType'), plotOptions.strainType = 'mechanical'; end
    if ~isfield(plotOptions, 'imageDPI'), plotOptions.imageDPI = 300; end

    [fig, ax] = trussFigure(node, plotOptions);

    nElems = size(element, 1);

    % Select strain type
    strainType = 'mechanical';
    if isfield(plotOptions, 'strainType')
        strainType = lower(plotOptions.strainType);
    end

    switch strainType
        case 'total'
            strainData = strain_total;
            strainLabel = 'Total Strain';
        case 'thermal'
            strainData = strain_thermal;
            strainLabel = 'Thermal Strain';
        case 'mechanical'
            strainData = strain_mechanical;
            strainLabel = 'Mechanical Strain';
        otherwise
            error('Truss:PlotOptions', 'strainType must be mechanical, total, or thermal.');
    end

    nColors = 256;
    [climits, cmap] = trussColorMap(strainData, nColors);

    % --- Draw elements with strain color ---
    for i = 1:nElems
        n1 = element(i, 1);
        n2 = element(i, 2);

        cIdx = round((strainData(i) - climits(1)) / (climits(2) - climits(1)) * (nColors - 1)) + 1;
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
    cb.Label.String = [strainLabel ' (dimensionless)'];
    cb.Label.FontSize = 11;

    % --- Annotate max and min strain ---
    [maxStrain, maxIdx] = max(strainData);
    [minStrain, minIdx] = min(strainData);
    xMid = mean([min(node(:,1)), max(node(:,1))]);

    mid_max = (node(element(maxIdx,1),:) + node(element(maxIdx,2),:)) / 2;
    if mid_max(1) > xMid
        horizAlignMax = 'right';
        maxStr = sprintf('Max: %.4e (e%d)  ', maxStrain, maxIdx);
    else
        horizAlignMax = 'left';
        maxStr = sprintf('  Max: %.4e (e%d)', maxStrain, maxIdx);
    end
    text(ax, mid_max(1), mid_max(2), maxStr, ...
        'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.7 0 0], ...
        'HorizontalAlignment', horizAlignMax, ...
        'BackgroundColor', [1 1 1 0.75], 'Margin', 2);

    if minIdx ~= maxIdx
        mid_min = (node(element(minIdx,1),:) + node(element(minIdx,2),:)) / 2;
        if mid_min(1) > xMid
            horizAlignMin = 'right';
            minStr = sprintf('Min: %.4e (e%d)  ', minStrain, minIdx);
        else
            horizAlignMin = 'left';
            minStr = sprintf('  Min: %.4e (e%d)', minStrain, minIdx);
        end
        text(ax, mid_min(1), mid_min(2), minStr, ...
            'FontSize', 9, 'FontWeight', 'bold', 'Color', [0 0 0.7], ...
            'HorizontalAlignment', horizAlignMin, ...
            'BackgroundColor', [1 1 1 0.75], 'Margin', 2);
    end

    % --- Formatting ---
    axis(ax, 'equal');
    grid(ax, 'on');
    ax.GridColor = [0.85 0.85 0.85];
    ax.GridAlpha = 0.5;
    xlabel(ax, 'X (m)', 'FontSize', 11);
    ylabel(ax, 'Y (m)', 'FontSize', 11);
    title(ax, ['Axial ' strainLabel ' Distribution'], 'FontSize', 14, 'FontWeight', 'bold');
    ax.FontSize = 10;

    % Subtitle with strain info
    hasThermal = any(abs(strain_thermal) > 0);
    if hasThermal && ~strcmp(strainType, 'thermal')
        subtitle(ax, sprintf('Displaying: %s  |  Thermal strain: %.4e', ...
            strainLabel, strain_thermal(1)), 'FontSize', 10, 'Color', [0.3 0.3 0.3]);
    else
        subtitle(ax, sprintf('Tensile (+) / Compressive (-)  |  Range: [%.4e, %.4e]', ...
            minStrain, maxStrain), 'FontSize', 10, 'Color', [0.3 0.3 0.3]);
    end

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
