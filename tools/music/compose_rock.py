"""A Crown of Stars: original piano / theatrical rock instrumental."""
from pathlib import Path
import concurrent.futures, json, math, struct, subprocess
import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/music'
WORK=Path('/tmp/duet-rock')
WORK.mkdir(exist_ok=True)
SR=44100
PPQ=480
RNG=np.random.default_rng(943731)
CHORDS={
 'Eb':(39,[55,58,63,67]),'Eb/G':(43,[55,58,63,67]),'Eb/Bb':(46,[55,58,63,67]),
 'Bb':(34,[53,58,62,65]),'Bb/D':(38,[53,58,62,65]),'Bb7':(34,[53,56,58,62]),
 'Ab':(32,[51,56,60,63]),'Abm':(32,[51,56,59,63]),'Cm':(36,[55,60,63,67]),
 'Gm':(31,[50,55,58,62]),'G7':(31,[53,55,59,62]),'Fm':(29,[53,56,60,65]),
 'F7':(29,[53,57,60,63]),'Eb7':(39,[55,58,61,63]),'C7':(36,[52,55,58,60]),
}
FORM=[
 ('piano prelude',8,3,84,['Eb','Eb/G','Ab','Abm','Eb/Bb','Bb7','Eb','Bb7'],0),
 ('verse',12,4,96,['Eb','Bb/D','Cm','Gm','Ab','Eb/G','Fm','Bb7','Eb','Eb7','Ab','Bb7'],0),
 ('rising refrain',4,4,108,['Cm','G7','Ab','Bb7'],0),
 ('anthem',12,4,124,['Eb','Bb','Ab','Eb/G','Fm','Bb7','Eb','Bb/D','Cm','Ab','Bb7','Eb'],0),
 ('theatrical interlude',8,3,108,['Cm','G7','Cm','Fm','Ab','F7','Bb7','Bb7'],0),
 ('guitar conversation',8,4,128,['Eb','Ab','Cm','Bb7','Eb','Ab','Bb7','C7'],0),
 ('final anthem',12,4,128,['Eb','Bb','Ab','Eb/G','Fm','Bb7','Eb','Bb/D','Cm','Ab','Bb7','Eb'],2),
 ('curtain call',4,3,90,['Ab','Abm','Eb/Bb','Eb'],2),
]
HOOK=[
 [(75,1),(70,.5),(67,.5),(70,1),(79,1)],
 [(77,.5),(79,.5),(77,1),(74,1),(70,1)],
 [(75,.75),(72,.25),(68,.5),(72,.5),(75,1),(77,1)],
 [(79,1),(77,.5),(75,.5),(70,1),(67,1)],
 [(77,.5),(75,.5),(72,1),(68,.5),(72,.5),(77,1)],
 [(77,.5),(74,.5),(70,1),(68,.5),(65,.5),(74,1)],
 [(75,2),(79,1),(82,1)],
 [(82,.75),(80,.25),(77,.5),(74,.5),(70,1),(77,1)],
 [(79,.5),(75,.5),(72,1),(70,.5),(72,.5),(75,1)],
 [(75,1),(72,.5),(68,.5),(72,1),(75,1)],
 [(77,.5),(80,.5),(77,1),(74,.5),(70,.5),(74,1)],
 [(75,3),(0,1)],
]
VERSE=[
 [(67,1.5),(70,.5),(75,1),(74,1)],[(70,1),(65,.5),(67,.5),(65,1.5),(0,.5)],
 [(67,1),(72,1),(75,.5),(74,.5),(72,1)],[(70,2),(67,1),(65,1)],
 [(68,1),(72,.5),(75,.5),(72,1.5),(0,.5)],[(67,1.5),(70,.5),(75,1),(79,1)],
 [(77,1),(75,.5),(72,.5),(68,1),(65,1)],[(74,1.5),(77,.5),(74,1),(70,1)],
 [(75,1.5),(79,.5),(82,1),(79,1)],[(79,1),(75,.5),(73,.5),(70,1),(67,1)],
 [(72,1),(75,1),(80,.5),(79,.5),(75,1)],[(77,1),(74,1),(70,1),(0,1)],
]
TRACKS={name:[] for name in ['piano','rhythm L','rhythm R','lead','harmony','bass','choir','organ','drums']}
BARS=[]
tempo_map=[]
global_beat=0.0
seconds=0.0
for name,count,meter,bpm,chords,transpose in FORM:
    tempo_map.append((global_beat,bpm,meter,seconds))
    for b in range(count):
        BARS.append({'section':name,'local':b,'beat':global_beat,'seconds':seconds,'bpm':bpm,'meter':meter,'chord':chords[b%len(chords)],'transpose':transpose})
        global_beat+=meter
        seconds+=meter*60/bpm
