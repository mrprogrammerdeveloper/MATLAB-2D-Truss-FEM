function [strain_total, strain_mechanical, strain_thermal] = computeElementStrain(node, element, U, alpha, T)
% COMPUTEELEMENTSTRAIN Computes element-level strains for a 2D truss FEM solver.
%
% Syntax:
%   [strain_total, strain_mechanical, strain_thermal] = computeElementStrain(node, element, U, alpha, T)
%
% Inputs:
%   node    - N x 2 matrix of [x, y] coordinates for each node
%   element - M x 2 matrix of element connectivity [node_i, node_j]
%   U       - 2N x 1 global displacement vector (DOFs: U(2*i-1)=Ux_i, U(2*i)=Uy_i)
%   alpha   - Scalar thermal expansion coefficient (default: 0)
%   T       - Scalar temperature change Delta T (default: 0)
%
% Outputs:
%   strain_total      - M x 1 column vector of total strains
%   strain_mechanical - M x 1 column vector of mechanical strains
%   strain_thermal    - M x 1 column vector of thermal strains
%
% Consistent with Stress.m:
%   Stress = E * strain_mechanical = (E/L)*[-c -s c s]*U - E*alpha*T

    if nargin < 4 || isempty(alpha)
        alpha = 0;
    end
    if nargin < 5 || isempty(T)
        T = 0;
    end

    U = U(:);
    num_elements = size(element, 1);

    % Preallocate M x 1 column vectors
    strain_total = zeros(num_elements, 1);
    strain_thermal = zeros(num_elements, 1);
    strain_mechanical = zeros(num_elements, 1);

    for i = 1:num_elements
        % 1. Get node coordinates
        node_i = element(i, 1);
        node_j = element(i, 2);

        x1 = node(node_i, 1);
        y1 = node(node_i, 2);
        x2 = node(node_j, 1);
        y2 = node(node_j, 2);

        % 2. Element length
        dx = x2 - x1;
        dy = y2 - y1;
        L = sqrt(dx^2 + dy^2);

        % 3. Direction cosines
        c = dx / L;
        s = dy / L;

        % 4. Global DOFs associated with element nodes
        dof = [2*node_i - 1, 2*node_i, 2*node_j - 1, 2*node_j];

        % 5. Total strain from nodal displacements
        strain_total(i, 1) = ([-c, -s, c, s] * U(dof)) / L;

        % 6. Thermal strain
        if isscalar(alpha) && isscalar(T)
            strain_thermal(i, 1) = alpha * T;
        else
            if isscalar(alpha)
                a_val = alpha;
            else
                a_val = alpha(i);
            end
            if isscalar(T)
                t_val = T;
            else
                t_val = T(i);
            end
            strain_thermal(i, 1) = a_val * t_val;
        end

        % 7. Mechanical strain
        strain_mechanical(i, 1) = strain_total(i, 1) - strain_thermal(i, 1);
    end
end
