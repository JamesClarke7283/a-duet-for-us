"""Original instrumental composition and offline stereo production."""
from pathlib import Path
import json, math, struct, subprocess
import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/music'
WORK = Path('/tmp/duet-song')
SR, BPM, PPQ = 44100, 124, 480
BEAT = 60 / BPM
BARS = 80
DURATION = BARS * 4 * BEAT + 3
RNG = np.random.default_rng(7814)
OUT.mkdir(parents=True, exist_ok=True)

# Entirely original motifs. Tuples are pitch (MIDI), duration in beats.
HOOK = [
 [(78,.5),(76,.5),(74,.75),(69,.25),(74,1),(78,.75),(76,.25)],
 [(76,.5),(73,.5),(71,1),(69,1),(76,.5),(78,.5)],
 [(78,1),(81,.5),(78,.5),(76,1),(74,.5),(71,.5)],
 [(74,.75),(71,.25),(69,.5),(71,.5),(74,1),(76,1)],
 [(78,.5),(81,.5),(83,.5),(81,.5),(78,1),(76,.5),(74,.5)],
 [(76,.5),(73,.5),(69,.5),(71,.5),(73,1),(76,1)],
 [(74,.5),(71,.5),(69,.5),(66,.5),(67,1),(71,1)],
 [(69,1),(73,.5),(76,.5),(74,1.5),(0,.5)],
]
VERSE = [
 [(66,.75),(69,.25),(71,1),(69,1),(66,.5),(0,.5)],
 [(64,1),(66,.5),(69,.5),(73,1),(71,1)],
 [(66,.5),(69,.5),(71,1.5),(73,.5),(71,1)],
 [(67,1),(66,.5),(64,.5),(62,1.5),(0,.5)],
 [(66,.5),(69,.5),(74,1),(73,.5),(71,.5),(69,1)],
 [(64,.5),(66,.5),(69,1),(71,.75),(69,.25),(66,1)],
 [(66,1),(69,1),(71,.5),(69,.5),(66,.5),(64,.5)],
 [(67,.75),(66,.25),(64,1),(62,1.5),(0,.5)],
]
CHORDS = {
 'D':(50,[62,66,69,73]), 'A':(45,[61,64,69,71]),
 'Bm':(47,[62,66,71,73]), 'G':(43,[62,66,67,71]),
 'Em':(40,[62,64,67,71]), 'Asus':(45,[62,64,69,74]),
}
SECTIONS = [(0,4,'intro'),(4,20,'verse'),(20,28,'build'),(28,44,'chorus'),
            (44,52,'bridge'),(52,60,'build2'),(60,76,'final chorus'),(76,80,'outro')]

def section(bar):
    return next(name for start,end,name in SECTIONS if start<=bar<end)

def harmony(bar):
    part=section(bar)
    if part in ('chorus','final chorus'):
        return ['G','D','A','Bm','G','D','A','Asus'][(bar-(28 if bar<44 else 60))%8]
    if part in ('build','build2'):
        return ['Bm','G','D','A','Bm','G','Em','A'][bar%8]
    if part=='bridge': return ['Bm','A','G','D','Em','G','Asus','A'][bar%8]
    if part=='outro': return ['G','A','D','D'][bar-76]
    return ['D','A','Bm','G'][bar%4]

TRACKS = {name:[] for name in ['piano','guitar','warm keys','strings','bass','lead','drums']}

def note(track, beat, pitch, duration, velocity=80):
    if pitch:
        TRACKS[track].append((float(beat),int(pitch),float(duration),int(velocity)))

