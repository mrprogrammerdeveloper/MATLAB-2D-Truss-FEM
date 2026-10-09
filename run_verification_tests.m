% RUN_VERIFICATION_TESTS Reproducible solver and plotting regression suite.
% From MATLAB, run this script from anywhere:
%   run('run_verification_tests.m')
% MATLAB itself is required for the tests below. No result is pre-certified.

clear; clc;
rootDir = fileparts(mfilename('fullpath'));
previousDir = pwd;
restoreDir = onCleanup(@() cd(previousDir)); %#ok<NASGU>
cd(rootDir);
workDir = tempname;
mkdir(workDir);
removeTemp = onCleanup(@() rmdir(workDir, 's')); %#ok<NASGU>
opts = struct('enabled', false);
passCount = 0;
fprintf('===== 2D TRUSS FEM REGRESSION TESTS =====\n');

%% T01: Existing reference cases, constitutive and equilibrium checks
cases = {'problem-1.txt', 'problem-2-without-thermal.txt', 'problem-2-with-thermal.txt', 'test_1.txt'};
for caseID = 1:numel(cases)
    filepath = fullfile('input matlab files', cases{caseID});
    [node, element, fext, prescribed, E, A, alpha, dT] = processFile(filepath);
    evalc('[U, S, R] = Truss(filepath, opts);');
    [K, fth] = K_GLOBAL(node, element, E, A, alpha, dT);
    [epsTotal, epsMech, epsThermal] = computeElementStrain(node, element, U, alpha, dT);
    assert(numel(U) == 2*size(node,1));
    assert(numel(S) == size(element,1));
    assert(all(isfinite(U)) && all(isfinite(S)) && all(isfinite(R)));
    constrained = ~isnan(prescribed);
    free = ~constrained;
    assert(max(abs(U(constrained)-prescribed(constrained))) < 1e-12);
    assert(norm(S - E*epsMech, inf) < 1e-3, 'Stress/strain consistency failure');
    assert(norm(epsThermal - alpha*dT, inf) < 1e-12);
    assert(norm(epsTotal - epsMech - epsThermal, inf) < 1e-12);
    residual = K*U - fext - fth;
    assert(norm(residual(free), inf) < 1e-3, 'Free DOF residual too large');
    assert(norm(R(constrained) - residual(constrained),inf) < 1e-3);
    assert(norm(R(free),inf) == 0);
    assert(abs(sum(R(1:2:end)+fext(1:2:end))) < 1e-3);
    assert(abs(sum(R(2:2:end)+fext(2:2:end))) < 1e-3);
    if caseID == 4
        assert(size(node,1)==186 && size(element,1)==485);
        assert(abs(max(hypot(U(1:2:end), U(2:2:end))) - 0.0438933) < 5e-6);
        assert(abs(max(S)/1e6 - 37.13704508) < 0.01);
        assert(abs(min(S)/1e6 + 216.9640075) < 0.01);
    end
    fprintf('PASS T01.%d: %s\n', caseID, cases{caseID});
    passCount = passCount + 1;
end

%% T02/T03: Free expansion and contraction of one axial bar
for signT = [1 -1]
    dT = 20*signT;
    file = fullfile(workDir, sprintf('thermal_%+d.txt', dT));
    writeCase(file, {'#node','n1,0,0','n2,2,0', '#element','e1,1,2', ...
        '#boundry_condition','n1,0,0','n2,,0', '#metadata', 'E,1000','A,1','alpha,0.001',sprintf('T,%g',dT)});
    evalc('[U,S,R] = Truss(file,opts);');
    assert(abs(U(3) - 2*0.001*dT) < 1e-12);
    assert(abs(S(1)) < 1e-10);
    assert(norm(R,inf) < 1e-10);
    fprintf('PASS T02/T03: signed thermal free expansion at T=%g\n',dT);
    passCount = passCount+1;
end

%% T04: Fully restrained thermal contraction gives tensile stress
file = fullfile(workDir, 'restrained_thermal.txt');
writeCase(file, {'#node','n1,0,0','n2,2,0','#element','e1,1,2', ...
   '#boundry_condition','n1,0,0','n2,0,0','#metadata','E,1000','A,1','alpha,0.001','T,-20'});
evalc('[U,S,R] = Truss(file,opts);');
assert(norm(U,inf)==0);
assert(abs(S(1)-20) < 1e-10);
assert(abs(sum(R(1:2:end))) < 1e-10);
fprintf('PASS T04: restrained negative thermal load\n'); passCount=passCount+1;

%% T05: Nonzero prescribed end displacement, free middle axial DOF
file = fullfile(workDir, 'prescribed_displacement.txt');
writeCase(file, {'#node','n1,0,0','n2,1,0','n3,2,0', ...
    '#element','e1,1,2','e2,2,3','#boundry_condition','n1,0,0','n2,,0','n3,0.02,0', ...
    '#metadata','E,1000','A,1'});
evalc('[U,S,R] = Truss(file,opts);');
assert(abs(U(3)-0.01)<1e-12);
assert(norm(S-[10;10],inf)<1e-10);
assert(abs(R(1)+10)<1e-10 && abs(R(5)-10)<1e-10);
fprintf('PASS T05: nonzero prescribed displacement\n'); passCount=passCount+1;

%% T06: Directly applied support load must be included in reaction
file = fullfile(workDir, 'support_load.txt');
writeCase(file, {'#node','n1,0,0','n2,1,0', '#element','e1,1,2', ...
    '#boundry_condition','n1,0,0','n2,,0','#force','n1,5,0', ...
    '#metadata','E,1000','A,1'});
