function [U_out, S_out, Ff_out] = Truss(inputFile, plotOptions)
format short e;
U_out = []; S_out = []; Ff_out = [];

% Support batch mode: accept filename argument; otherwise use GUI dialog
if nargin < 1 || isempty(inputFile)
    [file, location] = uigetfile("*.txt");
    if isequal(file, 0)
        disp('No file selected.');
        return;
    end
    inputFile = fullfile(location, file);
end

if nargin < 2
    plotOptions = struct();
end

[node , element , force , BC , E , A , alpha , T]  = processFile(inputFile);
[K,thermoMechanical_force] = K_GLOBAL(node , element , E , A,alpha , T);

% Save original BC and external force vectors for post-processing
BC_original = BC;
force_ext = force;

force = force + thermoMechanical_force;

Ff = zeros(size(node,1)*2, 1);

freeDOF = find(isnan(BC));
fixedDOF = find(~isnan(BC));

% Prescribed nonzero displacements contribute -K_fc * U_c to the RHS.
if ~isempty(freeDOF)
    K_free = K(freeDOF, freeDOF);
    if ~all(isfinite(K_free(:))) || rcond(K_free) < 1e-14
        error('Truss:SingularSystem', ...
            'Free stiffness matrix is singular or severely ill-conditioned. Check connectivity and supports.');
    end
    rhs = force(freeDOF) - K(freeDOF, fixedDOF) * BC(fixedDOF);
    BC(freeDOF) = K_free \ rhs;
end

% A reaction is the residual of applied mechanical AND thermal forces.
% Applied loads at restrained DOFs must be subtracted as well.
Ff(fixedDOF) = K(fixedDOF, :) * BC - force(fixedDOF);
[S] = Stress(node , element , BC , E , alpha , T);

fprintf('|----------------------------------------------------------------------------------------|\n')
fprintf('|---------------------------- جابه جایی و نیروهای عکس العمل ---------------------------|\n')
fprintf('|----------------------------------------------------------------------------------------|\n')
fprintf('|   NODE     |      U       |      V       |      REACTION_X       |      REACTION_Y     |\n')
fprintf('|----------------------------------------------------------------------------------------|\n')
for i =1:size(node,1)
    fprintf('|    n%-6d | %-12.5e | %-12.5e |    %-17.5e  |    %-17.5e|\n' ,i , BC(2*i-1) , BC(2*i) , Ff(2*i-1) , Ff(2*i))
end
fprintf('------------------------------------------------------------------------------------------\n\n')
fprintf('|----------------------------------------------------------------|\n')
fprintf('|------------------------ تنش المان ها -------------------------|\n')
fprintf('|----------------------------------------------------------------|\n')
fprintf('|  element   |   node_i    |   node_j    |        Stress         |\n')
fprintf('|----------------------------------------------------------------|\n')

for i =1:size(element,1)
    fprintf('|    e%-6d |     %-5d   |     %-5d   |     %-18.9e|\n' ,i , element(i , 1) , element(i , 2) ,S(i))
end
fprintf('------------------------------------------------------------------\n')

% --- Post-Processing Visualization ---
postProcess(node, element, BC, S, force_ext, BC_original, E, A, alpha, T, inputFile, plotOptions);

if nargout > 0
    U_out = BC;
end
if nargout > 1
    S_out = S;
end
if nargout > 2
    Ff_out = Ff;
end

end