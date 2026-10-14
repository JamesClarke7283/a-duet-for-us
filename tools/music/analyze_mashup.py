from pathlib import Path
import json
import numpy as np
from scipy import signal
from scipy.io import wavfile

rate,audio=wavfile.read('/tmp/queen-mashup/queen.wav')
mono=signal.resample_poly(audio.astype(np.float32).mean(axis=1)/32768,1,4)
sr=rate//4
f,t,z=signal.stft(mono,fs=sr,nperseg=1024,noverlap=768)
mag=np.abs(z)
onset=np.maximum(np.diff(np.log1p(mag*40),axis=1),0)[(f>150)&(f<5500)].sum(axis=0)
onset-=signal.medfilt(onset,43)
onset=np.maximum(onset,0)
env_rate=sr/256
auto=signal.fftconvolve(onset,onset[::-1],mode='full')[len(onset)-1:]
bpms=np.linspace(85,145,2401)
scores=np.interp(env_rate*60/bpms,np.arange(len(auto)),auto)
scores+=.45*np.interp(2*env_rate*60/bpms,np.arange(len(auto)),auto)
idx=signal.find_peaks(scores,distance=80)[0]
rank=sorted(idx,key=lambda i:scores[i],reverse=True)[:8]
candidates=[{'bpm':round(float(bpms[i]),3),'score':round(float(scores[i]),2)} for i in rank]
bpm=float(bpms[np.argmax(scores)])
period=60/bpm
phases=np.linspace(0,period,400)
phase_scores=[np.interp(np.arange(p,240,period)*env_rate,np.arange(len(onset)),onset).sum() for p in phases]
phase=float(phases[np.argmax(phase_scores)])
freq,times,zz=signal.stft(mono,fs=sr,nperseg=4096,noverlap=3072)
power=np.abs(zz)**1.2
chroma=np.zeros((12,power.shape[1]))
for i in np.where((freq>55)&(freq<1800))[0]:
    midi=int(round(69+12*np.log2(freq[i]/440)))
    chroma[midi%12]+=power[i]
profile=chroma.sum(axis=1); profile/=profile.sum()
major=np.array([6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88])
minor=np.array([6.33,2.68,3.52,5.38,2.60,3.53,2.54,4.75,3.98,2.69,3.34,3.17])
names=['C','C#','D','Eb','E','F','F#','G','Ab','A','Bb','B']
keys=sorted([(float(np.corrcoef(profile,np.roll(p,r))[0,1]),names[r]+mode) for p,mode in [(major,' major'),(minor,' minor')] for r in range(12)],reverse=True)[:6]
report={'tempo_candidates':candidates,'bpm':round(bpm,3),'beat_phase':round(phase,4),'key_candidates':keys,'chroma':profile.tolist(),'duration':len(audio)/rate}
Path('/tmp/queen-mashup/analysis.json').write_text(json.dumps(report,indent=2))
np.savez('/tmp/queen-mashup/features.npz',chroma=chroma,times=times,onset=onset,onset_rate=env_rate)
print(json.dumps(report,indent=2))