DURATION=seconds+5

def at_seconds(beat):
    entry=tempo_map[0]
    for candidate in tempo_map:
        if candidate[0]>beat: break
        entry=candidate
    return entry[3]+(beat-entry[0])*60/entry[1]

def add(name,beat,pitch,dur,vel=80):
    if pitch: TRACKS[name].append((max(0,beat),pitch,dur,max(1,min(127,vel))))

def third(pitch,transpose=0):
    scale=[0,2,3,5,7,8,10]
    # E-flat-major scale anchored at C (C D Eb F G Ab Bb).
    p=pitch-transpose
    pc=p%12
    idx=min(range(7),key=lambda i:abs(scale[i]-pc))
    new=idx+2
    return p-pc+scale[new%7]+12*(new//7)+transpose

for bar in BARS:
    name,b,meter,start,tr=bar['section'],bar['local'],bar['meter'],bar['beat'],bar['transpose']
    root,voice=CHORDS[bar['chord']]
    root+=tr; voice=[p+tr for p in voice]
    rock=name in ['anthem','guitar conversation','final anthem']
    verse=name=='verse'
    intro=name=='piano prelude'
    theatre=name=='theatrical interlude'
    outro=name=='curtain call'
    rising=name=='rising refrain'
    # Piano uses broad voicings, triplets, and dramatic answered phrases.
    for t in ([0,1.5] if meter==3 else [0,2]):
        add('piano',start+t,root+12,1.4 if not rock else .65,61 if intro else 72)
        if not intro: add('piano',start+t,root+24,.8,53)
    if intro or outro:
        arp=[voice[0],voice[1],voice[2],voice[3],voice[2],voice[1]]
        for j,p in enumerate(arp): add('piano',start+j*.5,p+12,.8,59+int(RNG.integers(-7,7)))
        add('piano',start,voice[-1]+12,2.4,77)
    elif theatre:
        for t in [0,1.25,2]:
            for p in voice: add('piano',start+t,p,.28,72)
    else:
        for t in ([0,1.5,2,3] if rock else [0,1,2,3]):
            for j,p in enumerate(voice): add('piano',start+t+j*.009,p,.44 if rock else .78,63 if rock else 55)
    if verse:
        t=start
        for p,d in VERSE[b]:
            add('piano',t,p,d*.88,82); t+=d
        # Two small guitar answers between piano phrases.
        if b in [3,7,11]:
            for j,p in enumerate([70,74,77,75]): add('lead',start+2+j*.5,p,.43,73)
    if rising:
        for p in voice[1:]: add('choir',start,p+12,3.5,48+b*5)
        for j,p in enumerate([voice[-1],voice[-2],voice[-1],voice[-1]+12]): add('lead',start+j,p+12,.85,72+b*4)
    if rock or rising:
        # Unequal takes, open fifths and octave rhythm guitars.
        guitar_root=root+12
        if guitar_root<40: guitar_root+=12
        accents=[(0,.72),(1,.3),(1.5,.36),(2,.72),(3,.3),(3.5,.36)]
        if name=='guitar conversation': accents=[(0,1.3),(1.5,.4),(2,1.25),(3.5,.4)]
        for t,d in accents:
            for guitar,offset in [('rhythm L',-.009),('rhythm R',.013)]:
                for j,p in enumerate([guitar_root,guitar_root+7,guitar_root+12]):
                    add(guitar,start+t+offset+j*.008,p,d,86+int(RNG.integers(-8,8)))
    elif verse and b>=4:
        for p in voice[:3]: add('rhythm L',start,p,3.5,41)
    if name in ['anthem','final anthem']:
        t=start
        for j,(p,d) in enumerate(HOOK[b]):
            if p:
                add('lead',t,p+tr,d*.94,98)
                if b%3!=1 or name=='final anthem': add('harmony',t+.017,third(p+tr,tr),d*.9,80)
            t+=d
        if name=='final anthem':
            for p in voice[1:]: add('choir',start,p+12,3.7,49)
    if name=='guitar conversation':
        # Guitar runs answer with slower harmonized phrases every other bar.
        run=[voice[0]+12,voice[1]+12,voice[2]+12,voice[3]+12,voice[2]+12,voice[1]+12,voice[3]+12,voice[3]+14]
        if b%2==0:
            for j,p in enumerate(run): add('lead',start+j*.5,p,.47,103)
        else:
            run=[voice[3]+12,voice[2]+12,voice[1]+12,voice[0]+12]
            for j,p in enumerate(run):
                add('lead',start+j,p,.94,101)
                add('harmony',start+j+.02,third(p),.9,86)
    if theatre:
        for t,d in [(0,.7),(1,.45),(1.75,.85)]:
            for j,p in enumerate(voice):
                add('choir',start+t+j*.006,p+12,d,64)
        for p in voice: add('organ',start,p,2.8,39)
        # Short guitar chords answer the choir from the other side.
        if b%2:
            for p in voice[1:]: add('harmony',start+2.4,p+12,.4,76)
    if not intro and not outro:
        rhythm=[0,1,2,3] if rock or verse or rising else [0,1.5]
        for j,t in enumerate(rhythm):
            p=root+(12 if j==3 and bar['chord'] not in ['G7','Bb7'] else 0)
            add('bass',start+t,p,.8 if rock else 1.0,89 if rock else 72)
            if rock and j in [1,3]: add('bass',start+t+.5,root+7,.35,67)
    if rock or rising or (verse and b>=4):
        for t in ([0,1.5,2.75] if not rock else [0,.5,1.5,2,2.75,3.5]): add('drums',start+t,36,.14,108 if rock else 84)
        for t in [1,3]: add('drums',start+t,38,.15,111 if rock else 87)
        for t in np.arange(0,4,.5):
            cymbal=51 if name=='final anthem' else 42
            add('drums',start+float(t),cymbal,.16,65 if int(t)==t else 47)
        if b%4==0 or b==0: add('drums',start,49,.5,90 if rock else 61)
        if b%4==3:
            for j,p in enumerate([38,48,47,45,43,41]): add('drums',start+2.5+j*.25,p,.12,80+j*5)
    elif theatre:
        add('drums',start,49,.4,52)
        if b>=4:
            add('drums',start+1,45,.2,75)
            add('drums',start+2,43,.2,84)
    if outro and b==3:
        for p in [root+12,*voice,voice[-1]+12]: add('piano',start,p,6,71)
        for p in voice[1:]: add('choir',start,p+12,5,35)
        add('drums',start,49,.5,59)

PROGRAMS={'piano':(0,0,99,64),'rhythm L':(1,29,90,22),'rhythm R':(2,29,87,105),
 'lead':(3,30,104,52),'harmony':(4,30,89,80),'bass':(5,33,104,64),
 'choir':(6,52,76,58),'organ':(7,19,58,76),'drums':(9,0,114,64)}

def vlq(n):
    parts=[n&127]; n>>=7
    while n: parts.insert(0,(n&127)|128); n>>=7
    return bytes(parts)

def write_midi(path,names):
    conductor=[]
    for beat,bpm,meter,_ in tempo_map:
        tick=round(beat*PPQ)
        conductor.append((tick,0,b'\xff\x51\x03'+int(60_000_000/bpm).to_bytes(3,'big')))
        conductor.append((tick,1,b'\xff\x58\x04'+bytes([meter,2,24,8])))
    title=b'A Crown of Stars - original theatrical rock instrumental'
    conductor.append((0,-1,b'\xff\x03'+vlq(len(title))+title))
    def chunk(events):
        data=b''; previous=0
        for tick,_,payload in sorted(events,key=lambda e:(e[0],e[1])):
            data+=vlq(tick-previous)+payload; previous=tick
        data+=vlq(max(1,round((global_beat+8)*PPQ)-previous))+b'\xff\x2f\0'
        return b'MTrk'+len(data).to_bytes(4,'big')+data
    chunks=[chunk(conductor)]
    for name in names:
        ch,program,volume,pan=PROGRAMS[name]
        text=name.encode()
        events=[(0,-3,b'\xff\x03'+vlq(len(text))+text),(0,-2,bytes([0xc0|ch,program])),
                (0,-1,bytes([0xb0|ch,7,volume])),(0,-1,bytes([0xb0|ch,10,pan]))]
        for beat,pitch,dur,velocity in TRACKS[name]:
            start=round(beat*PPQ); end=round((beat+dur)*PPQ)
            events.extend([(start,1,bytes([0x90|ch,pitch,velocity])),(end,0,bytes([0x80|ch,pitch,0]))])
            if name in ['lead','harmony'] and dur>.7:
                for off in np.arange(.3,dur-.08,.065):
                    bend=int(8192+math.sin(off*math.tau*5.4)*165)
                    events.append((start+round(off*PPQ),2,bytes([0xe0|ch,bend&127,bend>>7])))
                events.append((end,-1,bytes([0xe0|ch,0,64])))
        chunks.append(chunk(events))
    path.write_bytes(b'MThd\0\0\0\x06\0\x01'+len(chunks).to_bytes(2,'big')+PPQ.to_bytes(2,'big')+b''.join(chunks))

write_midi(OUT/'A-Crown-of-Stars.mid',TRACKS)
STEMS={'piano':['piano'],'rhythm':['rhythm L','rhythm R'],'lead':['lead','harmony'],'band':['bass','choir','organ','drums']}
sf=Path('/tmp/duet-song/usr/share/sounds/sf2/TimGM6mb.sf2')

def render(name):
    path=WORK/(name+'.mid')
    write_midi(path,STEMS[name])
    subprocess.run(['fluidsynth','-ni','-F',str(WORK/(name+'.wav')),'-T','wav','-r',str(SR),'-g','0.68',
     '-o','synth.reverb.active=1','-o','synth.reverb.room-size=0.76','-o','synth.reverb.damp=0.55',
     '-o','synth.reverb.level='+('0.23' if name=='piano' else '0.13'),
     '-o','synth.chorus.active=1',str(sf),str(path)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    return name

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    for result in pool.map(render,STEMS): print('Rendered',result,flush=True)

N=round(DURATION*SR)
stems={}
for name in STEMS:
    sr,data=wavfile.read(WORK/(name+'.wav'))
    data=data.astype(np.float32)/32768
    target=np.zeros((N,2),np.float32)
    target[:min(N,len(data))]=data[:N]
    stems[name]=target

def lowpass(data,freq):
    return signal.sosfilt(signal.butter(3,freq,fs=SR,output='sos'),data,axis=0).astype(np.float32)

# Amp-like saturation and cabinet roll-off; piano remains unprocessed.
for name,drive,cutoff in [('rhythm',2.8,5300),('lead',2.0,6400)]:
    data=stems[name]
    data=signal.sosfilt(signal.butter(2,110,btype='highpass',fs=SR,output='sos'),data,axis=0)
    data=np.tanh(data*drive)/math.tanh(drive)
    stems[name]=lowpass(data,cutoff)
lead=stems['lead']
for delay,amount in [(.19,.13),(.39,.075)]:
    offset=int(delay*SR)
    lead[offset:]+=stems['lead'][:-offset,::-1].copy()*amount

mix=stems['piano']*.93+stems['rhythm']*.76+lead*.88+stems['band']*1.02
mix=np.tanh(mix*1.12).astype(np.float32)
mix[:int(.06*SR)]*=np.linspace(0,1,int(.06*SR))[:,None]
fade_start=round((seconds+1)*SR)
mix[fade_start:]*=np.linspace(1,0,N-fade_start)[:,None]**1.4
wavfile.write(WORK/'mix.wav',SR,np.int16(np.clip(mix,-1,1)*32767))
metadata={'title':'A Crown of Stars','version':'Original theatrical rock instrumental','duration_seconds':round(DURATION,2),
 'key':'E-flat major / C minor, final chorus in F major',
 'sections':[{'name':name,'start_seconds':round(sec,2),'tempo_bpm':bpm,'meter':str(meter)+'/4'} for (beat,bpm,meter,sec),(name,*_) in zip(tempo_map,FORM)],
 'instruments':['grand piano','double-tracked overdriven guitar','harmonized lead guitars','electric bass','rock drums','wordless choir','organ'],
 'notes':'New melodies and arrangement. Synthesized instruments; no artist voices or commercial song recordings.'}
(OUT/'A-Crown-of-Stars-composition.json').write_text(json.dumps(metadata,indent=2)+'\n')
print('Finished mix:',DURATION,'seconds, peak',float(np.max(np.abs(mix))),flush=True)