for bar in range(BARS):
    part=section(bar)
    root,voicing=CHORDS[harmony(bar)]
    base=bar*4
    full=part in ('chorus','final chorus')
    # A rolling piano figure and warm bass notes tie all the sections together.
    piano_vel=70 if full else 61
    if part=='bridge': piano_vel=53
    for t in [0,2]:
        note('piano',base+t,root,.9,piano_vel-13)
        note('piano',base+t,root+12,.8,piano_vel-18)
    pattern=[0,2,1,3,0,2,1,3]
    for step,index in enumerate(pattern):
        if part=='outro' and bar==79 and step>0: continue
        note('piano',base+step*.5+float(RNG.uniform(-.009,.009)),voicing[index],.42 if full else .7,piano_vel+int(RNG.integers(-7,7)))
    if full:
        for t in [0,1.5,2,3.5]:
            for p in voicing[:3]: note('piano',base+t,p,.35,52)
    if part=='outro' and bar==79:
        for p in [50,62,66,69,74]: note('piano',base,p,6,57)
    # Finger-picked verse guitar; syncopated strumming opens the chorus.
    guitar_notes=[root+12,voicing[0],voicing[1],voicing[2],voicing[3]]
    if not full:
        for step in range(8):
            if part=='outro' and bar==79: break
            p=guitar_notes[[0,2,3,1,4,2,3,1][step]]
            note('guitar',base+step*.5+.012,p,.7,52+int(RNG.integers(-6,7)))
    else:
        for t in [0,.75,1.5,2.5,3.25,3.5]:
            for j,p in enumerate(guitar_notes):
                note('guitar',base+t+j*.014,p,.36,48+int(RNG.integers(-5,5)))
    if part not in ('intro','outro') or bar==78:
        for p in voicing:
            note('strings',base,p-12,4.0,34 if full else 24)
    if part in ('verse','bridge'):
        phrase=VERSE[(bar-(4 if part=='verse' else 44))%8]
        at=base+(.25 if part=='verse' else 0)
        for p,d in phrase:
            note('warm keys',at,p+(12 if part=='bridge' and bar%2 else 0),d*.83,56 if part=='verse' else 44)
            at+=d
    if full or part in ('build','build2'):
        phrase=HOOK[(bar-(28 if bar<44 else 60))%8]
        at=base
        for p,d in phrase:
            note('lead',at,p,d*.88,94 if full else 60)
            at+=d
        for t in np.arange(0,4,.5): note('bass',base+float(t),root-12,.38,86 if full else 64)
    if full or (part=='verse' and bar>=12) or (part in ('build','build2') and bar%8<6):
        for t in range(4): note('drums',base+t,36,.15,110 if full else 82)
        for t in [1,3]: note('drums',base+t,39,.1,100 if full else 65)
    if part not in ('intro','bridge','outro'):
        for t in np.arange(.5,4,1): note('drums',base+float(t),46,.1,67 if full else 41)
        for t in np.arange(0,4,.5): note('drums',base+float(t),42,.07,45 if full else 30)
    if part in ('build','build2'):
        offset=bar-(20 if part=='build' else 52)
        spacing=.5 if offset<6 else (.25 if offset==6 else .125)
        for t in np.arange(0,4,spacing): note('drums',base+float(t),38,.06,44+offset*6)

def varlen(n):
    parts=[n&127]; n>>=7
    while n: parts.insert(0,(n&127)|128); n>>=7
    return bytes(parts)

def midi(path, tracks):
    chunks=[]
    tempo=int(60_000_000/BPM)
    conductor=b'\0\xff\x51\x03'+tempo.to_bytes(3,'big')+b'\0\xff\x58\x04\x04\x02\x18\x08'
    title=b'When the Lights Find Us - original instrumental'
    conductor+=b'\0\xff\x03'+varlen(len(title))+title
    conductor+=varlen((BARS*4+8)*PPQ)+b'\xff\x2f\0'
    chunks.append(b'MTrk'+len(conductor).to_bytes(4,'big')+conductor)
    programs={'piano':(0,0,98,61),'guitar':(1,25,88,36),'warm keys':(2,4,83,72),
              'strings':(3,48,51,86),'bass':(4,38,88,64),'lead':(5,81,92,64),'drums':(9,0,95,64)}
    for name in tracks:
        ch,program,vol,pan=programs[name]
        rawname=name.encode()
        data=b'\0\xff\x03'+varlen(len(rawname))+rawname
        data+=b'\0'+bytes([0xc0|ch,program])+b'\0'+bytes([0xb0|ch,7,vol])+b'\0'+bytes([0xb0|ch,10,pan])
        events=[]
        for start,p,duration,vel in TRACKS[name]:
            tick=max(0,round(start*PPQ))
            events.append((tick,1,bytes([0x90|ch,p,vel])))
            events.append((tick+round(duration*PPQ),0,bytes([0x80|ch,p,0])))
        events.sort(key=lambda event:(event[0],event[1]))
        previous=0
        for tick,_,payload in events:
            data+=varlen(tick-previous)+payload; previous=tick
        data+=varlen(max(1,(BARS*4+8)*PPQ-previous))+b'\xff\x2f\0'
        chunks.append(b'MTrk'+len(data).to_bytes(4,'big')+data)
    path.write_bytes(b'MThd\0\0\0\x06\0\x01'+len(chunks).to_bytes(2,'big')+PPQ.to_bytes(2,'big')+b''.join(chunks))

