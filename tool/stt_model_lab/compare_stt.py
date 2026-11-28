#!/usr/bin/env python3
"""Speech-to-text model comparison on the Mac (sherpa-onnx, same runtime as the app).

Contains no user data. It reads the user's recordings and writes every result only to
OUT_DIR (integration_test/voice_samples/real/stt_compare_2026-11-27/, git-ignored).

Setup (once):
  uv venv --python 3.12 <venv> && uv pip install --python <venv>/bin/python \
      sherpa-onnx==1.13.8 numpy psutil huggingface_hub
  (1.13.8 = the version pinned by the app in pubspec.lock). Model folders go under
  models/eval/stt/ (git-ignored); see MODELS below for the folder names.

Run (each model and each of the two tests runs in its own fresh process):
  <venv>/bin/python tool/stt_model_lab/compare_stt.py selfcheck      # scorer vs phone results
  <venv>/bin/python tool/stt_model_lab/compare_stt.py make-long      # builds the ~5 min WAV
  <venv>/bin/python tool/stt_model_lab/compare_stt.py run-all        # all models, clips + long
  <venv>/bin/python tool/stt_model_lab/compare_stt.py run-all --only parakeet-v3-int8
  <venv>/bin/python tool/stt_model_lab/compare_stt.py report         # writes summary.md
  <venv>/bin/python tool/stt_model_lab/compare_stt.py seg-run --only parakeet-v3-int8 parakeet-v2-int8
  <venv>/bin/python tool/stt_model_lab/compare_stt.py seg-plan <wav>  # prints the planned cuts
  <venv>/bin/python tool/stt_model_lab/compare_stt.py seg-report     # writes segmented.md

Scoring mirrors integration_test/support/text_eval.dart exactly (lowercase, '-' to space,
drop everything outside [a-z0-9\\s], collapse spaces; word-level Levenshtein / reference
word count; a mustKeep group counts when any alternative appears as whole words).
Timings are relative only (Mac, 4 threads, Python binding), not phone numbers.
"""
import argparse
import json
import os
import re
import resource
import subprocess
import sys
import time
import wave
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SAMPLES = REPO / "integration_test/voice_samples"
REAL = SAMPLES / "real"
OUT_DIR = REAL / "stt_compare_2026-11-27"
STT = REPO / "models/eval/stt"
PHONE_RESULTS = REAL / "results_real_2026-11-20_run2.json"
LONG_WAV = OUT_DIR / "long_5min.wav"
LONG_META = OUT_DIR / "long_5min_meta.json"
THREADS = 4
TAIL_PAD = 4800  # 300 ms of silence, as in lib/features/ai_processing/stt_engine.dart

# key -> (kind, folder, files, licence, note)
MODELS = {
    "parakeet-v3-int8": dict(kind="transducer", dir=REPO / "models/parakeet",
        files=["encoder.int8.onnx", "decoder.int8.onnx", "joiner.int8.onnx", "tokens.txt"],
        licence="CC-BY-4.0", label="Parakeet TDT 0.6b v3 int8 (app baseline)"),
    "parakeet-v3-fp32": dict(kind="transducer", dir=STT / "parakeet-v3-fp32",
        files=["encoder.onnx", "encoder.weights", "decoder.onnx", "joiner.onnx", "tokens.txt"],
        enc="encoder.onnx", dec="decoder.onnx", join="joiner.onnx",
        licence="CC-BY-4.0", label="Parakeet TDT 0.6b v3 fp32"),
    "parakeet-v3-ultra-int8": dict(kind="transducer", dir=STT / "parakeet-v3-ultra-int8",
        files=["encoder.int8.onnx", "decoder.int8.onnx", "joiner.int8.onnx", "tokens.txt"],
        licence="CC-BY-4.0", label="Parakeet TDT 0.6b Ultra int8 (Moondream post-train of v3)"),
    "parakeet-v2-int8": dict(kind="transducer", dir=STT / "parakeet-v2-int8",
        files=["encoder.int8.onnx", "decoder.int8.onnx", "joiner.int8.onnx", "tokens.txt"],
        licence="CC-BY-4.0", label="Parakeet TDT 0.6b v2 (English) int8"),
    "whisper-turbo-int8": dict(kind="whisper", dir=STT / "whisper-turbo-int8", prefix="turbo", lang="en",
        files=["turbo-encoder.int8.onnx", "turbo-decoder.int8.onnx", "turbo-tokens.txt"],
        licence="MIT", label="Whisper large-v3-turbo int8 (language=en)"),
    "whisper-turbo-int8-auto": dict(kind="whisper", dir=STT / "whisper-turbo-int8", prefix="turbo", lang="",
        files=["turbo-encoder.int8.onnx", "turbo-decoder.int8.onnx", "turbo-tokens.txt"],
        licence="MIT", label="Whisper large-v3-turbo int8 (language auto-detect)"),
    "whisper-distil-v3.5-int8": dict(kind="whisper", dir=STT / "whisper-distil-large-v3.5-int8",
        prefix="distil-large-v3.5", lang="en",
        files=["distil-large-v3.5-encoder.int8.onnx", "distil-large-v3.5-decoder.int8.onnx",
               "distil-large-v3.5-tokens.txt"],
        licence="MIT", label="Whisper distil-large-v3.5 int8 (English only)"),
    "cohere-transcribe-int8": dict(kind="cohere", dir=STT / "cohere-transcribe-int8",
        files=None, licence="Apache-2.0", label="Cohere Transcribe 14-language int8"),
}

