"""Transform the user-supplied recording and our original instrumental stems."""
from pathlib import Path
import concurrent.futures, json, math, subprocess
import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT=Path(__file__).resolve().parents[2]
WORK=Path('/tmp/queen-mashup')
OUT=ROOT/'output/music'
SR=44100
report=json.loads((WORK/'analysis.json').read_text())
features=np.load(WORK/'features.npz')
onset=features['onset'].astype(float)
env_rate=float(features['onset_rate'])
period=60/report['bpm']*env_rate
# Dynamic-program beat path followed by gentle smoothing retains the band's tempo drift.
normalized=onset/(np.std(onset)+1e-8)
score=np.zeros(len(onset)); back=np.full(len(onset),-1,dtype=int)
offsets=np.arange(round(period*.65),round(period*1.35)+1)
penalty=45*np.log(offsets/period)**2
for i in range(len(onset)):
    valid=offsets<=i
    if not np.any(valid): score[i]=normalized[i]; continue
    prev=i-offsets[valid]
    candidates=score[prev]-penalty[valid]
    k=np.argmax(candidates)
    if candidates[k]>0:
        score[i]=normalized[i]+candidates[k]; back[i]=prev[k]
    else: score[i]=normalized[i]
end_range=np.arange(max(0,len(onset)-round(period*2)),len(onset))
point=int(end_range[np.argmax(score[end_range])]); beats=[]
while point>=0:
    beats.append(point/env_rate)
    point=back[point]
beats=np.array(beats[::-1])
beats=signal.savgol_filter(beats,9,2)
# Anchor complete bars at the first reliable beat, retaining the original opening.
beats=beats[beats>=0]
bars=beats[::4]
sr,queen=wavfile.read(WORK/'queen.wav')
queen=queen.astype(np.float32)/32768
duration=len(queen)/sr
bars=bars[(bars>=0)&(bars<duration-2.0)]
chroma=features['chroma']; times=features['times']
templates={
 'D':([2,6,9],2),'A':([9,1,4],9),'G':([7,11,2],7),
 'Bm':([11,2,6],11),'Em':([4,7,11],4),'F#m':([6,9,1],6),
}

def chord_for(start,end):
    vec=chroma[:,(times>=start)&(times<end)].sum(axis=1)
    vec=vec/(np.linalg.norm(vec)+1e-9)
    scores={}
    for name,(notes,root) in templates.items():
        template=np.zeros(12)
        template[notes]=1
        template[root]=1.3
        scores[name]=float(np.dot(vec,template/np.linalg.norm(template)))
    return max(scores,key=scores.get)

# Bar starts in A Crown of Stars, preserving each section's original tempo.
sections=[(0,8,3,84),(17.1428571429,12,4,96),(47.1428571429,4,4,108),
          (56.0317460318,12,4,124),(79.2575524834,8,3,108),
          (92.5908858167,8,4,128),(107.5908858167,12,4,128)]
verse=sections[1][0]; anthem=sections[3][0]; solo=sections[5][0]
verse_chords=['D','A','Bm','F#m','G','D','Em','A','D','D','G','A']
anthem_chords=['D','A','G','D','Em','A','D','A','Bm','G','A','D']
solo_chords=['D','G','Bm','A','D','G','A','A']
sources={}
for family,start,bpm,chords in [('verse',verse,96,verse_chords),('anthem',anthem,124,anthem_chords),('solo',solo,128,solo_chords)]:
    for i,chord in enumerate(chords):
        sources[(family,i)]={'time':start+i*4*60/bpm,'bpm':bpm,'chord':chord}

def render_bar(key):
    family,index,stem=key
    source=sources[(family,index)]
    output=WORK/f'{family}-{index}-{stem}.wav'
    if not output.exists():
        subprocess.run(['ffmpeg','-y','-hide_banner','-loglevel','error','-ss',str(source['time']),
          '-t',str(4*60/source['bpm']+.05),'-i',f'/tmp/duet-rock/{stem}.wav',
          '-af',f"rubberband=tempo={report['bpm']/source['bpm']}:pitch={2**(-1/12)}:transients=mixed:phase=laminar",
          '-ar',str(SR),str(output)],check=True)
    _,data=wavfile.read(output)
    return key,data[:round(4*60/report['bpm']*SR)].astype(np.float32)/32768

keys=[(family,i,stem) for family,i in sources for stem in (['piano'] if family=='verse' else ['piano','lead','rhythm'])]
cache={}
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
    for key,data in pool.map(render_bar,keys): cache[key]=data
print('Retimed and transposed original stems:',len(cache),flush=True)