midi(OUT/'When-the-Lights-Find-Us.mid',TRACKS)
midi(WORK/'acoustic-bed.mid',['piano','guitar','warm keys','strings'])
sf=next(WORK.rglob('*.sf2'))
subprocess.run(['fluidsynth','-ni','-F',str(WORK/'bed.wav'),'-T','wav','-r',str(SR),'-g','0.7',
 '-o','synth.reverb.active=1','-o','synth.reverb.room-size=0.72','-o','synth.reverb.damp=0.45',
 '-o','synth.reverb.level=0.24','-o','synth.chorus.active=1',str(sf),str(WORK/'acoustic-bed.mid')],check=True,stdout=subprocess.DEVNULL)
print('Acoustic instruments rendered.',flush=True)
n=int(DURATION*SR)
rate,bed=wavfile.read(WORK/'bed.wav')
bed=bed.astype(np.float32)/32768
if bed.ndim==1: bed=np.column_stack([bed,bed])
acoustic=np.zeros((n,2),np.float32)
acoustic[:min(n,len(bed))]=bed[:n]
acoustic*=.46/max(float(np.max(np.abs(acoustic))),.01)
drums=np.zeros((n,2),np.float32)
synth=np.zeros((n,2),np.float32)
duck=np.ones(n,np.float32)

def add(bus,sound,beat,gain=1,pan=0):
    start=round(beat*BEAT*SR)
    if start<0: sound=sound[-start:]; start=0
    end=min(n,start+len(sound))
    if end<=start: return
    sound=sound[:end-start]
    if sound.ndim==1:
        bus[start:end,0]+=sound*(math.sqrt((1-pan)/2)*gain)
        bus[start:end,1]+=sound*(math.sqrt((1+pan)/2)*gain)
    else: bus[start:end]+=sound*gain

def synth_note(pitch,length,kind):
    f=440*2**((pitch-69)/12)
    t=np.arange(max(8,int(length*SR)),dtype=np.float32)/SR
    if kind=='lead':
        # Smooth saw stack with a little octave chime, no sampled voice.
        stereo=[]
        for side in [-1,1]:
            wave=np.zeros(len(t),np.float32)
            for detune in [-.0045,0,.0045]:
                phase=2*np.pi*f*(1+detune+side*.0007)*t
                for harmonic in range(1,7): wave+=np.sin(harmonic*phase)/(harmonic**1.6*3)
            wave+=.12*np.sin(2*np.pi*f*2*t)*np.exp(-t*7)
            env=np.minimum(t/.012,1)*np.minimum((length-t)/.09,1)
            wave*=np.maximum(env,0)*(.65+.35*np.exp(-t*5))
            stereo.append(wave)
        return np.column_stack(stereo)
    phase=2*np.pi*f*t
    wave=np.sin(phase)+.24*np.sin(2*phase)+.08*np.sin(3*phase)
    env=np.minimum(t/.006,1)*np.minimum((length-t)/.06,1)
    return wave*np.maximum(env,0)*np.exp(-t*1.7)