FILLERS = ["um", "umm", "uh", "uhh", "er", "ah", "you know", "basically", "so yeah"]
FILLER_RE = re.compile(r"\b(?:%s)\b" % "|".join(sorted(FILLERS, key=len, reverse=True)))


# ---------------------------------------------------------------- scoring (mirror of text_eval.dart)
def normalize(text):
    t = text.lower().replace("-", " ")
    t = re.sub(r"[^a-z0-9\s]", "", t)
    return re.sub(r"\s+", " ", t).strip()


def words(text):
    n = normalize(text)
    return n.split(" ") if n else []


def lev_ops(ref, hyp):
    """Return (distance, ops) with ops list of (tag, ref_word, hyp_word)."""
    n, m = len(ref), len(hyp)
    d = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        d[i][0] = i
    for j in range(m + 1):
        d[0][j] = j
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            c = 0 if ref[i - 1] == hyp[j - 1] else 1
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + c)
    ops, i, j = [], n, m
    while i > 0 or j > 0:
        if i > 0 and j > 0 and d[i][j] == d[i - 1][j - 1] + (0 if ref[i - 1] == hyp[j - 1] else 1):
            if ref[i - 1] != hyp[j - 1]:
                ops.append(("sub", ref[i - 1], hyp[j - 1]))
            i, j = i - 1, j - 1
        elif i > 0 and d[i][j] == d[i - 1][j] + 1:
            ops.append(("del", ref[i - 1], ""))
            i -= 1
        else:
            ops.append(("ins", "", hyp[j - 1]))
            j -= 1
    ops.reverse()
    return d[n][m], ops


def ref_deleted_flags(ref, hyp):
    """For each reference word: True when the alignment deletes it (no hypothesis word, not even a wrong one)."""
    n, m = len(ref), len(hyp)
    d = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        d[i][0] = i
    for j in range(m + 1):
        d[0][j] = j
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (ref[i - 1] != hyp[j - 1]))
    flags, i, j = [False] * n, n, m
    while i > 0 or j > 0:
        if i > 0 and j > 0 and d[i][j] == d[i - 1][j - 1] + (ref[i - 1] != hyp[j - 1]):
            i, j = i - 1, j - 1
        elif i > 0 and d[i][j] == d[i - 1][j] + 1:
            flags[i - 1] = True
            i -= 1
        else:
            j -= 1
    return flags


def wer(reference, hypothesis):
    ref, hyp = words(reference), words(hypothesis)
    if not ref:
        return float(len(hyp))
    return lev_ops(ref, hyp)[0] / len(ref)


def strip_fillers(text):
    return re.sub(r"\s+", " ", FILLER_RE.sub(" ", normalize(text))).strip()


