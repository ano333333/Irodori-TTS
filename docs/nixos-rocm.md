# NixOS / Radeon で v4-Large の VoiceDesign を実行する

リポジトリのルートで実行します。`flake.lock` で固定した Nixpkgs から
uv、Python 3.11、FFmpeg、wheel の実行に必要な共有ライブラリを導入します。
Python の依存関係は既存の `uv.lock` と `rocm` extra を使用します。
HIP、rocBLAS、MIOpen は PyTorch の ROCm 7.1 wheel に同梱されています。

```bash
nix develop
uv sync --locked --extra rocm
```

Python 3.11 は、依存する SentencePiece 0.1.99 のビルド済み wheel を使うために
指定しています。uv による別の Python の自動ダウンロードは無効です。
仮想環境は `.venv/`、uv と Hugging Face のキャッシュは `.cache/` に作成されます。
初回は PyTorch とモデルなどの大きなダウンロードが発生します。

## GPU の確認

ホストで `/dev/kfd` と `/dev/dri/renderD*` にアクセスできる必要があります。
GPU デバイスを公開していないサンドボックス内では、通常のターミナルで実行してください。
ROCm でも PyTorch のデバイス名は `cuda` です。

```bash
uv run --no-sync python - <<'PY'
import torch
print("PyTorch:", torch.__version__, "ROCm:", torch.version.hip)
assert torch.version.hip is not None, "ROCm 版 PyTorch が必要です"
assert torch.cuda.is_available(), "GPU にアクセスできません"
for i in range(torch.cuda.device_count()):
    p = torch.cuda.get_device_properties(i)
    print(i, p.name, f"{p.total_memory / 2**30:.1f} GiB")
PY
```

内蔵 GPU もある場合、上の結果から使用する Radeon の番号を選びます。
以下は GPU 0 を使用する例です。`HIP_VISIBLE_DEVICES` で選んだ GPU は、
プロセス内では `cuda:0` になります。

## VoiceDesign

```bash
HIP_VISIBLE_DEVICES=0 uv run --no-sync python infer.py \
  --hf-checkpoint Aratako/Irodori-TTS-v4-Large \
  --text "こんにちは、私はAIです。これは音声合成のテストです。" \
  --caption "落ち着いた、近い距離感の女性話者" \
  --no-ref \
  --model-device cuda \
  --codec-device cuda \
  --output-wav outputs/sample_voice_design.wav
```

参照音声は不要です。モデル、同梱 tokenizer、音声コーデックは自動取得されます。
モデル精度は README のコマンドと同じ既定値の FP32 です。
VRAM が不足する場合は `--model-precision bf16` や `--codec-device cpu` を指定します。
バックエンドを維持するため、同期後のコマンドでは `uv run --no-sync` を使ってください。

## 動作確認結果

2026-09-30、NixOS / Radeon（GPU 0、VRAM 24 GiB）で上記コマンドを実行しました。

- Python 3.11.16、uv 0.11.21、PyTorch / torchaudio 2.10.0+rocm7.1
- v4-Large、モデル・コーデックとも GPU / FP32、SilentCipher 透かし処理あり
- `outputs/sample_voice_design.wav`: 48 kHz、モノラル、5.76 秒
- 出力波形が有限値で、無音でないことを確認
- `nix flake check --no-build` 成功

この環境では ROCm wheel の `/opt/amdgpu/share/libdrm/amdgpu.ids` 不在や
torchao の CUDA 用拡張の読み込み警告が出ますが、上記の FP32 推論は完了します。
GPU 名が `AMD Radeon Graphics` と表示される場合も、番号と VRAM 容量で選択できます。

モデルの詳細は [Irodori-TTS-v4-Large のモデルカード](https://huggingface.co/Aratako/Irodori-TTS-v4-Large) を参照してください。
