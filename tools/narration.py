"""Generate and verify the POI audio narrations (F03 c) with Google Cloud.

Pipeline per POI (scripts in docs/content/narration/Pxx.md):
  1. synthesize  Gemini TTS on Vertex AI (`generateContent`, responseModalities AUDIO) → 24 kHz WAV
  2. master      ffmpeg: trim silence, loudness −16 LUFS / −1.5 dBTP, soft intro + outro sting,
                 mono MP3 64 kbps → assets/audio/pxx.mp3
  3. verify      Google Speech-to-Text v2 (Chirp 3, id-ID) transcribes the MP3; word error rate
                 against the script, duration 120–180 s, loudness → docs/content/narration/VERIFICATION.md

Auth: Application Default Credentials (`gcloud auth application-default login`), project from
$GOOGLE_CLOUD_PROJECT or `gcloud config get-value project`. Needs `gcloud` and `ffmpeg`/`ffprobe`.
Stdlib only. Unchanged scripts are skipped (hash in docs/content/narration/manifest.json).

Usage:
  python3 tools/narration.py generate [--only P05 P06] [--force]
  python3 tools/narration.py verify   [--only P05]
  python3 tools/narration.py all      [--only ...] [--force]
  python3 tools/narration.py sync     (only rewrite audio/audio_seconds/sources in pois.json)

`generate` also syncs assets/content/pois.json: `audio`, `audio_seconds` and `sources` (the S1, S2 …
lines of each script header) for every POI that has a narration file.
"""

from __future__ import annotations

import argparse
import base64
import difflib
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "docs" / "content" / "narration"
MANIFEST = SCRIPTS / "manifest.json"
REPORT = SCRIPTS / "VERIFICATION.md"
AUDIO_OUT = ROOT / "assets" / "audio"
STING_IN = ROOT / "tools" / "narration_assets" / "sting_intro.wav"
STING_OUT = ROOT / "tools" / "narration_assets" / "sting_outro.wav"
CACHE = ROOT / "build" / "narration"  # raw TTS takes, gitignored
POIS_JSON = ROOT / "assets" / "content" / "pois.json"

TTS_MODEL = "gemini-3.8-flash-tts"
TTS_LOCATION = "global"
VOICE = "Sulafat"  # documented as "Warm"; one narrator for every POI
STT_MODEL = "chirp_3"
STT_LOCATION = "us"  # chirp_3 id-ID is not served in asia-southeast1

MIN_S, MAX_S = 120, 180  # PRD F03 (c), v0.9.2
MAX_WER = 0.08
TARGET_LUFS, TRUE_PEAK = -16.0, -1.5
MP3_RATE, MP3_KBPS = 44100, 64

PAUSE_TAG = re.compile(r"<[^>]+>")


# ---- helpers ----------------------------------------------------------------------------------
def gcloud() -> str:
    exe = shutil.which("gcloud") or str(Path.home() / "google-cloud-sdk" / "bin" / "gcloud")
    if not Path(exe).exists():
        sys.exit("gcloud not found (install the Google Cloud SDK or put it on PATH)")
    return exe


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw)


_token: tuple[str, float] | None = None


def token() -> str:
    global _token
    if _token is None or time.time() - _token[1] > 1800:
        _token = (run([gcloud(), "auth", "application-default", "print-access-token"]).stdout.strip(), time.time())
    return _token[0]


def project() -> str:
    p = os.environ.get("GOOGLE_CLOUD_PROJECT") or run([gcloud(), "config", "get-value", "project"]).stdout.strip()
    if not p:
        sys.exit("No Google Cloud project: set GOOGLE_CLOUD_PROJECT or `gcloud config set project …`")
    return p