def wer_nofiller(reference, hypothesis):
    ref, hyp = strip_fillers(reference).split(), strip_fillers(hypothesis).split()
    if not ref:
        return float(len(hyp))
    return lev_ops(ref, hyp)[0] / len(ref)


def missing_facts(text, must_keep):
    hay = " " + normalize(text) + " "
    missing = []
    for spellings in must_keep:
        found = any(normalize(s) and (" " + normalize(s) + " ") in hay for s in spellings)
        if not found and spellings:
            missing.append(spellings[0])
    return missing


# ---------------------------------------------------------------- data
def load_manifest():
    m = json.load(open(SAMPLES / "manifest.json"))
    return [x for x in m if re.fullmatch(r"r\d\d", x["id"])]


def read_wav16(path):
    import numpy as np
    with wave.open(str(path), "rb") as w:
        assert w.getframerate() == 16000 and w.getnchannels() == 1 and w.getsampwidth() == 2
        raw = w.readframes(w.getnframes())
    return np.frombuffer(raw, dtype="<i2").astype("float32") / 32768.0


# ---------------------------------------------------------------- worker (one process per model/test)
def build_recognizer(key):
    import sherpa_onnx as so
    cfg = MODELS[key]
    d = cfg["dir"]
    if cfg["kind"] == "transducer":
        return so.OfflineRecognizer.from_transducer(
            encoder=str(d / cfg.get("enc", "encoder.int8.onnx")),
            decoder=str(d / cfg.get("dec", "decoder.int8.onnx")),
            joiner=str(d / cfg.get("join", "joiner.int8.onnx")),
            tokens=str(d / "tokens.txt"), num_threads=THREADS, model_type="nemo_transducer",
            decoding_method="greedy_search")
    if cfg["kind"] == "whisper":
        p = cfg["prefix"]
        return so.OfflineRecognizer.from_whisper(
            encoder=str(d / f"{p}-encoder.int8.onnx"), decoder=str(d / f"{p}-decoder.int8.onnx"),
            tokens=str(d / f"{p}-tokens.txt"), language=cfg["lang"], task="transcribe",
            num_threads=THREADS)
    if cfg["kind"] == "cohere":
        return so.OfflineRecognizer.from_cohere_transcribe(
            encoder=str(d / "encoder.int8.onnx"), decoder=str(d / "decoder.int8.onnx"),
            tokens=str(d / "tokens.txt"), num_threads=THREADS, language="en",
            use_punct=True, use_itn=True)
    raise SystemExit("unknown kind")


def peak_rss_mb():
    # macOS ru_maxrss is in bytes (Linux: kilobytes).
    v = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    return (v if sys.platform == "darwin" else v * 1024) / 1e6


def current_rss_mb():
    import psutil
    return psutil.Process().memory_info().rss / 1e6


def transcribe(rec, samples):
    import numpy as np
    padded = np.concatenate([samples, np.zeros(TAIL_PAD, dtype="float32")])
    s = rec.create_stream()
    s.accept_waveform(16000, padded)
    rec.decode_stream(s)
    return s.result.text


# ---------------------------------------------------------------- segmenting (mirror of audio_segmenter.dart)
# Mirrors planSttSegments in lib/features/ai_processing/audio_segmenter.dart exactly: same
# constants, frames counted from each window start, energies summed in the same order in
# float64, lowest energy wins with the earliest on a tie. Change both together.
SEG_MAX_S, SEG_MIN_CUT_S, SEG_MIN_LAST_S = 40, 25, 10
SEG_FRAME_MS, SEG_STRETCH_MS = 20, 300


def _quietest_cut(x, rate, w_start, w_end):
    frame = rate * SEG_FRAME_MS // 1000
    per = SEG_STRETCH_MS // SEG_FRAME_MS
    n = (w_end - w_start) // frame
    energies = []
    for f in range(n):
        a = w_start + f * frame
        e = 0.0
        for v in x[a:a + frame]:
            e += v * v
        energies.append(e)
    best, best_e = 0, float("inf")
    for j in range(0, n - per + 1):
        e = 0.0
        for v in energies[j:j + per]:
            e += v
        if e < best_e:
            best, best_e = j, e
    return w_start + best * frame + per * frame // 2


