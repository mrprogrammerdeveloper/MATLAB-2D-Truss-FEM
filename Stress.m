function S = Stress(node, element, U, E, alpha, T)
% STRESS Signed element axial stress [Pa]. T is DeltaT (positive or negative).
% Formula is consistent with computeElementStrain and thermal FEM loads.
    S = zeros(size(element, 1), 1);
    for i = 1:size(element, 1)
        ni = element(i, 1);
        nj = element(i, 2);
        delta = node(nj,:) - node(ni,:);
        L = hypot(delta(1), delta(2));
        c = delta(1) / L;
        s = delta(2) / L;
        dof = [2*ni-1, 2*ni, 2*nj-1, 2*nj];
        strainTotal = ([-c -s c s] * U(dof)) / L;
        S(i) = E * (strainTotal - alpha*T);
    end
end
