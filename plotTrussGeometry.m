function plotTrussGeometry(node, element, BC_original, force_original, outputPath, plotOptions)
% PLOTTRUSSGEOMETRY Visualizes original truss geometry with supports and forces.
%
%   plotTrussGeometry(node, element, BC_original, force_original, outputPath, plotOptions)
%
%   Inputs:
%       node           - Nx2 matrix of [x, y] nodal coordinates
%       element        - Mx2 matrix of [node_i, node_j] connectivity
%       BC_original    - 2Nx1 boundary condition vector (NaN = free, 0 = fixed)
%       force_original - 2Nx1 external force vector (before thermal forces)
%       outputPath     - Full path for output PNG file
%       plotOptions    - Struct with fields: showNodeIDs, showElementIDs,
%                        showSupports, showForces, imageDPI

    if nargin < 6 || isempty(plotOptions), plotOptions = struct(); end
    if ~isfield(plotOptions, 'showNodeIDs'), plotOptions.showNodeIDs = size(node,1) <= 40; end
    if ~isfield(plotOptions, 'showElementIDs'), plotOptions.showElementIDs = false; end
    if ~isfield(plotOptions, 'showSupports'), plotOptions.showSupports = true; end
    if ~isfield(plotOptions, 'showForces'), plotOptions.showForces = true; end
    if ~isfield(plotOptions, 'imageDPI'), plotOptions.imageDPI = 300; end
    if ~isfield(plotOptions, 'showForceLabels'), plotOptions.showForceLabels = 'auto'; end

    [fig, ax] = trussFigure(node, plotOptions);

    nNodes = size(node, 1);
    nElems = size(element, 1);

    % Structure size for proportional scaling
    xRange = range(node(:,1));
    yRange = range(node(:,2));
    structSize = max(xRange, yRange);
    if structSize == 0, structSize = 1; end

    % --- Draw elements ---
    for i = 1:nElems
        n1 = element(i, 1);
        n2 = element(i, 2);
        plot(ax, [node(n1,1) node(n2,1)], [node(n1,2) node(n2,2)], ...
            '-', 'Color', [0.1 0.2 0.5], 'LineWidth', 1.5);

        if plotOptions.showElementIDs
            mx = (node(n1,1) + node(n2,1)) / 2;
            my = (node(n1,2) + node(n2,2)) / 2;
            text(ax, mx, my, sprintf('e%d', i), ...
                'FontSize', 7, 'Color', [0.3 0.3 0.6], ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
        end
    end

    % --- Draw nodes ---
    plot(ax, node(:,1), node(:,2), 'ko', 'MarkerSize', 5, ...
        'MarkerFaceColor', [0.2 0.2 0.2]);

    if plotOptions.showNodeIDs
        offset = 0.015 * structSize;
        for i = 1:nNodes
            text(ax, node(i,1) + offset, node(i,2) + offset, sprintf('n%d', i), ...
                'FontSize', 8, 'Color', [0.1 0.1 0.1], 'FontWeight', 'bold');
        end
    end

    % --- Draw supports ---
    if plotOptions.showSupports
        baseSize = 0.04 * max(min(xRange, yRange), structSize * 0.03);

        for i = 1:nNodes
            xFixed = ~isnan(BC_original(2*i - 1));
            yFixed = ~isnan(BC_original(2*i));
            px = node(i, 1);
            py = node(i, 2);

            if xFixed && yFixed
                % Pinned support: filled triangle pointing down
                tri_x = [px - baseSize, px + baseSize, px, px - baseSize];
                tri_y = [py - baseSize*1.3, py - baseSize*1.3, py, py - baseSize*1.3];
                patch(ax, tri_x, tri_y, [0.45 0.45 0.45], ...
                    'EdgeColor', 'k', 'LineWidth', 1.5);
                % Ground hatching lines
                for k = -1:0.5:1
                    plot(ax, [px + k*baseSize - baseSize*0.3, px + k*baseSize], ...
                        [py - baseSize*1.7, py - baseSize*1.3], ...
                        'Color', [0.4 0.4 0.4], 'LineWidth', 0.8);
                end
            elseif xFixed
                % X constrained: horizontal reaction, roller against vertical wall.
                wallX = px - baseSize*1.4;
                plot(ax, [wallX wallX], [py-baseSize py+baseSize], 'k-', 'LineWidth', 1.5);
                theta = linspace(0, 2*pi, 30);
                rr = baseSize * 0.25;
                plot(ax, px-baseSize*0.65 + rr*cos(theta), py + rr*sin(theta), ...
                    'k-', 'LineWidth', 1);
                plot(ax, [px wallX+rr*2], [py py], 'k-', 'LineWidth', 1);
            elseif yFixed
                % Roller in X: triangle + circle (horizontal)
                tri_x = [px - baseSize*0.7, px + baseSize*0.7, px, px - baseSize*0.7];
                tri_y = [py - baseSize, py - baseSize, py, py - baseSize];
                patch(ax, tri_x, tri_y, [0.6 0.6 0.6], ...
                    'EdgeColor', 'k', 'LineWidth', 1.2);
                theta = linspace(0, 2*pi, 30);
                r = baseSize * 0.25;
                plot(ax, px + r*cos(theta), py - baseSize - r + r*sin(theta), ...
                    'k-', 'LineWidth', 1);
            end
        end
    end

    % --- Draw force arrows ---
    if plotOptions.showForces
        % Collect forces
        forceNodes = [];
        Fx = []; Fy = [];
        for i = 1:nNodes
            fx = force_original(2*i - 1);
            fy = force_original(2*i);
            if abs(fx) > 0 || abs(fy) > 0
                forceNodes(end+1) = i; %#ok<AGROW>
                Fx(end+1) = fx; %#ok<AGROW>
                Fy(end+1) = fy; %#ok<AGROW>
            end
        end

        if ~isempty(forceNodes)
            % Scale arrows: longest arrow = 15% of structure diagonal
            diagSize = sqrt(xRange^2 + yRange^2);
            if diagSize == 0, diagSize = 1; end
            maxForce = max(sqrt(Fx.^2 + Fy.^2));
            if maxForce == 0, maxForce = 1; end
            arrowScale = 0.065 * diagSize / maxForce;

            for k = 1:length(forceNodes)
                ni = forceNodes(k);
                px = node(ni, 1);
                py = node(ni, 2);
                dx = Fx(k) * arrowScale;
                dy = Fy(k) * arrowScale;

                % Arrow starts offset from node, points toward node
                quiver(ax, px - dx, py - dy, dx, dy, 0, ...
                    'Color', [0.85 0.1 0.1], 'LineWidth', 2, ...
                    'MaxHeadSize', 0.5);

                % Force label
                fMag = sqrt(Fx(k)^2 + Fy(k)^2);
                if fMag >= 1e3
                    fStr = sprintf('%.1f kN', fMag/1e3);
                else
                    fStr = sprintf('%.1f N', fMag);
                end
                showLabels = plotOptions.showForceLabels;
                if ischar(showLabels) || isstring(showLabels)
                    showLabels = length(forceNodes) <= 12;
                end
                if showLabels
                    text(ax, px - dx, py - dy, ['  ' fStr], ...
                        'FontSize', 8, 'Color', [0.85 0.1 0.1], 'FontWeight', 'bold');
                end
            end
        end
    end

    % --- Formatting ---
    axis(ax, 'equal');
    grid(ax, 'on');
    ax.GridColor = [0.8 0.8 0.8];
    ax.GridAlpha = 0.5;
    xlabel(ax, 'X (m)', 'FontSize', 11);
    ylabel(ax, 'Y (m)', 'FontSize', 11);
    title(ax, 'Truss Geometry', 'FontSize', 14, 'FontWeight', 'bold');
    ax.FontSize = 10;

    % Add margins
    xl = xlim(ax); yl = ylim(ax);
    xMargin = 0.10 * diff(xl);
    yMargin = 0.10 * diff(yl);
    if xMargin == 0, xMargin = 1; end
    if yMargin == 0, yMargin = 1; end
    xlim(ax, [xl(1)-xMargin, xl(2)+xMargin]);
    ylim(ax, [yl(1)-yMargin, yl(2)+yMargin]);

    % --- Export ---
    set(ax, 'Color', 'w');
    exportgraphics(fig, outputPath, 'Resolution', plotOptions.imageDPI, 'BackgroundColor', 'w');
    close(fig);

end