def post(url: str, body: dict, retries: int = 4) -> dict:
    data = json.dumps(body).encode()
    for attempt in range(retries):
        req = urllib.request.Request(url, data=data, method="POST", headers={
            "Authorization": f"Bearer {token()}", "x-goog-user-project": project(),
            "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")
            if e.code in (429, 500, 503) and attempt < retries - 1:
                time.sleep(5 * 2 ** attempt)
                continue
            sys.exit(f"HTTP {e.code} from {url}\n{msg}")
    raise RuntimeError("unreachable")


# ---- scripts ----------------------------------------------------------------------------------
class Script:
    """docs/content/narration/Pxx.md: `key: value` header lines, a `---` line, then the transcript."""

    def __init__(self, path: Path):
        self.path = path
        self.id = path.stem
        raw = path.read_text(encoding="utf-8")
        head, sep, body = raw.partition("\n---\n")
        if not sep:
            sys.exit(f"{path}: missing '---' line between header and transcript")
        self.meta = {}
        for line in head.splitlines():
            if ":" in line and not line.startswith("#"):
                k, v = line.split(":", 1)
                self.meta[k.strip()] = v.strip()
        self.style = self.meta.get("style", "")
        # Paragraphs are separated by blank lines; source notes ([S1] …) are stripped before TTS.
        paras = [" ".join(p.split()) for p in body.strip().split("\n\n") if p.strip()]
        self.transcript = "\n\n".join(re.sub(r"\s*\[S\d+(?:,\s*S\d+)*\]", "", p) for p in paras)

    @property
    def spoken(self) -> str:
        """What the listener should hear: transcript without inline delivery tags."""
        return " ".join(PAUSE_TAG.sub(" ", self.transcript).split())

    @property
    def words(self) -> int:
        return len(self.spoken.split())

    def key(self) -> str:
        sting = b"".join(p.read_bytes() for p in (STING_IN, STING_OUT) if p.exists())
        h = hashlib.sha256()
        for part in (TTS_MODEL, VOICE, self.style, self.transcript):
            h.update(part.encode() + b"\0")
        h.update(hashlib.sha256(sting).digest())
        return h.hexdigest()[:16]


def load_scripts(only: list[str] | None) -> list[Script]:
    paths = sorted(SCRIPTS.glob("P[0-9][0-9].md"))
    out = [Script(p) for p in paths if not only or p.stem in only]
    if not out:
        sys.exit(f"No scripts found in {SCRIPTS} (filter: {only})")
    return out


# ---- synthesis + mastering -------------------------------------------------------------------
def synthesize(s: Script, dest: Path) -> None:
    url = (f"https://aiplatform.googleapis.com/v1/projects/{project()}/locations/{TTS_LOCATION}"
           f"/publishers/google/models/{TTS_MODEL}:generateContent")
    part: dict = {"text": s.transcript}
    if s.style:
        part["speechMetadata"] = {"style": s.style}
    body = {"contents": [{"role": "user", "parts": [part]}],
            "generationConfig": {"responseModalities": ["AUDIO"],
                                 "speechConfig": {"voiceConfig": {"voice": VOICE}}}}
    r = post(url, body)
    try:
        inline = r["candidates"][0]["content"]["parts"][0]["inlineData"]
    except (KeyError, IndexError):
        sys.exit(f"{s.id}: unexpected TTS response: {json.dumps(r)[:500]}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(base64.b64decode(inline["data"]))


def duration(path: Path) -> float:
    out = run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)])
    return float(out.stdout.strip())


def loudness(path: Path) -> dict:
    """Integrated loudness / true peak measured with ffmpeg loudnorm (analysis pass)."""
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af",
                        f"loudnorm=I={TARGET_LUFS}:TP={TRUE_PEAK}:LRA=11:print_format=json",
                        "-f", "null", "-"], capture_output=True, text=True)
    m = re.search(r"\{[^{}]*\"input_i\"[^{}]*\}", r.stderr, re.S)
    if not m:
        raise RuntimeError(f"loudnorm analysis failed for {path}:\n{r.stderr[-800:]}")
    return json.loads(m.group(0))


def master(raw: Path, out: Path) -> None:
    """Trim leading/trailing silence, normalise voice to −16 LUFS (two-pass), wrap in the stings."""
    with tempfile.TemporaryDirectory() as td:
        voice = Path(td) / "voice.wav"
        trim = ("silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.15,"
                "areverse,silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.3,areverse")
        run(["ffmpeg", "-y", "-i", str(raw), "-af", trim, "-ar", "48000", "-ac", "1", str(voice)])
        m = loudness(voice)
        norm = (f"loudnorm=I={TARGET_LUFS}:TP={TRUE_PEAK}:LRA=11:measured_I={m['input_i']}:"
                f"measured_TP={m['input_tp']}:measured_LRA={m['input_lra']}:"
                f"measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true")
        voice_n = Path(td) / "voice_n.wav"
        run(["ffmpeg", "-y", "-i", str(voice), "-af", norm + ",aresample=48000", "-ac", "1", str(voice_n)])

        out.parent.mkdir(parents=True, exist_ok=True)
        if STING_IN.exists() and STING_OUT.exists():
            # intro sting, voice enters while the sting tails off (−0.8 s overlap); outro after 0.6 s.
            vlen = duration(voice_n)
            ilen = duration(STING_IN)
            v_at = max(0.0, ilen - 0.8)
            o_at = v_at + vlen + 0.6
            graph = (f"[0:a]aformat=sample_rates=48000:channel_layouts=mono[i];"
                     f"[1:a]adelay={int(v_at * 1000)}[v];"
                     f"[2:a]aformat=sample_rates=48000:channel_layouts=mono,adelay={int(o_at * 1000)}[o];"
                     f"[i][v][o]amix=inputs=3:duration=longest:normalize=0,"
                     f"alimiter=limit={10 ** (TRUE_PEAK / 20):.3f}:level=false[m]")
            cmd = ["ffmpeg", "-y", "-i", str(STING_IN), "-i", str(voice_n), "-i", str(STING_OUT),
                   "-filter_complex", graph, "-map", "[m]"]
        else:
            print("  (no sting files in tools/narration_assets/, voice only)")
            cmd = ["ffmpeg", "-y", "-i", str(voice_n)]
        run(cmd + ["-ac", "1", "-ar", str(MP3_RATE), "-codec:a", "libmp3lame", "-b:a", f"{MP3_KBPS}k",
                   "-id3v2_version", "3", "-metadata", "artist=Jelajah Taman",
                   "-metadata", "comment=Narasi sintetis (Gemini TTS)", str(out)])