def plan_segments(samples, rate=16000):
    """List of (start, end) sample ranges; see planSttSegments for the rules."""
    x = samples.tolist() if hasattr(samples, "tolist") else list(samples)
    total, max_seg = len(x), SEG_MAX_S * rate
    segs, start = [], 0
    while total - start > max_seg:
        cut = _quietest_cut(x, rate, start + SEG_MIN_CUT_S * rate,
                            min(start + max_seg, total - SEG_MIN_LAST_S * rate))
        segs.append((start, cut))
        start = cut
    segs.append((start, total))
    return segs


def transcribe_segmented(rec, samples):
    """Mirror of transcribeInSegments: one stream per segment, each tail-padded, freed before the next."""
    segs = plan_segments(samples)
    if len(segs) == 1:
        return transcribe(rec, samples), segs
    texts = []
    for a, b in segs:
        t = transcribe(rec, samples[a:b]).strip()
        if t:
            texts.append(t)
    return " ".join(texts), segs


def seg_worker(key, case, mode):
    """One fresh process per (model, case, mode) so peak RSS belongs to that case alone."""
    out = {"model": key, "label": MODELS[key]["label"], "case": case, "mode": mode, "threads": THREADS}
    rec = build_recognizer(key)
    out["rss_after_load_mb"] = round(current_rss_mb(), 1)
    sm = read_wav16(LONG_WAV if case == "long" else SAMPLES / {x["id"]: x for x in load_manifest()}[case]["file"])
    t = time.perf_counter()
    if mode == "single":
        text, segs = transcribe(rec, sm), [(0, len(sm))]
    else:
        text, segs = transcribe_segmented(rec, sm)
    el = time.perf_counter() - t
    out.update(audio_s=round(len(sm) / 16000, 2), time_s=round(el, 3), text=text,
               segments=[[a, b] for a, b in segs], peak_rss_mb=round(peak_rss_mb(), 1))
    (OUT_DIR / f"seg_{key}_{case}_{mode}.json").write_text(json.dumps(out, indent=1, ensure_ascii=False))


SEG_CASES = ("long", "r11", "r12", "r13")


def cmd_seg_run(only):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for key in (only or ["parakeet-v3-int8", "parakeet-v2-int8"]):
        for case in SEG_CASES:
            for mode in ("single", "seg"):
                print(f"=== {key} / {case} / {mode}", flush=True)
                with open(OUT_DIR / f"log_seg_{key}_{case}_{mode}.txt", "w") as log:
                    r = subprocess.run([sys.executable, "-I", os.path.abspath(__file__), "seg-worker", key, case, mode],
                                       stderr=log, stdout=log)
                print("exit", r.returncode, flush=True)


def cmd_seg_plan(path):
    sm = read_wav16(path)
    for a, b in plan_segments(sm):
        print(a, b)


def cmd_seg_report():
    man = {x["id"]: x for x in load_manifest()}
    meta = json.load(open(LONG_META))
    L = ["# Single call vs segmented (sherpa-onnx 1.13.8, Mac, 4 threads, 2026-11-27)", "",
         "Private data: this folder is git-ignored. One fresh process per row; peak RSS is that process's maximum.", "",
         "| Model | Case | Audio s | Mode | Segments (cut at s) | WER | Words | Last 6 words | Peak RSS MB | Time s |",
         "|---|---|---|---|---|---|---|---|---|---|"]
    for key in ("parakeet-v3-int8", "parakeet-v2-int8"):
        for case in SEG_CASES:
            ref = meta["reference"] if case == "long" else man[case].get("reference")
            for mode in ("single", "seg"):
                p = OUT_DIR / f"seg_{key}_{case}_{mode}.json"
                if not p.exists():
                    continue
                r = json.load(open(p))
                cuts = ", ".join(f"{b / 16000:.2f}" for _, b in r["segments"][:-1])
                w = f"{wer(ref, r['text']) * 100:.1f}%" if ref else "n/a"
                L.append(f"| {r['label']} | {case} | {r['audio_s']} | {mode} | {len(r['segments'])}{' (' + cuts + ')' if cuts else ''} | "
                         f"{w} | {len(words(r['text']))} | {' '.join(r['text'].split()[-6:])} | {r['peak_rss_mb']:.0f} | {r['time_s']:.1f} |")
    L += ["", f"Reference last 6 words of the 5-minute file: {' '.join(meta['reference'].split()[-6:])}", ""]
    for c in ("r11", "r12"):
        L.append(f"Reference last 6 words of {c}: {' '.join(man[c]['reference'].split()[-6:])}")
    (OUT_DIR / "segmented.md").write_text("\n".join(L) + "\n")
    print("wrote", OUT_DIR / "segmented.md")