evalc('[U,S,R] = Truss(file,opts);');
assert(abs(R(1)+5)<1e-11 && norm(R(2:end),inf)<1e-11);
fprintf('PASS T06: support force correctly included in reaction\n'); passCount=passCount+1;

%% T07: Singular DOF detection
file = fullfile(workDir, 'singular.txt');
writeCase(file, {'#node','n1,0,0','n2,1,0', '#element','e1,1,2', ...
    '#boundry_condition','n1,0,0','#metadata','E,1000','A,1'});
assertThrows(@() Truss(file,opts), 'Truss:SingularSystem');
fprintf('PASS T07: mechanism detected\n'); passCount=passCount+1;

%% T08: Full explicit input validation
base = {'#node','n1,0,0','n2,1,0','#element','e1,1,2', ...
    '#boundry_condition','n1,0,0','n2,,0','#metadata','E,1000','A,1'};
invalid = { ...
    {'#node','n1,0,0','n1,1,0','#element','e1,1,2','#metadata','E,1000','A,1'}, ...
    {'#node','n1,0,0','n2,1,0','#element','e1,1,3','#metadata','E,1000','A,1'}, ...
    {'#node','n1,0,0','n2,0,0','#element','e1,1,2','#metadata','E,1000','A,1'}, ...
    {'#node','n1,0,0','n2,1,0','#element','e1,1,2','e2,2,1','#metadata','E,1000','A,1'}, ...
    {'#node','n1,0,0','n2,1,0','#element','e1,1,2','#metadata','E,-10','A,1'}, ...
    {'#node','n1,0,0','n2,1,0','#element','e1,1,2','#metadata','E,1000','A,0'}, ...
    {'#node','n1,0,0','n2,1,0','#element','e1,1,2','#force','n2,NaN,0','#metadata','E,1000','A,1'}, ...
    {'#node','n1,0,0','n2,1,0','#element','e1,1,2','#force','n99,10,0','#metadata','E,1000','A,1'}, ...
    {'#node','n1,0,0','n2,1,0','#element','e1,1,2','#boundry_condition','n1,0,0','n1,1,0','#metadata','E,1000','A,1'}, ...
    {'#node','n1,0,0','n2,1,0','#element','e1,1,2','#metadata','E,1000'}, ...
    {'#node','n1,0,0','n2,1,0','#element','e1,1,2','#bad_section','E,1000','A,1'} ...
};
for j=1:numel(invalid)
    f=fullfile(workDir,sprintf('invalid_%02d.txt',j));
    writeCase(f,invalid{j});
    assertThrows(@() processFile(f), 'Truss:InputError');
end
assertThrows(@() processFile(fullfile(workDir,'missing.txt')), 'Truss:InputError');
% Repeated loads add; blank roller DOF remains free.
file=fullfile(workDir,'repeated_forces.txt');
writeCase(file, [base, {'#force','n2,5,-3','n2,-2,4'}]);
[~,~,f,bc]=processFile(file);
assert(f(3)==3 && f(4)==1 && isnan(bc(3)) && bc(4)==0);
fprintf('PASS T08: %d malformed inputs + missing file + repeated loads\n',numel(invalid));
passCount=passCount+1;

%% T09: Color mapping covers mixed signs, one sign, and all zero
[limits,map]=trussColorMap([-200;37],256);
assert(all(abs(limits-[-200 37]) < 1e-12) && all(map(:)>=0) && all(map(:)<=1));
[limits,map]=trussColorMap(zeros(3,1),256);
assert(isequal(limits,[-1 1]) && all(isfinite(map(:))));
[limits,~]=trussColorMap([-5;-1],256);
assert(isequal(limits,[-5 0]));
fprintf('PASS T09: diverging color maps\n'); passCount=passCount+1;

%% T10: Four independently exported PNGs with zero solution
imageRoot = fullfile(workDir, 'images'); mkdir(imageRoot);
nodes=[0 0;1 0]; elements=[1 2]; uu=zeros(4,1); ss=0;
popts=struct('imageDPI',110,'showNodeIDs',false,'showFigures',false,'deformationScale',[]);
plotTrussGeometry(nodes,elements,[0;0;NaN;0],zeros(4,1),fullfile(imageRoot,'01.png'),popts);
plotDisplacement(nodes,elements,uu,fullfile(imageRoot,'02.png'),popts);
plotAxialStress(nodes,elements,ss,fullfile(imageRoot,'03.png'),popts);
[eT,eM,eTh]=computeElementStrain(nodes,elements,uu,0,0);
plotAxialStrain(nodes,elements,eT,eM,eTh,fullfile(imageRoot,'04.png'),popts);
for j=1:4
    info = dir(fullfile(imageRoot,sprintf('%02d.png',j)));
    assert(numel(info)==1 && info.bytes>1000,'PNG missing or suspiciously small');
end
fprintf('PASS T10: 4 exported PNGs\n'); passCount=passCount+1;

fprintf('\n===== SUCCESS: %d regression groups passed =====\n', passCount);

function writeCase(filename,lines)
    fid=fopen(filename,'wt');
    assert(fid>=0, 'Could not write test fixture.');
    cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
    for k=1:numel(lines)
        fprintf(fid,'%s\n',lines{k});
    end
end

function assertThrows(fn,expectedID)
    try
        fn();
    catch ME
        assert(strcmp(ME.identifier,expectedID), ...
            'Unexpected exception %s: %s', ME.identifier,ME.message);
        return;
    end
    error('Truss:TestFailed', 'Expected %s but no error occurred.',expectedID);
end
