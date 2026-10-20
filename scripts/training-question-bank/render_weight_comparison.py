#!/usr/bin/env python3
"""Render measured proportions on linear axes without third-party plotting dependencies."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/accuracy-weight-review-20261021'
s=json.loads((OUT/'summary.json').read_text())
font=lambda n:ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',n)
im=Image.new('RGB',(1700,700),'#f4f7f6');d=ImageDraw.Draw(im)
d.text((50,25),'同一套目标权重 · 每种方法实抽20万题',font=font(34),fill='#193d32')
colors=['#a6b4ae','#d88b32','#26775e']
for j,label in enumerate(['目标权重','原顺序抽样','校准对照']):
 x=50+j*240;d.rectangle((x,85,x+24,109),fill=colors[j]);d.text((x+35,82),label,font=font(24),fill='#193d32')
for side,axis in enumerate([3,4]):
 left=90+side*830;bottom=580;top=180;width=690;maximum=60 if axis==3 else 100
 d.text((left,132),s['names'][axis],font=font(29),fill='#193d32')
 for percent in range(0,maximum+1,20):
  y=bottom-(bottom-top)*percent/maximum;d.line((left,y,left+width,y),fill='#d7e0db',width=1);d.text((left-57,y-11),str(percent)+'%',font=font(18),fill='#50675e')
 values=[s['weights'][axis],s['sequential']['actual'][axis],s['calibrated']['actual'][axis]]
 for group in range(3):
  center=left+115+group*230
  label=s['labels'][axis][group];box=d.textbbox((0,0),label,font=font(25));d.text((center-(box[2]-box[0])/2,bottom+18),label,font=font(25),fill='#193d32')
  for j,series in enumerate(values):
   x=center+(j-1)*65-25;v=100*series[group];y=bottom-(bottom-top)*v/maximum
   d.rectangle((x,y,x+50,bottom),fill=colors[j]);txt=f'{v:.1f}%';box=d.textbbox((0,0),txt,font=font(20));d.text((x+25-(box[2]-box[0])/2,y-30),txt,font=font(20),fill='#193d32')
d.text((50,650),'当前题库分布模拟，含未验证角袋候选；校准方法仅为离线对照。',font=font(23),fill='#50675e')
im.save(OUT/'权重偏差对比.png')
p=OUT/'随机权重模拟.html';h=p.read_text();marker='<div class="scroll">';tag='<img src="权重偏差对比.png" alt="目标球距袋和库边权重对比" style="width:100%;height:auto">'
if tag not in h:h=h.replace(marker,tag+marker,1)
h=h.replace('未修改App抽题器或题库。','未修改App抽题器或题库；这里只模拟默认全随机，用户多选筛选后的分布尚未模拟。');p.write_text(h)
