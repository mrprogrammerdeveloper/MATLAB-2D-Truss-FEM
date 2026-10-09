function postProcess(node, element, U, S, force_ext, BC_original, E, A, alpha, T, inputFileName, plotOptions)
% POSTPROCESS Generates and saves FEA visualizations for truss analysis.
%
%   postProcess(node, element, U, S, force_ext, BC_original, E, A, alpha, T, inputFileName, plotOptions)
%
%   Parameters:
%       node          - N x 2 matrix of nodal coordinates [x, y]
%       element       - M x 2 matrix of element connectivity [node_i, node_j]
%       U             - 2N x 1 global displacement vector
%       S             - M x 1 element axial stress vector
%       force_ext     - 2N x 1 original external force vector (before thermal forces)
%       BC_original   - 2N x 1 original boundary conditions (NaN for free DOFs)
%       E             - Young's modulus (scalar)
%       A             - Cross-sectional area (scalar)
%       alpha         - Thermal expansion coefficient (scalar)
%       T             - Temperature change (scalar)
%       inputFileName - Input file path or name (e.g., 'problem-2-with-thermal.txt')
%       plotOptions   - Struct configuring visualization options

    % Handle missing or empty plotOptions struct
    if nargin < 12 || isempty(plotOptions)
        plotOptions = struct();
    end

    % 1. Set default options if fields are missing
    if ~isfield(plotOptions, 'enabled'), plotOptions.enabled = true; end
    if ~isfield(plotOptions, 'showNodeIDs'), plotOptions.showNodeIDs = size(node,1) <= 40; end
    if ~isfield(plotOptions, 'showElementIDs'), plotOptions.showElementIDs = false; end
    if ~isfield(plotOptions, 'showSupports'), plotOptions.showSupports = true; end
    if ~isfield(plotOptions, 'showForces'), plotOptions.showForces = true; end
    if ~isfield(plotOptions, 'deformationScale'), plotOptions.deformationScale = 'auto'; end
    if ~isfield(plotOptions, 'imageDPI'), plotOptions.imageDPI = 300; end
    if ~isfield(plotOptions, 'showFigures'), plotOptions.showFigures = false; end
    if ~isfield(plotOptions, 'strainType'), plotOptions.strainType = 'mechanical'; end

    if ~plotOptions.enabled
        return;
    end

    % 2. Create output directory
    [~, baseName, ~] = fileparts(inputFileName);
    if isfield(plotOptions, 'outputDir') && ~isempty(plotOptions.outputDir)
        outputDir = fullfile(char(plotOptions.outputDir), baseName);
    else
        outputDir = fullfile('results', baseName);
    end
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % 3. Compute strains
    [strain_total, strain_mechanical, strain_thermal] = computeElementStrain(node, element, U, alpha, T);

    % 4. Render independently so one failing plot cannot hide other outputs.
    fprintf('\nGenerating visualizations...\n');
    plotters = {@() plotTrussGeometry(node, element, BC_original, force_ext, ...
                     fullfile(outputDir,'01_truss_geometry.png'), plotOptions), ...
                @() plotDisplacement(node, element, U, ...
                     fullfile(outputDir,'02_displacement.png'), plotOptions), ...
                @() plotAxialStress(node, element, S, ...
                     fullfile(outputDir,'03_axial_stress.png'), plotOptions), ...
                @() plotAxialStrain(node, element, strain_total, strain_mechanical, strain_thermal, ...
                     fullfile(outputDir,'04_axial_strain.png'), plotOptions)};
    names = {'01_truss_geometry.png', '02_displacement.png', ...
             '03_axial_stress.png', '04_axial_strain.png'};
    failed = {};
    for i = 1:numel(plotters)
        try
            plotters{i}();
            fprintf('  Saved: %s\n', fullfile(outputDir,names{i}));
        catch ME
            failed{end+1} = sprintf('%s: %s', names{i}, ME.message); %#ok<AGROW>
            fprintf(2, '  FAILED %s: %s\n', names{i}, ME.message);
        end
    end
    if ~isempty(failed)
        warning('Truss:VisualizationFailed', ...
            '%d of 4 images failed. Numerical results are unaffected.', numel(failed));
    else
        fprintf('All visualizations saved to: %s\n', outputDir);
    end
end