def worker(key, test):
    out = {"model": key, "label": MODELS[key]["label"], "test": test, "threads": THREADS}
    t0 = time.perf_counter()
    rec = build_recognizer(key)
    out["load_s"] = round(time.perf_counter() - t0, 3)
    out["rss_after_load_mb"] = round(current_rss_mb(), 1)
    out["peak_rss_after_load_mb"] = round(peak_rss_mb(), 1)
    if test == "clips":
        # one warm-up decode so one-time graph setup is not charged to clip 1; not scored
        transcribe(rec, read_wav16(REAL / "02.wav")[:16000 * 3])
        rows = []
        for item in load_manifest():
            sm = read_wav16(SAMPLES / item["file"])
            dur = len(sm) / 16000
            t = time.perf_counter()
            try:
                text, err = transcribe(rec, sm), None
            except Exception as e:  # failure isolation: record and continue
                text, err = "", repr(e)
            el = time.perf_counter() - t
            rows.append({"id": item["id"], "audio_s": round(dur, 2), "time_s": round(el, 3),
                         "rtf": round(el / dur, 4), "text": text, "error": err,
                         "rss_mb": round(current_rss_mb(), 1), "peak_rss_so_far_mb": round(peak_rss_mb(), 1)})
            print(item["id"], f"{el:.2f}s", file=sys.stderr, flush=True)
        out["clips"] = rows
    else:
        sm = read_wav16(LONG_WAV)
        t = time.perf_counter()
        try:
            text, err = transcribe(rec, sm), None
        except Exception as e:
            text, err = "", repr(e)
        el = time.perf_counter() - t
        out["long"] = {"audio_s": round(len(sm) / 16000, 2), "time_s": round(el, 3),
                       "rtf": round(el / (len(sm) / 16000), 4), "text": text, "error": err}
    out["peak_rss_mb"] = round(peak_rss_mb(), 1)
    suffix = "" if test == "clips" else "_long"
    (OUT_DIR / f"raw_{key}{suffix}.json").write_text(json.dumps(out, indent=1, ensure_ascii=False))


# ---------------------------------------------------------------- commands
def cmd_make_long():
    import numpy as np
    parts, refs, ids, total = [], [], [], 0.0
    gap = np.zeros(int(0.3 * 16000), dtype="float32")
    for item in load_manifest():
        if not item.get("reference") or item["id"] in ("r10", "r13", "r20", "r22"):
            continue
        sm = read_wav16(SAMPLES / item["file"])
        if total + len(sm) / 16000 > 297:
            break
        parts += [sm, gap]
        refs.append(item["reference"])
        ids.append(item["id"])
        total += len(sm) / 16000 + 0.3
    audio = np.concatenate(parts)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with wave.open(str(LONG_WAV), "wb") as w:
        w.setnchannels(1), w.setsampwidth(2), w.setframerate(16000)
        w.writeframes((np.clip(audio, -1, 1) * 32767).astype("<i2").tobytes())
    LONG_META.write_text(json.dumps({"clips": ids, "seconds": round(len(audio) / 16000, 2),
                                     "reference": " ".join(refs), "clip_refs": refs}, indent=1))
    print("long wav", ids, round(len(audio) / 16000, 1), "s")


