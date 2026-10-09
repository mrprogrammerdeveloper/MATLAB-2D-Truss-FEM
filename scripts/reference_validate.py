"""Independent SciPy truss FEM numerical validation.

Run: python scripts/reference_validate.py
This is NOT a MATLAB execution and does not validate MATLAB graphics.
"""
from pathlib import Path
import math
import re
import sys
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.linalg import spsolve

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / 'input matlab files'


def read_case(path):
    node, elem, forces, bcs = [], [], [], []
    material = {'E': None, 'A': None, 'alpha': 0., 'T': 0.}
    section = ''
    for raw in path.read_text(encoding='utf-8-sig').splitlines():
        line = raw.strip()
        if not line or line.startswith('%'):
            continue
        if line.startswith('#'):
            section = line.lower()
            continue
        tok = [x.strip() for x in line.split(',')]
        if section == '#node':
            assert int(tok[0][1:]) == len(node)+1
            node.append([float(tok[1]),float(tok[2])])
        elif section == '#element':
            assert int(tok[0][1:]) == len(elem)+1
            elem.append([int(tok[1])-1,int(tok[2])-1])
        elif section == '#force':
            forces.append((int(tok[0][1:])-1,float(tok[1]),float(tok[2])))
        elif section in ('#boundry_condition','#boundary_condition'):
            bcs.append((int(tok[0][1:])-1,tok[1:]))
        elif section == '#metadata':
            material[tok[0]] = float(tok[1])
        else: raise ValueError(f'Unknown section: {section}')
    node = np.array(node,dtype=float)
    elem = np.array(elem,dtype=int)
    N=len(node)
    f=np.zeros(2*N)
    u_pres=np.full(2*N,np.nan)
    for k,x,y in forces:
        f[2*k] += x; f[2*k+1] += y
    for k,entries in bcs:
        for d,val in enumerate(entries):
            if val and val.lower() != 'nan':u_pres[2*k+d] = float(val)
    return node,elem,f,u_pres,material


def solve(case):
    node,elem,f,u_pres,m=case
    N=len(node); E=m['E'];A=m['A']; alpha=m['alpha']; T=m['T']
    assert E>0 and A>0
    ids=[]; jds=[]; data=[]
    fth=np.zeros(2*N)
    for ni,nj in elem:
        delta=node[nj]-node[ni]
        L=np.linalg.norm(delta)
        assert L>0
        c,s=delta/L
        B=np.array([-c,-s,c,s])
        dof=np.array([2*ni,2*ni+1,2*nj,2*nj+1])
        k=np.outer(B,B)*(E*A/L)
        ids.extend(np.repeat(dof,4))
        jds.extend(np.tile(dof,4))
        data.extend(k.ravel())
        fth[dof]+=E*A*alpha*T*B
    K=coo_matrix((data,(ids,jds)),shape=(2*N,2*N)).tocsr()
    free=np.where(np.isnan(u_pres))[0]
    fixed=np.where(~np.isnan(u_pres))[0]
    u=u_pres.copy()
    if len(free):
        u[free]=spsolve(K[free,:][:,free],f[free]+fth[free]-K[free,:][:,fixed]@u[fixed])
    stress=[]
    strains=[]
    for ni,nj in elem:
        delta=node[nj]-node[ni]
        L=np.linalg.norm(delta)
        c,s=delta/L
        B=np.array([-c,-s,c,s])
        dof=[2*ni,2*ni+1,2*nj,2*nj+1]
        eps=(B@u[dof])/L-alpha*T
        stress.append(E*eps)
        strains.append(eps)
    stress=np.array(stress)
    reactions=K@u-f-fth
    residual=np.linalg.norm(reactions[free],ord=np.inf) if len(free) else 0
    support_reactions=np.zeros(2*N)
    support_reactions[fixed]=reactions[fixed]
    equilibrium=np.array([sum((support_reactions+f)[::2]),sum((support_reactions+f)[1::2])])
    return dict(U=u,S=stress,R=support_reactions,eq=equilibrium,residual=residual,K=K)


def check(label,condition):
    assert condition,label
    print('PASS:',label)


