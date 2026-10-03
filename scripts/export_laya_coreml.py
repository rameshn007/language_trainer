#!/usr/bin/env python3
"""
scripts/export_laya_coreml.py

Exports convaiinnovations/laya (multilingual mmBERT-base) to an Apple Core ML
package (.mlpackage / .mlmodelc) optimized for the Apple Neural Engine (ANE)
on iPhone 17 Pro Max.

Features:
- Fixed-sequence tracing (e.g. seq_len=128) tailored for voice quiz grading
- INT8 linear weight quantization (~160 MB footprint vs 647 MB FP32)
- Pre-compilation with xcrun coremlc into iOS Bundle Resources
- Export of tokenizer configs and vocabulary

Usage:
    python3 scripts/export_laya_coreml.py [--quantize int8] [--output-dir ios/Runner/Models]
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT_DIR = REPO_ROOT / "ios/Runner/Models"


def check_dependencies():
    missing = []
    try:
        import torch
    except ImportError:
        missing.append("torch")
    try:
        import coremltools
    except ImportError:
        missing.append("coremltools")
    try:
        import laya
    except ImportError:
        missing.append("laya")

    if missing:
        print(f"❌ Missing required dependencies: {', '.join(missing)}")
        print(f"👉 Please install them: pip install {' '.join(missing)}")
        sys.exit(1)


def export_coreml(
    output_dir: Path,
    checkpoint: str = "convaiinnovations/laya",
    subfolder: str = "multilingual",
    quantize: str = "int8",
    seq_len: int = 128,
    compile_model: bool = True,
):
    import torch
    import coremltools as ct
    from coremltools.optimize.coreml import (
        OpLinearQuantizerConfig,
        OptimizationConfig,
        linear_quantize_weights,
    )
    import laya

    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"🚀 Loading Laya checkpoint: {checkpoint} (subfolder={subfolder})...")

    # Load agent
    agent = laya.load(checkpoint, subfolder=subfolder)
    model = agent.model
    model.eval()

    print(f"📦 Tracing model with sequence length = {seq_len}...")
    dummy_input_ids = torch.ones((1, seq_len), dtype=torch.int32)
    dummy_attention_mask = torch.ones((1, seq_len), dtype=torch.int32)
    dummy_marker_pos = torch.zeros((1, 4), dtype=torch.int32)
    dummy_marker_mask = torch.ones((1, 4), dtype=torch.bool)
    dummy_qtype = torch.zeros((1,), dtype=torch.int32)

    class TraceableWrapper(torch.nn.Module):
        def __init__(self, inner_model):
            super().__init__()
            self.inner = inner_model

        def forward(self, input_ids, attention_mask, marker_pos, marker_mask, qtype):
            logits, act_logits = self.inner(
                input_ids=input_ids,
                attention_mask=attention_mask,
                marker_pos=marker_pos,
                marker_mask=marker_mask,
                qtype=qtype,
            )
            return logits, act_logits

    wrapper = TraceableWrapper(model).eval()

    with torch.no_grad():
        traced = torch.jit.trace(
            wrapper,
            (
                dummy_input_ids,
                dummy_attention_mask,
                dummy_marker_pos,
                dummy_marker_mask,
                dummy_qtype,
            ),
        )

    print("⚙️  Converting TorchScript model to Core ML (.mlpackage)...")
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, seq_len), dtype=int),
            ct.TensorType(name="attention_mask", shape=(1, seq_len), dtype=int),
            ct.TensorType(name="marker_pos", shape=(1, 4), dtype=int),
            ct.TensorType(name="marker_mask", shape=(1, 4), dtype=int),
            ct.TensorType(name="qtype", shape=(1,), dtype=int),
        ],
        outputs=[
            ct.TensorType(name="logits"),
            ct.TensorType(name="act_logits"),
        ],
        minimum_deployment_target=ct.target.iOS15,
        compute_precision=ct.precision.FLOAT16,
    )

    # Metadata
    mlmodel.author = "Convai Innovations (Laya) / Simple Language Trainer"
    mlmodel.short_description = (
        "Non-autoregressive System 1 decision model for European Portuguese semantic evaluation"
    )

    package_path = output_dir / "LayaMultilingual.mlpackage"

    if quantize == "int8":
        print("⚡ Applying INT8 linear weight quantization for Apple Neural Engine...")
        op_config = OpLinearQuantizerConfig(mode="linear_symmetric", weight_threshold=512)
        opt_config = OptimizationConfig(global_config=op_config)
        mlmodel = linear_quantize_weights(mlmodel, config=opt_config)

    print(f"💾 Saving Core ML package to {package_path}...")
    mlmodel.save(str(package_path))
    print(f"✅ Saved Core ML package: {package_path}")

    # Compile to .mlmodelc if xcrun coremlc is present
    if compile_model and shutil.which("xcrun"):
        print("🔨 Pre-compiling .mlpackage to .mlmodelc with xcrun coremlc...")
        try:
            subprocess.run(
                ["xcrun", "coremlc", "compile", str(package_path), str(output_dir)],
                check=True,
            )
            print(f"✅ Successfully compiled: {output_dir / 'LayaMultilingual.mlmodelc'}")
        except subprocess.CalledProcessError as e:
            print(f"⚠️  coremlc compilation returned an error: {e}")

    # Copy tokenizer files if available
    tok_dir = getattr(agent, "tok", None)
    if tok_dir and hasattr(tok_dir, "save_pretrained"):
        tok_out = output_dir / "tokenizer"
        tok_out.mkdir(parents=True, exist_ok=True)
        agent.tok.save_pretrained(str(tok_out))
        print(f"✅ Tokenizer saved to: {tok_out}")

    print("\n🎉 Model export complete! The model is ready for Apple Neural Engine inference on iOS.")


def main():
    parser = argparse.ArgumentParser(description="Export Laya to Core ML for iOS")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Directory to save the Core ML model",
    )
    parser.add_argument(
        "--checkpoint",
        type=str,
        default="convaiinnovations/laya",
        help="HuggingFace model id",
    )
    parser.add_argument(
        "--subfolder",
        type=str,
        default="multilingual",
        help="Subfolder in model repository",
    )
    parser.add_argument(
        "--quantize",
        type=str,
        choices=["int8", "fp16", "none"],
        default="int8",
        help="Quantization precision",
    )
    parser.add_argument(
        "--seq-len",
        type=int,
        default=128,
        help="Fixed sequence length for prompt + spoken utterance",
    )
    parser.add_argument(
        "--no-compile",
        action="store_true",
        help="Skip compiling .mlpackage to .mlmodelc",
    )

    args = parser.parse_args()
    check_dependencies()
    export_coreml(
        output_dir=args.output_dir,
        checkpoint=args.checkpoint,
        subfolder=args.subfolder,
        quantize=args.quantize,
        seq_len=args.seq_len,
        compile_model=not args.no_compile,
    )


if __name__ == "__main__":
    main()
