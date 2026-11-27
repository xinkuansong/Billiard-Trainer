from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import PowerNorm
from lookup import PipeGrid
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/pocket-pipe-precompute-20261104';g=PipeGrid(OUT)
values=np.zeros((len(g.x),len(g.z),6))
for ix in range(len(g.x)):
 for iz in range(len(g.z)):
  for p in range(6):
   ranges,flags=g.record(ix,iz,p)
   values[ix,iz,p]=max((b-a for a,b in ranges),default=0) if flags&7==7 else np.nan
fig,axes=plt.subplots(3,2,figsize=(13,10),constrained_layout=True)
for p,ax in enumerate(axes.flat):
 art=ax.pcolormesh(g.x,g.z,values[:,:,p].T,shading='auto',cmap='viridis',norm=PowerNorm(.4,vmin=0,vmax=np.nanmax(values)))
 center=g.meta['pockets'][p]['center'];ax.scatter(*center,s=80,facecolor='#e85e30',edgecolor='white',zorder=5)
 ax.set_title(f'Pocket {p}: target-ball clean pipe angle');ax.set_aspect('equal');ax.set_ylim(.70,-.70);ax.set_xlim(-1.34,1.34)
 ax.set_xlabel('X (m)');ax.set_ylabel('Z (m), downward')
fig.colorbar(art,ax=axes.ravel().tolist(),label='Maximum contiguous window (degrees)',shrink=.8)
fig.suptitle('Target-only precomputed pipe windows · ~1 cm grid + 1/2/5 mm rail offsets\nNo cue ball, blockers, speed, spin or jaw rebound',fontsize=15)
fig.savefig(OUT/'six-pocket-windows.png',dpi=150);fig.savefig(OUT/'six-pocket-windows.svg')