def main():
    # Static regression guards for critical MATLAB implementation changes.
    truss=(ROOT/'Truss.m').read_text()
    thermal=(ROOT/'K_GLOBAL.m').read_text()
    reader=(ROOT/'processFile.m').read_text()
    check('MATLAB signed thermal assembly guard', 'if(T ~= 0 && alpha ~= 0)' in thermal)
    check('MATLAB prescribed displacement RHS term', 'K(freeDOF, fixedDOF) * BC(fixedDOF)' in truss)
    check('MATLAB support reaction includes applied loads', '- force(fixedDOF)' in truss)
    check('MATLAB parser validates zero lengths and connectivity', 'Zero-length element' in reader and 'Duplicate element connectivity' in reader)

    for name in ('problem-1.txt','problem-2-without-thermal.txt','problem-2-with-thermal.txt','test_1.txt'):
        case=read_case(INPUT/name)
        sol=solve(case)
        N=len(case[0]); M=len(case[1]);
        check(f'{name}: finite, equilibrated {N}-node/{M}-element solution',
              np.all(np.isfinite(sol['U'])) and np.all(np.isfinite(sol['S']))
              and sol['residual']<1e-3 and np.max(np.abs(sol['eq']))<1e-3)
        if name=='test_1.txt':
            check('186/485 reference geometry',N==186 and M==485)
            check('benchmark maximum displacement', abs(np.max(np.hypot(sol['U'][::2],sol['U'][1::2]))-0.0438933)<5e-6)
            check('benchmark maximum tension', abs(np.max(sol['S'])/1e6-37.13704508)<0.01)
            check('benchmark maximum compression', abs(np.min(sol['S'])/1e6+216.9640075)<0.01)
            i=int(np.argmax(np.hypot(sol['U'][::2],sol['U'][1::2])))+1
            check('benchmark maximum displacement node n16',i==16)
            print(f'REFERENCE: maxU={np.max(np.hypot(sol["U"][::2],sol["U"][1::2])):.9f} m; '
                  f'maxS={np.max(sol["S"])/1e6:.6f} MPa; '
                  f'minS={np.min(sol["S"])/1e6:.6f} MPa')

    # Independent analytic simple bar cases: thermal signs and displacement constraints.
    nodes=np.array([[0,0],[2,0]],float)
    elem=np.array([[0,1]])
    for T in (-20,0,20):
        Upre=np.array([0,0,np.nan,0],float)
        case=(nodes,elem,np.zeros(4),Upre,{'E':1000.,'A':1.,'alpha':.001,'T':T})
        sol=solve(case)
        check(f'analytic free thermal bar ΔT={T}: u=αΔTL and σ=0',
              abs(sol['U'][2]-.001*T*2)<1e-13 and abs(sol['S'][0])<1e-10)
    case=(nodes,elem,np.zeros(4),np.zeros(4),{'E':1000.,'A':1.,'alpha':.001,'T':-20})
    sol=solve(case)
    check('analytic restrained cooling: positive 20 Pa stress',abs(sol['S'][0]-20)<1e-10)
    nodes=np.array([[0,0],[1,0],[2,0]],float);elem=np.array([[0,1],[1,2]])
    case=(nodes,elem,np.zeros(6),np.array([0,0,np.nan,0,.02,0]),{'E':1000.,'A':1.,'alpha':0.,'T':0.})
    sol=solve(case)
    check('analytic nonzero prescribed settlement',abs(sol['U'][2]-.01)<1e-12 and np.max(abs(sol['S']-10))<1e-11)
    nodes=np.array([[0,0],[1,0]],float);elem=np.array([[0,1]])
    case=(nodes,elem,np.array([5,0,0,0]),np.array([0,0,np.nan,0]),{'E':1000.,'A':1.,'alpha':0.,'T':0.})
    sol=solve(case)
    check('analytic externally loaded support reaction',abs(sol['R'][0]+5)<1e-11)
    print('INDEPENDENT PYTHON REFERENCE TESTS PASSED (not MATLAB execution)')

if __name__=='__main__':
    try:main()
    except Exception as exc:
        print('FAIL:',repr(exc),file=sys.stderr)
        sys.exit(1)
