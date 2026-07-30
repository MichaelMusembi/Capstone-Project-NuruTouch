import wave
import struct
import math
import os

def generate_tone(filename, freq, duration_ms=300, volume=0.5, decay=True):
    sample_rate = 44100.0
    num_samples = int(sample_rate * (duration_ms / 1000.0))
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(int(sample_rate))
        
        for i in range(num_samples):
            t = float(i) / sample_rate
            # sine wave
            value = math.sin(2.0 * math.pi * freq * t)
            
            if decay:
                # exponential decay
                env = math.exp(-5.0 * t / (duration_ms / 1000.0))
            else:
                env = 1.0
                
            sample = value * volume * env
            # 16-bit PCM
            data = struct.pack('<h', int(sample * 32767.0))
            wav_file.writeframesraw(data)

def generate_chord(filename, freqs, duration_ms=800, volume=0.5):
    sample_rate = 44100.0
    num_samples = int(sample_rate * (duration_ms / 1000.0))
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(int(sample_rate))
        
        for i in range(num_samples):
            t = float(i) / sample_rate
            value = 0
            for freq in freqs:
                value += math.sin(2.0 * math.pi * freq * t)
            value /= len(freqs)
            
            # exponential decay
            env = math.exp(-3.0 * t / (duration_ms / 1000.0))
            sample = value * volume * env
            data = struct.pack('<h', int(sample * 32767.0))
            wav_file.writeframesraw(data)

def main():
    out_dir = r"c:\Users\LENOVO\Capstone Project NuruTouch\nurutouch\assets\sounds"
    os.makedirs(out_dir, exist_ok=True)
    
    # C5, E5, G5 (ascending major triad)
    generate_tone(os.path.join(out_dir, "ding_1.wav"), 523.25)
    generate_tone(os.path.join(out_dir, "ding_2.wav"), 659.25)
    generate_tone(os.path.join(out_dir, "ding_3.wav"), 783.99)
    
    # C major chord (C5, E5, G5, C6)
    generate_chord(os.path.join(out_dir, "success_chord.wav"), [523.25, 659.25, 783.99, 1046.50])
    
    print("Generated chimes successfully!")

if __name__ == "__main__":
    main()
