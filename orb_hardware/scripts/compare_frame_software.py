"""Compare the saved UDP frame with matching arithmetic and OpenCV ORB."""
import json
import re
import statistics
import time
from pathlib import Path
import cv2
import numpy as np
from fast_check import opencv_fast

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/tests/2026-11-25-software-comparison'
OUT.mkdir(parents=True, exist_ok=True)
color = cv2.imread(str(ROOT / 'orb_test_output/tum_images/freiburg1_desk.png'))
gray = cv2.cvtColor(color, cv2.COLOR_BGR2GRAY)
records = [line.split() for line in (ROOT / 'orb_test_output/frame_udp_2026-11-25/descriptors.txt').read_text().splitlines()]
hardware = [(int(o),int(x),int(y),int(a),int(d,16)) for o,x,y,a,d in records]
pattern_text = (ROOT / 'orb_hardware/rtl/common/brief_pattern.sv').read_text()
pattern = []
for row in re.findall(r"'\{([^{}]+)\}", pattern_text):
    values = re.findall(r"(-?)6'sd\s*(\d+)",row)
    if len(values) == 4:
        pattern.append([(-1 if s else 1)*int(v) for s,v in values])
pattern = np.array(pattern,dtype=np.int64)
assert pattern.shape == (256,4)
sin_table = np.array([6,19,31,43,55,66,76,86,95,103,110,116,121,124,127,127])
tangents = np.array([25,51,78,106,137,171,210,256,312,383,479,618,844,1287,2599])

def scale(image):
    h,w = image.shape
    xs = np.arange(w*5//6)*6
    ys = np.arange(h*5//6)*6
    x,y = xs//5,ys//5
    fx,fy = xs%5,ys%5
    image = image.astype(np.int64)
    top = image[y[:,None],x]*(5-fx)+image[y[:,None],np.minimum(x+1,w-1)]*fx
    bottom = image[np.minimum(y+1,h-1)[:,None],x]*(5-fx)+image[np.minimum(y+1,h-1)[:,None],np.minimum(x+1,w-1)]*fx
    return ((top*(5-fy[:,None])+bottom*fy[:,None])//25).astype(np.uint8)

def matching_software():
    pyramid=[gray]
    for _ in range(2): pyramid.append(scale(pyramid[-1]))
    outputs=[]
    weights=np.array([1,6,15,20,15,6,1],dtype=np.float64)
    for octave,image in enumerate(pyramid):
        h,w=image.shape
        blur=(cv2.sepFilter2D(image.astype(np.float64),-1,weights,weights)/4096).astype(np.uint8)
        candidates=opencv_fast(image,20)
        for x,y in sorted(candidates,key=lambda p:(p[1],p[0])):
            if not (21<=x<w-21 and 21<=y<h-21): continue
            patch=blur[y-18:y+19,x-18:x+19].astype(np.int64)
            axis=np.arange(-18,19)
            mx=int((patch*axis).sum()); my=int((patch*axis[:,None]).sum())
            q=(2 if mx<0 else 3) if my<0 else (1 if mx<0 else 0)
            k=int(np.count_nonzero(abs(mx)*tangents<=abs(my)*256)) if my else 0
            sine=int(sin_table[k])*(-1 if q>=2 else 1)
            cosine=int(sin_table[15-k])*(-1 if q in (1,2) else 1)
            rx=(pattern[:,[0,2]]*cosine-pattern[:,[1,3]]*sine+64)>>7
            ry=(pattern[:,[0,2]]*sine+pattern[:,[1,3]]*cosine+64)>>7
            pixels=patch[ry+18,rx+18]>>2
            bits=pixels[:,0]>pixels[:,1]
            descriptor=sum(int(bit)<<i for i,bit in enumerate(bits))
            angle=q*16+(15-k if q%2 else k)
            outputs.append((octave,x,y,angle,descriptor))
    return outputs

cv2.setNumThreads(1)
start=time.perf_counter(); software=matching_software(); matched_ms=(time.perf_counter()-start)*1000
orb=cv2.ORB_create()
for _ in range(5): orb.detectAndCompute(gray,None)
times=[]
for _ in range(30):
    start=time.perf_counter(); keys,desc=orb.detectAndCompute(gray,None); times.append((time.perf_counter()-start)*1000)
lookup={(o,x,y):(a,d) for o,x,y,a,d in software}
shared=[(r,lookup[r[:3]]) for r in hardware if r[:3] in lookup]
angle_matches=sum(r[3]==s[0] for r,s in shared)
descriptor_matches=sum(r[4]==s[1] for r,s in shared)
bit_errors=[(r[4]^s[1]).bit_count() for r,s in shared]
summary=dict(image='TUM Freiburg1 desk, 640x480',opencv_version=cv2.__version__,
    hardware=dict(levels=3,engines=[2,2,1],features=len(hardware),per_level=[sum(r[0]==i for r in hardware) for i in range(3)],
                  simulated_total_ms=26.984740,includes_camera_and_ethernet=True),
    matching_software=dict(levels=3,features=len(software),per_level=[sum(r[0]==i for r in software) for i in range(3)],
                           runtime_ms=matched_ms,implementation='Python/NumPy/OpenCV arithmetic model, unlimited engine availability'),
    standard_opencv=dict(levels=orb.getNLevels(),max_features=orb.getMaxFeatures(),features=len(keys),
                         per_level=[sum(k.octave==i for k in keys) for i in range(orb.getNLevels())],
                         median_runtime_ms=statistics.median(times),runs=30,cpu_threads=1),
    hardware_vs_matching=dict(shared_coordinates=len(shared),angle_exact=angle_matches,descriptor_exact=descriptor_matches,
                             mean_hamming=float(np.mean(bit_errors)) if bit_errors else None,
                             software_only=len(software)-len(shared),hardware_only=len(hardware)-len(shared)))
(OUT/'results.json').write_text(json.dumps(summary,indent=2)+'\n')

palette=[(70,230,70),(255,190,40),(220,80,255),(50,210,255),(255,120,80),(180,220,60),(160,160,255),(240,240,240)]
def overlay(records):
    image=color.copy()
    for o,x,y,*_ in records:
        cv2.circle(image,(round(x*1.2**o),round(y*1.2**o)),2,palette[o],1,cv2.LINE_AA)
    return image
panels=[overlay(hardware),overlay(software),color.copy()]
for k in keys: cv2.circle(panels[2],tuple(round(v) for v in k.pt),2,palette[k.octave],1,cv2.LINE_AA)
canvas=np.full((550,1920,3),24,np.uint8)
labels=[f'FPGA 3 levels, 2/2/1 BRIEF: {len(hardware)}',f'Matching software, unlimited: {len(software)}',f'OpenCV default, 8 levels: {len(keys)}']
for i,(panel,label) in enumerate(zip(panels,labels)):
    cv2.putText(canvas,label,(i*640+12,30),cv2.FONT_HERSHEY_SIMPLEX,.64,(245,245,245),1,cv2.LINE_AA)
    canvas[45:525,i*640:(i+1)*640]=panel
cv2.putText(canvas,'Same TUM desk frame | color = octave | hardware drops included; software has no hardware scheduling limit',
            (12,545),cv2.FONT_HERSHEY_SIMPLEX,.55,(230,230,230),1,cv2.LINE_AA)
cv2.imwrite(str(OUT/'side-by-side.png'),canvas)
print(json.dumps(summary,indent=2))