def cmd_run_all(only):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for key in MODELS:
        if only and key not in only:
            continue
        for test in ("clips", "long"):
            print(f"=== {key} / {test}", flush=True)
            log = open(OUT_DIR / f"log_{key}_{test}.txt", "w")
            r = subprocess.run([sys.executable, "-I", os.path.abspath(__file__), "worker", key, test],
                               stderr=log, stdout=log)
            log.close()
            print("exit", r.returncode, flush=True)


def cmd_selfcheck():
    r = json.load(open(PHONE_RESULTS))
    man = {x["id"]: x for x in load_manifest()}
    bad = 0
    for s in r["samples"]:
        if s["id"] in man and man[s["id"]].get("reference") and s.get("wer") is not None:
            mine = wer(man[s["id"]]["reference"], s["stt_text"])
            ok = abs(mine - s["wer"]) < 1e-9
            bad += not ok
            print(s["id"], round(mine, 4), round(s["wer"], 4), "OK" if ok else "MISMATCH")
        if s["id"] in man and s.get("missing_facts") is not None and man[s["id"]]["mustKeep"]:
            mf = missing_facts(s["stt_text"], man[s["id"]]["mustKeep"])
            if mf != s["missing_facts"]:
                bad += 1
                print(s["id"], "missing_facts MISMATCH", mf, s["missing_facts"])
    print("mismatches:", bad)


def diff_text(ref, hyp, limit=14):
    ops = lev_ops(words(ref), words(hyp))[1]
    bits = []
    for tag, a, b in ops:
        bits.append({"sub": f"{a}->{b}", "del": f"-{a}", "ins": f"+{b}"}[tag])
    s = ", ".join(bits[:limit])
    return s + (f", ... (+{len(bits) - limit} more)" if len(bits) > limit else "")


def punct_stats(texts):
    nonempty = [t for t in texts if t.strip()]
    if not nonempty:
        return 0, 0, 0
    cap = sum(1 for t in nonempty if t.strip()[0].isupper())
    term = sum(1 for t in nonempty if t.strip()[-1] in ".?!")
    comma = sum(1 for t in nonempty if "," in t)
    return cap / len(nonempty), term / len(nonempty), comma / len(nonempty)


def dir_size_gb(cfg):
    if cfg["files"] is None:
        files = [p for p in cfg["dir"].glob("*") if p.is_file()]
    else:
        files = [cfg["dir"] / f for f in cfg["files"]]
    return sum(f.stat().st_size for f in files if f.exists()) / 1e9


