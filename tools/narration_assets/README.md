# Narration stings

`sting_intro.wav` (4.2 s) and `sting_outro.wav` (4.0 s) frame every POI narration (`tools/narration.py`).

- Source: one 32.8 s instrumental clip generated with Google **Lyria 2** (`lyria-002`, Vertex AI) on 2026-11-12.
  Prompt: "A short, gentle, warm opening chime for a forest audio guide: soft bamboo angklung notes and a light
  kalimba arpeggio, airy, calm, natural, with birdsong far in the background. Slow tempo, major key, peaceful and
  inviting." Negative prompt: "drums, vocals, heavy bass, electronic, distortion".
- Intro = 0–4.2 s, outro = 28.8–32.8 s (the clip's own decaying ending), fades added, mono 48 kHz,
  −22 LUFS (about 6 LU under the −16 LUFS voice so they stay in the background).
- AI-generated audio: log in the AI & Tools Disclosure.