def generate(scripts: list[Script], force: bool) -> None:
    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    for s in scripts:
        out = AUDIO_OUT / f"{s.id.lower()}.mp3"
        key = s.key()
        if not force and manifest.get(s.id, {}).get("key") == key and out.exists():
            print(f"{s.id}: unchanged, skip")
            continue
        print(f"{s.id}: synthesizing {s.words} words with {TTS_MODEL}/{VOICE} …")
        raw = CACHE / f"{s.id}.wav"
        synthesize(s, raw)
        master(raw, out)
        secs = duration(out)
        manifest[s.id] = {"key": key, "file": out.name, "seconds": round(secs, 1), "words": s.words,
                          "model": TTS_MODEL, "voice": VOICE, "style": s.style,
                          "generated": time.strftime("%Y-%m-%d")}
        flag = "" if MIN_S <= secs <= MAX_S else f"  ← outside {MIN_S}–{MAX_S} s"
        print(f"{s.id}: {out.relative_to(ROOT)} {secs:.1f} s{flag}")
        MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")


# ---- content sync -----------------------------------------------------------------------------
def content_fields(pid: str) -> dict:
    """pois.json fields for one POI from the manifest + script header (empty if no narration)."""
    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    m = manifest.get(pid)
    path = SCRIPTS / f"{pid}.md"
    if not m or not (AUDIO_OUT / m["file"]).exists() or not path.exists():
        return {}
    s = Script(path)
    refs = [(k, v) for k, v in s.meta.items() if re.fullmatch(r"S\d+", k)]
    sources = [f"{k}: {v}" for k, v in sorted(refs, key=lambda kv: int(kv[0][1:]))]
    return {"audio": m["file"], "audio_seconds": round(m["seconds"]), "sources": sources}


def sync_content() -> None:
    data = json.loads(POIS_JSON.read_text(encoding="utf-8"))
    changed = 0
    for poi in data["pois"]:
        fields = content_fields(poi["id"])
        if fields and any(poi.get(k) != v for k, v in fields.items()):
            poi.update(fields)
            changed += 1
    POIS_JSON.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"pois.json: {changed} POI(s) updated")


# ---- verification ----------------------------------------------------------------------------
def norm_words(text: str) -> list[str]:
    t = text.lower().replace("-", " ")
    t = re.sub(r"(?<=\d)[.,](?=\d)", "", t)  # 31.272 → 31272
    t = re.sub(r"[^\w\s]", " ", t)
    return t.split()


def stt_chunks(mp3: Path, td: Path) -> list[Path]:
    """Split at silences into ≤55 s FLAC chunks (sync recognize accepts ≤60 s)."""
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(mp3), "-af",
                        "silencedetect=noise=-35dB:d=0.35", "-f", "null", "-"], capture_output=True, text=True)
    mids = [(float(a) + float(b)) / 2 for a, b in
            zip(re.findall(r"silence_start: ([\d.]+)", r.stderr), re.findall(r"silence_end: ([\d.]+)", r.stderr))]
    total = duration(mp3)
    cuts, start = [], 0.0
    while total - start > 55:
        cand = [m for m in mids if start + 20 < m <= start + 55]
        cut = cand[-1] if cand else start + 55
        cuts.append((start, cut))
        start = cut
    cuts.append((start, total))
    out = []
    for i, (a, b) in enumerate(cuts):
        p = td / f"c{i}.flac"
        run(["ffmpeg", "-y", "-i", str(mp3), "-ss", f"{a:.2f}", "-to", f"{b:.2f}", "-ac", "1", "-ar", "16000", str(p)])
        out.append(p)
    return out