def cmd_report():
    man = {x["id"]: x for x in load_manifest()}
    phone = {s["id"]: s for s in json.load(open(PHONE_RESULTS))["samples"]}
    meta = json.load(open(LONG_META)) if LONG_META.exists() else None
    models = []
    for key in MODELS:
        p = OUT_DIR / f"raw_{key}.json"
        if not p.exists():
            continue
        models.append((key, json.load(open(p)),
                       json.load(open(OUT_DIR / f"raw_{key}_long.json")) if (OUT_DIR / f"raw_{key}_long.json").exists() else None))
    L = ["# STT comparison on the Mac (sherpa-onnx 1.13.8, 4 threads, 2026-11-27)", "",
         "Private data: this folder is git-ignored. Timings are relative only (Mac, Python binding).", ""]
    rows = []
    for key, c, lg in models:
        cl = {r["id"]: r for r in c["clips"]}
        wers, wers_nf, nfacts, nhit, tsum, asum = [], [], 0, 0, 0.0, 0.0
        wers30 = []
        wrong = []
        for cid, item in man.items():
            t = cl[cid]["text"]
            tsum += cl[cid]["time_s"]
            asum += cl[cid]["audio_s"]
            if item.get("reference"):
                w = wer(item["reference"], t)
                wers.append(w)
                if cl[cid]["audio_s"] <= 30:
                    wers30.append(w)
                wers_nf.append(wer_nofiller(item["reference"], t))
            mf = missing_facts(t, item["mustKeep"]) if item["mustKeep"] else []
            nfacts += len(item["mustKeep"])
            nhit += len(item["mustKeep"]) - len(mf)
            if item.get("reference") and (mf or w >= 0.10):
                wrong.append((cid, w, mf))
        cap, term, comma = punct_stats([cl[i]["text"] for i in man if man[i].get("reference") or i in ("r10", "r13", "r22")])
        # pooled WER: total edits / total reference words
        edits = refw = 0
        for cid, item in man.items():
            if item.get("reference"):
                edits += lev_ops(words(item["reference"]), words(cl[cid]["text"]))[0]
                refw += len(words(item["reference"]))
        rows.append(dict(key=key, c=c, lg=lg, mean=sum(wers) / len(wers), mean30=sum(wers30) / len(wers30), n30=len(wers30),
                         peak9=cl["r09"].get("peak_rss_so_far_mb", 0), pooled=edits / refw,
                         nf=sum(wers_nf) / len(wers_nf), facts=nhit / nfacts, nhit=nhit, nfacts=nfacts,
                         cap=cap, term=term, comma=comma, rtf=tsum / asum, tsum=tsum, wrong=wrong,
                         size=dir_size_gb(MODELS[key]), cl=cl))
    L += ["## Summary table", "",
          "WER = mean of per-clip WER over the 18 clips that have a reference (harness definition); pooled = total edits / total reference words; "
          "no-filler = same after removing um/uh/etc. from both sides. mustKeep = groups hit / groups (any alternative counts).", "",
          "| Model | Size on disk | Mean WER | Mean WER clips <=30 s | Pooled WER | WER no-filler | mustKeep | Capitalised / final stop / comma (share of clips) | RTF (all 22) | Load s | Peak RSS through r09 (all <=19 s) MB | Peak RSS all 22 clips MB | Licence |",
          "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in rows:
        L.append(f"| {r['c']['label']} | {r['size']:.2f} GB | {r['mean']*100:.1f}% | {r['mean30']*100:.1f}% | {r['pooled']*100:.1f}% | {r['nf']*100:.1f}% | "
                 f"{r['nhit']}/{r['nfacts']} ({r['facts']*100:.0f}%) | {r['cap']*100:.0f}% / {r['term']*100:.0f}% / {r['comma']*100:.0f}% | "
                 f"{r['rtf']:.3f} | {r['c']['load_s']:.1f} | {r['peak9']:.0f} | {r['c']['peak_rss_mb']:.0f} | {MODELS[r['key']]['licence']} |")
    L += ["", "Reference: phone Parakeet v3 int8 run (2026-11-20 run2): mean WER over the same clips "
          f"{sum(phone[i]['wer'] for i in man if phone[i].get('wer') is not None)/sum(1 for i in man if phone[i].get('wer') is not None)*100:.1f}%.", ""]
    L += ["## Five-minute single call", ""]
    if meta:
        L += [f"Concatenation of clips {', '.join(meta['clips'])} ({meta['seconds']} s, 16 kHz mono), one recognizer call, fresh process per model.", "",
              "| Model | Time s | RTF | Peak RSS MB | WER vs concatenated reference | Source clips found (a clip is missing when >=50% of its words are deleted by the alignment) | Words out / ref words | First 15 words | Last 15 words | Error |",
              "|---|---|---|---|---|---|---|---|---|---|"]
        rw = words(meta["reference"])
        for r in rows:
            lg = r["lg"]
            if not lg:
                L.append(f"| {r['c']['label']} | not run | | | | | | | |")
                continue
            t = lg["long"]["text"]
            tw = t.split()
            flags = ref_deleted_flags(rw, words(t))
            found, missing_clips, pos = [], [], 0
            for cid, cr in zip(meta["clips"], meta.get("clip_refs", [])):
                n = len(words(cr))
                if sum(flags[pos:pos + n]) / n >= 0.5:
                    missing_clips.append(cid)
                else:
                    found.append(cid)
                pos += n
            L.append(f"| {r['c']['label']} | {lg['long']['time_s']:.1f} | {lg['long']['rtf']:.3f} | {lg['peak_rss_mb']:.0f} | "
                     f"{wer(meta['reference'], t)*100:.1f}% | {len(found)}/{len(meta['clips'])}{' (missing ' + ','.join(missing_clips) + ')' if missing_clips else ''} | {len(words(t))} / {len(rw)} | {' '.join(tw[:15])} | {' '.join(tw[-15:])} | {lg['long']['error'] or ''} |")
        L += ["", f"Reference first 15 words: {' '.join(meta['reference'].split()[:15])}", "",
              f"Reference last 15 words: {' '.join(meta['reference'].split()[-15:])}", ""]
    L += ["## Clips without a reference (r10 32 s, r13 128 s, r20 silence, r22 Hindi/English)", "",
          "Compared with the phone Parakeet v3 int8 transcript (not ground truth). Words = normalised word count.", "",
          "| Model | r10 words | r13 words | r13 start / end | r20 (silence) output | r22 text |", "|---|---|---|---|---|---|"]
    ph = {i: phone[i]["stt_text"] for i in ("r10", "r13", "r22")}
    L.append(f"| phone Parakeet v3 int8 | {len(words(ph['r10']))} | {len(words(ph['r13']))} | {' '.join(ph['r13'].split()[:6])} ... {' '.join(ph['r13'].split()[-6:])} | (empty) | {ph['r22']} |")
    for r in rows:
        cl = r["cl"]
        t13 = cl["r13"]["text"]
        L.append(f"| {r['c']['label']} | {len(words(cl['r10']['text']))} | {len(words(t13))} | {' '.join(t13.split()[:6])} ... {' '.join(t13.split()[-6:])} | "
                 f"{cl['r20']['text'] or '(empty)'} | {cl['r22']['text']} |")
    L += ["", "## Per-model details", ""]
    for r in rows:
        cl = r["cl"]
        L += [f"### {r['c']['label']}", "",
              f"load {r['c']['load_s']:.1f} s, RSS after load {r['c']['rss_after_load_mb']:.0f} MB, peak {r['c']['peak_rss_mb']:.0f} MB, "
              f"total decode {r['tsum']:.1f} s for 530 s of audio.", "",
              "| clip | audio s | time s | RTF | WER | missing mustKeep | diff (ref->hyp, - deleted, + inserted) |", "|---|---|---|---|---|---|---|"]
        for cid, item in man.items():
            t = cl[cid]["text"]
            if item.get("reference"):
                w = wer(item["reference"], t)
                mf = missing_facts(t, item["mustKeep"])
                d = diff_text(item["reference"], t) if w > 0 else ""
                L.append(f"| {cid} | {cl[cid]['audio_s']} | {cl[cid]['time_s']} | {cl[cid]['rtf']} | {w*100:.1f}% | {', '.join(mf)} | {d} |")
            else:
                L.append(f"| {cid} | {cl[cid]['audio_s']} | {cl[cid]['time_s']} | {cl[cid]['rtf']} | n/a | | no reference |")
        L.append("")
    (OUT_DIR / "summary.md").write_text("\n".join(L))
    print("wrote", OUT_DIR / "summary.md")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("selfcheck"), sub.add_parser("make-long"), sub.add_parser("report")
    ra = sub.add_parser("run-all")
    ra.add_argument("--only", nargs="*")
    w = sub.add_parser("worker")
    w.add_argument("key"), w.add_argument("test", choices=["clips", "long"])
    sr = sub.add_parser("seg-run")
    sr.add_argument("--only", nargs="*")
    sw = sub.add_parser("seg-worker")
    sw.add_argument("key"), sw.add_argument("case", choices=SEG_CASES), sw.add_argument("mode", choices=["single", "seg"])
    sp = sub.add_parser("seg-plan")
    sp.add_argument("wav")
    sub.add_parser("seg-report")
    a = ap.parse_args()
    if a.cmd.startswith("seg-"):
        {"seg-run": lambda: cmd_seg_run(a.only), "seg-worker": lambda: seg_worker(a.key, a.case, a.mode),
         "seg-plan": lambda: cmd_seg_plan(a.wav), "seg-report": cmd_seg_report}[a.cmd]()
        sys.exit(0)
    {"selfcheck": cmd_selfcheck, "make-long": cmd_make_long, "report": cmd_report}.get(a.cmd, lambda: None)() \
        if a.cmd in ("selfcheck", "make-long", "report") else (
        cmd_run_all(a.only) if a.cmd == "run-all" else worker(a.key, a.test))