center=queen.mean(axis=1)
side=(queen[:,0]-queen[:,1])*.5
vocal_filter=signal.butter(2,[450,3500],btype='bandpass',fs=SR,output='sos')
c=signal.sosfilt(vocal_filter,center).astype(np.float32)
s=signal.sosfilt(vocal_filter,side).astype(np.float32)
# A slow, conservative centre-energy envelope gives room to the supplied vocal.
smooth=signal.butter(1,3,fs=SR,output='sos')
ce=np.sqrt(np.maximum(signal.sosfilt(smooth,c*c),0))
se=np.sqrt(np.maximum(signal.sosfilt(smooth,s*s),0))
prominence=np.clip((ce-se*.65)/(np.percentile(ce,85)+1e-8),0,1)
duck=(1-.62*prominence).astype(np.float32)
overlay=np.zeros_like(queen)
guitars=np.zeros_like(queen)
details=[]
phrase_counter={'verse':0,'anthem':0,'solo':0}
for b in range(len(bars)-1):
    start,end=float(bars[b]),float(bars[b+1])
    if end-start<1.7 or end-start>2.6: continue
    chord=chord_for(start,end)
    # Thin accompaniment under verses, stronger original hooks in selected passages.
    if start<19: family='anthem'; lead_gain=1.05; piano_gain=.55; rhythm_gain=0
    elif start<57: family='verse'; lead_gain=0; piano_gain=.7; rhythm_gain=0
    elif start<85: family='anthem'; lead_gain=.65; piano_gain=.48; rhythm_gain=.16
    elif start<125: family='verse'; lead_gain=0; piano_gain=.65; rhythm_gain=0
    elif start<147: family='solo'; lead_gain=.78; piano_gain=.32; rhythm_gain=.16
    elif start<187: family='verse'; lead_gain=0; piano_gain=.7; rhythm_gain=0
    elif start<225: family='anthem'; lead_gain=.65; piano_gain=.5; rhythm_gain=.17
    else: family='anthem'; lead_gain=.85; piano_gain=.47; rhythm_gain=.1
    options=[i for fam,i in sources if fam==family and sources[(fam,i)]['chord']==chord]
    if not options:
        family='verse'
        options=[i for fam,i in sources if fam==family and sources[(fam,i)]['chord']==chord]
    expected=phrase_counter[family]
    index=min(options,key=lambda i:(i-expected)%(8 if family=='solo' else 12))
    phrase_counter[family]=index+1
    i0=round(start*SR); i1=round(end*SR); length=i1-i0
    details.append({'start':round(start,3),'end':round(end,3),'chord':chord,'original_section':family,'original_bar':index+1})
    for stem,gain in [('piano',piano_gain),('lead',lead_gain),('rhythm',rhythm_gain)]:
        key=(family,index,stem)
        if gain==0 or key not in cache: continue
        data=cache[key]
        # Match the small remaining human timing variations from bar to bar.
        ratio=length/len(data)
        x=np.linspace(0,len(data)-1,length)
        fitted=np.column_stack([np.interp(x,np.arange(len(data)),data[:,ch]) for ch in range(2)]).astype(np.float32)
        fade=min(round(.035*SR),length//4)
        fitted[:fade]*=np.linspace(0,1,fade)[:,None]
        fitted[-fade:]*=np.linspace(1,0,fade)[:,None]
        if stem=='piano': overlay[i0:i1]+=fitted*gain
        else: guitars[i0:i1]+=fitted*gain

# Gentle guitar cabinet roll-off and spatial delay preserve space for the source vocal.
guitars=signal.sosfilt(signal.butter(2,[150,4900],btype='bandpass',fs=SR,output='sos'),guitars,axis=0).astype(np.float32)
guitars=np.tanh(guitars*2.2)/1.5
delay=round(.17*SR)
guitars[delay:]+=guitars[:-delay,::-1].copy()*.12
mix=queen*.80+overlay*2.5*(.65+.35*duck[:,None])+guitars*1.8*duck[:,None]
mix=np.tanh(mix*1.05).astype(np.float32)
fade=round(.8*SR)
mix[-fade:]*=np.linspace(1,0,fade)[:,None]
wavfile.write(WORK/'mix.wav',SR,np.int16(np.clip(mix,-1,1)*32767))
notes={'title':'Under Pressure × A Crown of Stars','duration_seconds':duration,'tempo_bpm_estimate':report['bpm'],
 'key':'D major','source_recording':'User-supplied Queen - Under Pressure.opus',
 'original_material':'Piano and harmonized guitar stems from A Crown of Stars',
 'arrangement':'Original recording retained with chord-matched, transposed and tempo-aligned piano/guitar overlays; vocal-aware ducking.',
 'bars':details}
(OUT/'Under-Pressure-x-A-Crown-of-Stars-arrangement.json').write_text(json.dumps(notes,indent=2)+'\n')
print('Mashup mix complete:',duration,'seconds;',len(details),'aligned bars.',flush=True)
