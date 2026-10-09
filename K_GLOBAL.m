function [K , thermoMechanical_force] =  K_GLOBAL(node , element , E , A,alpha , T)


n = size(node, 1);

thermoMechanical_force = zeros(n*2 , 1);
K = zeros(n*2);

dof(1) =0;
dof(2) =0;
dof(3) =0;
dof(4) =0;

    for i =1:size(element,1)
        x1 = node(element(i , 1) ,1);
        y1 = node(element(i , 1) ,2);
        x2 = node(element(i , 2) ,1);
        y2 = node(element(i , 2) ,2);
        L = sqrt(((y2-y1)^2) + ((x2-x1)^2));
        c = (x2 -x1)/L;
        s = (y2-y1)/L;
       
        dof(1)= 2*element(i ,1)-1;
        dof(2) = element(i ,1)*2;
        dof(3)= 2*element(i ,2)-1;
        dof(4) = element(i ,2)*2;

        k_local = (A*E/L) * [
         c^2, c*s, -c^2, -c*s;
         c*s, s^2, -c*s, -s^2;
        -c^2, -c*s, c^2, c*s;
        -c*s, -s^2, c*s, s^2
    ];
        
        dof_vec = [dof(1) dof(2) dof(3) dof(4)];
        K(dof_vec, dof_vec) = K(dof_vec, dof_vec) + k_local;
        if(T ~= 0 && alpha ~= 0)
            thermoMechanical_force_global = (E*A*alpha*T)*[-c ; -s ; c; s];
            thermoMechanical_force(dof_vec) = thermoMechanical_force(dof_vec)+ thermoMechanical_force_global;

        end
    end
end