def transcribe(mp3: Path) -> str:
    url = (f"https://{STT_LOCATION}-speech.googleapis.com/v2/projects/{project()}/locations/"
           f"{STT_LOCATION}/recognizers/_:recognize")
    parts = []
    with tempfile.TemporaryDirectory() as td:
        for chunk in stt_chunks(mp3, Path(td)):
            body = {"config": {"autoDecodingConfig": {}, "languageCodes": ["id-ID"], "model": STT_MODEL},
                    "content": base64.b64encode(chunk.read_bytes()).decode()}
            r = post(url, body)
            parts += [res["alternatives"][0]["transcript"] for res in r.get("results", []) if res.get("alternatives")]
    return " ".join(" ".join(parts).split())


def wer(ref: list[str], hyp: list[str]) -> tuple[float, list[str]]:
    sm = difflib.SequenceMatcher(a=ref, b=hyp, autojunk=False)
    errors, diffs = 0, []
    for op, a1, a2, b1, b2 in sm.get_opcodes():
        if op == "equal":
            continue
        errors += max(a2 - a1, b2 - b1)
        diffs.append(f"{op}: «{' '.join(ref[a1:a2])}» → «{' '.join(hyp[b1:b2])}»")
    return errors / max(1, len(ref)), diffs


def verify(scripts: list[Script]) -> bool:
    rows, details, ok_all = [], [], True
    for s in scripts:
        mp3 = AUDIO_OUT / f"{s.id.lower()}.mp3"
        if not mp3.exists():
            print(f"{s.id}: no audio, skip")
            continue
        print(f"{s.id}: transcribing …")
        secs = duration(mp3)
        lu = loudness(mp3)
        hyp = transcribe(mp3)
        rate, diffs = wer(norm_words(s.spoken), norm_words(hyp))
        ok = MIN_S <= secs <= MAX_S and rate <= MAX_WER and float(lu["input_tp"]) <= -1.0
        ok_all &= ok
        rows.append(f"| {s.id} | {secs:.1f} | {s.words} | {float(lu['input_i']):.1f} | {float(lu['input_tp']):.1f} "
                    f"| {rate * 100:.1f} % | {'✅' if ok else '❌'} |")
        details.append(f"### {s.id}\n\nDifferences script → STT ({len(diffs)}):\n\n"
                       + ("\n".join(f"- {d}" for d in diffs) or "- none") + "\n")
        print(f"{s.id}: {secs:.1f} s, {float(lu['input_i']):.1f} LUFS, WER {rate * 100:.1f} % {'OK' if ok else 'FAIL'}")
    REPORT.write_text(
        "# Narration verification\n\n"
        f"Generated by `python3 tools/narration.py verify` on {time.strftime('%Y-%m-%d')}. "
        f"TTS `{TTS_MODEL}` voice `{VOICE}`; STT Google Speech-to-Text v2 `{STT_MODEL}` (id-ID, `{STT_LOCATION}`).\n\n"
        f"Pass = duration {MIN_S}–{MAX_S} s, word error rate ≤ {MAX_WER * 100:.0f} % against the script "
        "(case, punctuation and delivery tags ignored), true peak ≤ −1 dBTP. Target loudness −16 LUFS. "
        "Remaining differences are mostly spelling variants of names (Djuanda/Juanda) and numbers; "
        "read them below and listen to any that look like a skipped or wrong phrase.\n\n"
        "| POI | Seconds | Words | LUFS | Peak dBTP | WER | Pass |\n|---|---|---|---|---|---|---|\n"
        + "\n".join(rows) + "\n\n" + "\n".join(details), encoding="utf-8")
    print(f"Report: {REPORT.relative_to(ROOT)}")
    return ok_all


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["generate", "verify", "all", "sync"])
    ap.add_argument("--only", nargs="*", help="POI ids, e.g. P05 P06")
    ap.add_argument("--force", action="store_true", help="regenerate even if the script is unchanged")
    a = ap.parse_args()
    for exe in ("ffmpeg", "ffprobe"):
        if not shutil.which(exe):
            sys.exit(f"{exe} not found")
    if a.command == "sync":
        sync_content()
        return
    scripts = load_scripts(a.only)
    if a.command in ("generate", "all"):
        generate(scripts, a.force)
        sync_content()
    if a.command in ("verify", "all"):
        sys.exit(0 if verify(scripts) else 1)


if __name__ == "__main__":
    main()
