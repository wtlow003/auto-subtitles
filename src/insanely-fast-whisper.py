from datetime import timedelta
from typing import Dict, Tuple, Union

import cli
import srt
import torch
from constants import INSANELY_FAST_WHISPER_MODELS_MAPPING
from rich.progress import BarColumn, Progress, TextColumn, TimeElapsedColumn
from srt import Subtitle
from transformers import pipeline
from transformers.utils import is_flash_attn_2_available


# ref: https://github.com/Vaibhavs10/insanely-fast-whisper/blob/main/convert_output.py
class SRTFormatter:
    @classmethod
    def format_seconds(cls, seconds: float) -> timedelta:
        """_summary_

        Args:
            seconds (_type_): _description_

        Returns:
            _type_: _description_
        """
        # hours, remainder = divmod(seconds, 3600)
        # minutes, seconds = divmod(remainder, 60)
        # return f"{int(hours):02d}:{int(minutes):02d}:{seconds:06.3f}"
        return timedelta(seconds=seconds)

    @classmethod
    def format_chunk(
        cls, chunk: Dict[str, Union[Tuple[float, float], str]]
    ) -> Tuple[timedelta, timedelta, str]:
        """_summary_

        Args:
            chunk (_type_): _description_
            index (_type_): _description_

        Returns:
            _type_: _description_
        """
        start: float = chunk["timestamp"][0]  # type: ignore
        end: float = chunk["timestamp"][1]  # type: ignore
        print(start, end, chunk["text"])  # type: ignore
        start_formatted, end_formatted = (
            cls.format_seconds(start),
            cls.format_seconds(end),
        )  # type: ignore
        return start_formatted, end_formatted, chunk["text"]  # type: ignore


def main():
    """_summary_"""
    args = cli.insanely_fast_whisper_cli()

    if args.device not in ["mps", "cuda"]:
        raise ValueError("Device must be 'mps' or 'cuda'")

    # due to stability issues as well as hallucination issues,
    # only large models are supported
    if not args.model.startswith("large"):
        raise ValueError("Model must be 'large' or 'large-v2' or 'large-v3'")

    # load pipeline
    # only only supports mps or cuda
    pipe = pipeline(
        task="automatic-speech-recognition",
        model=INSANELY_FAST_WHISPER_MODELS_MAPPING[args.model],
        torch_dtype=torch.float16,
        device=torch.device(args.device),
        model_kwargs=(
            {"attn_implementation": "flash_attention_2"}
            if is_flash_attn_2_available()
            else {"attn_implementation": "sdpa"}
        ),
    )

    with Progress(
        TextColumn("[progress.description]{task.description}"),
        BarColumn(style="yellow1", pulse_style="white"),
        TimeElapsedColumn(),
    ) as progress:
        progress.add_task(
            f"[yellow]Transcribing with insanely-fast-whisper ({args.model})...",
            total=None,
        )

        outputs = pipe(
            args.audio_path,
            chunk_length_s=args.max_length,
            # ref: https://github.com/Vaibhavs10/insanely-fast-whisper?tab=readme-ov-file#frequently-asked-questions
            batch_size=4 if args.device == "mps" else 24,
            return_timestamps=True,
            generate_kwargs={"task": "transcribe", "num_beams": 5},
        )

        print(outputs)
    # formatting timestamps and save for srt
    transcripts = []
    for idx, output in enumerate(outputs["chunks"]):  # type: ignore
        start, end, text = SRTFormatter.format_chunk(output)  # type: ignore
        transcripts.append(Subtitle(idx + 1, start, end, text.strip()))  # type: ignore

    with open(args.output_path, "w") as f:
        f.write(srt.compose(transcripts))


if __name__ == "__main__":
    torch.mps.empty_cache()
    torch.cuda.empty_cache()
    main()
