function plotDisplacement(node, element, U, outputPath, plotOptions)
% PLOTDISPLACEMENT Visualizes nodal displacement distribution on deformed truss.
%
%   plotDisplacement(node, element, U, outputPath, plotOptions)
%
%   Inputs:
%       node        - Nx2 matrix of [x, y] nodal coordinates
%       element     - Mx2 matrix of [node_i, node_j] connectivity
%       U           - 2Nx1 displacement vector (Ux_i = U(2i-1), Uy_i = U(2i))
%       outputPath  - Full path for output PNG file
%       plotOptions - Struct with fields: deformationScale, imageDPI

    if nargin < 5 || isempty(plotOptions), plotOptions = struct(); end
    if ~isfield(plotOptions, 'deformationScale'), plotOptions.deformationScale = 'auto'; end
    if ~isfield(plotOptions, 'imageDPI'), plotOptions.imageDPI = 300; end

    [fig, ax] = trussFigure(node, plotOptions);

    nNodes = size(node, 1);
    nElems = size(element, 1);

    % Extract nodal displacements
    Ux = U(1:2:end);
    Uy = U(2:2:end);
    U_mag = sqrt(Ux.^2 + Uy.^2);

    % Compute deformation scale
    structSize = max(range(node(:,1)), range(node(:,2)));
    if structSize == 0, structSize = 1; end
    maxDisp = max(U_mag);

    if isempty(plotOptions.deformationScale) || ischar(plotOptions.deformationScale) || isstring(plotOptions.deformationScale)
        % Auto scale: make max deformation ~10% of structure size
        if maxDisp > 0
            scale = 0.10 * structSize / maxDisp;
        else
            scale = 1;
        end
    else
        scale = plotOptions.deformationScale;
        if ~isscalar(scale) || ~isfinite(scale) || scale < 0
            error('Truss:PlotOptions', 'deformationScale must be auto or a finite nonnegative scalar.');
        end
    end

    % Deformed positions
    deformed = node + scale * [Ux, Uy];

    % --- Draw original geometry (dashed gray) ---
    for i = 1:nElems
        n1 = element(i, 1);
        n2 = element(i, 2);
        plot(ax, [node(n1,1) node(n2,1)], [node(n1,2) node(n2,2)], ...
            '--', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.8);
    end

    % --- Draw deformed geometry with color interpolation ---
    climits = [0, max(U_mag)];
    if climits(2) == 0
        climits(2) = 1;  % Prevent issues with zero displacement
    end

    % Use surface trick for continuous nodal color interpolation along elements
    for i = 1:nElems
        n1 = element(i, 1);
        n2 = element(i, 2);

        nPts = 20;
        t = linspace(0, 1, nPts);
        x_pts = deformed(n1,1) + t * (deformed(n2,1) - deformed(n1,1));
        y_pts = deformed(n1,2) + t * (deformed(n2,2) - deformed(n1,2));
        u_pts = U_mag(n1) + t * (U_mag(n2) - U_mag(n1));

        z_pts = zeros(size(x_pts));
        surface(ax, [x_pts; x_pts], [y_pts; y_pts], [z_pts; z_pts], ...
            [u_pts; u_pts], 'FaceColor', 'none', 'EdgeColor', 'interp', ...
            'LineWidth', 2.5);
    end

    % Deformed node markers
    scatter(ax, deformed(:,1), deformed(:,2), 30, U_mag, 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.5);

    % --- Colorbar ---
    colormap(ax, jet(256));
    clim(ax, climits);
    cb = colorbar(ax);
    cb.Label.String = 'Displacement Magnitude (m)';
    cb.Label.FontSize = 11;

    % --- Annotate maximum displacement ---
    [maxU, maxIdx] = max(U_mag);
    nodeX = deformed(maxIdx, 1);
    nodeY = deformed(maxIdx, 2);
    xRangeAll = range([node(:,1); deformed(:,1)]);
    xMid = mean([min([node(:,1); deformed(:,1)]), max([node(:,1); deformed(:,1)])]);
    if nodeX > xMid
        horizAlign = 'right';
        txtStr = sprintf('Max: %.4e m (n%d)  ', maxU, maxIdx);
    else
        horizAlign = 'left';
        txtStr = sprintf('  Max: %.4e m (n%d)', maxU, maxIdx);
    end
    text(ax, nodeX, nodeY, txtStr, ...
        'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.8 0 0], ...
        'HorizontalAlignment', horizAlign, ...
        'BackgroundColor', [1 1 1 0.8], 'Margin', 3);

    % --- Formatting ---
    axis(ax, 'equal');
    grid(ax, 'on');
    ax.GridColor = [0.85 0.85 0.85];
    ax.GridAlpha = 0.5;
    xlabel(ax, 'X (m)', 'FontSize', 11);
    ylabel(ax, 'Y (m)', 'FontSize', 11);
    title(ax, 'Nodal Displacement Distribution', 'FontSize', 14, 'FontWeight', 'bold');
    subtitle(ax, sprintf('Deformation Scale: %.1fx  |  Max Displacement: %.4e m', scale, maxDisp), ...
        'FontSize', 10, 'Color', [0.3 0.3 0.3]);
    ax.FontSize = 10;

    % Axis limits: union of original and deformed extents with margin
    allX = [node(:,1); deformed(:,1)];
    allY = [node(:,2); deformed(:,2)];
    xl = [min(allX), max(allX)];
    yl = [min(allY), max(allY)];
    xMargin = 0.15 * max(diff(xl), 1);
    yMargin = 0.12 * max(diff(yl), 1);
    xlim(ax, [xl(1)-xMargin, xl(2)+xMargin]);
    ylim(ax, [yl(1)-yMargin, yl(2)+yMargin]);

    % --- Export ---
    set(ax, 'Color', 'w');
    exportgraphics(fig, outputPath, 'Resolution', plotOptions.imageDPI, 'BackgroundColor', 'w');
    close(fig);

end