for beat,pitch,dur,velocity in TRACKS['lead']:
    part=section(min(BARS-1,int(beat//4)))
    loud=part in ('chorus','final chorus')
    sound=synth_note(pitch,dur*BEAT+.11,'lead')
    gain=.26 if loud else .055
    if part=='final chorus': gain*=1.09
    add(synth,sound,beat,gain)
    add(synth,sound[:,::-1],beat+.75,gain*.16)
    add(synth,sound,beat+1.5,gain*.08)
    if loud:
        add(synth,synth_note(pitch-12,dur*BEAT+.06,'lead'),beat,.065)
for beat,pitch,dur,velocity in TRACKS['bass']:
    add(synth,synth_note(pitch,dur*BEAT,'bass'),beat,.31 if velocity>70 else .14)

def noise(duration):
    return RNG.normal(0,1,int(duration*SR)).astype(np.float32)

t=np.arange(int(.48*SR))/SR
phase=2*np.pi*(43*t+115*.019*(1-np.exp(-t/.019)))
kick=np.sin(phase)*np.exp(-t*10)+.24*np.sin(2*np.pi*82*t)*np.exp(-t*22)
kick+=noise(.48)*np.exp(-t*210)*.18
clap_noise=noise(.32)
clap_noise=signal.sosfilt(signal.butter(2,[900,8500],btype='bandpass',fs=SR,output='sos'),clap_noise).astype(np.float32)
tclap=np.arange(len(clap_noise))/SR
env=np.zeros_like(tclap)
for start in [0,.012,.024]: env+=np.where(tclap>=start,np.exp(-np.maximum(tclap-start,0)*45),0)
clap=clap_noise*env*.32
hat_noise=noise(.2)
hat_noise=signal.sosfilt(signal.butter(2,7000,btype='highpass',fs=SR,output='sos'),hat_noise).astype(np.float32)
th=np.arange(len(hat_noise))/SR
closed=hat_noise*np.exp(-th*75)
opened=hat_noise*np.exp(-th*22)
snare_noise=noise(.14)
ts=np.arange(len(snare_noise))/SR
snare=(snare_noise*.37+np.sin(2*np.pi*185*ts)*.3)*np.exp(-ts*29)
for beat,pitch,dur,velocity in TRACKS['drums']:
    gain=velocity/127
    if pitch==36:
        add(drums,kick,beat,gain*.80)
        bar=int(beat//4)
        if section(bar) in ('chorus','final chorus','build','build2'):
            start=round(beat*BEAT*SR)
            dt=np.arange(int(.31*SR))/SR
            curve=1-.57*np.exp(-dt/.085)
            duck[start:start+len(curve)]=np.minimum(duck[start:start+len(curve)],curve[:max(0,n-start)])
    elif pitch==39:
        add(drums,clap,beat,gain*.30,-.08)
        add(drums,clap,beat+.23,gain*.055,.35)
    elif pitch==38: add(drums,snare,beat,gain*.115,.12)
    elif pitch==46: add(drums,opened,beat,gain*.13,.22)
    else: add(drums,closed,beat,gain*.095,-.3)

for drop in [28,60]:
    length=8*BEAT
    rise=noise(length)
    tt=np.arange(len(rise))/len(rise)
    rise=signal.sosfilt(signal.butter(2,[700,10500],btype='bandpass',fs=SR,output='sos'),rise)
    rise*=tt**2*.048
    add(drums,rise,drop*4-8)
    crash=noise(2.8)
    ct=np.arange(len(crash))/SR
    crash=signal.sosfilt(signal.butter(2,5000,btype='highpass',fs=SR,output='sos'),crash)
    crash*=np.exp(-ct*2.5)*.08
    add(drums,crash,drop*4,1,-.1)
    # Low impact at the first downbeat, fading into the bass.
    add(drums,synth_note(26,.95,'bass'),drop*4,.25)

mix=acoustic*(.72+.28*duck[:,None])+synth*duck[:,None]+drums
mix=np.tanh(mix*.93).astype(np.float32)
mix[:int(.07*SR)]*=np.linspace(0,1,int(.07*SR))[:,None]
fade_start=int((BARS*4*BEAT-1.2)*SR)
mix[fade_start:]*=np.linspace(1,0,n-fade_start)[:,None]**1.4
wavfile.write(WORK/'mix.wav',SR,np.int16(np.clip(mix,-1,1)*32767))
metadata={'title':'When the Lights Find Us','version':'Original instrumental','bpm':BPM,'key':'D major','duration_seconds':round(DURATION,2),
 'sections':[{'name':name,'start_seconds':round(start*4*BEAT,2),'end_seconds':round(end*4*BEAT,2)} for start,end,name in SECTIONS],
 'instruments':['piano','acoustic steel guitar','electric piano','strings','layered synthesizer lead','sub bass','electronic drums'],
 'notes':'Original melody and arrangement. No sampled commercial songs or artist voices.'}
(OUT/'composition.json').write_text(json.dumps(metadata,indent=2)+'\n')
print('Stereo arrangement complete:',DURATION,'seconds; peak',float(np.max(np.abs(mix))),flush=True)
