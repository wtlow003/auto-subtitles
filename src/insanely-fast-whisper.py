from datetime import timedelta
from typing import Dict, List, Tuple, Union

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
        start_formatted, end_formatted = (
            cls.format_seconds(start),
            cls.format_seconds(end),
        )  # type: ignore
        return start_formatted, end_formatted, chunk["text"]  # type: ignore


def split_by_length(
    chunks: List[Dict[str, Union[Tuple[float, float], str]]], max_length: int
) -> List[Dict[str, Union[Tuple[float, float], str]]]:
    """Given a list of chunks, split them into segments of max_length

    Args:
        chunks (List[Dict[str, Union[Tuple[float, float], str]]]): List of chunks
        max_length (int): Maximum length of each segment

    Returns:
        List[Dict[str, Union[Tuple[float, float], str]]]: List of segments
    """
    segments = []
    idx = 0

    while idx < len(chunks):
        curr_text = []
        curr_length = 0
        start_timestamp = 0.0 if idx == 0 else chunks[idx - 1]["timestamp"][1]
        end_timestamp = chunks[idx]["timestamp"][1]

        while idx < len(chunks) and curr_length + len(chunks[idx]["text"]) < max_length:
            text = chunks[idx]["text"].strip()  # type: ignore
            if text.startswith("-"):
                last_word = curr_text.pop()
                curr_text.append("".join([last_word, text]))
            else:
                curr_text.append(text)
            curr_length += len(text)
            end_timestamp = chunks[idx]["timestamp"][1]
            idx += 1

        # check if next word is part of a hyphenated word
        # outside of max_length
        if idx < len(chunks) and chunks[idx]["text"].startswith("-"):  # type: ignore
            last_word = curr_text.pop()
            text = chunks[idx]["text"].strip()  # type: ignore
            curr_text.append("".join([last_word, text]))
            end_timestamp = chunks[idx]["timestamp"][1]
            idx += 1

        # check if this is the last word
        if idx == len(chunks) - 1:
            curr_text.append(chunks[idx]["text"].strip())  # type: ignore
            end_timestamp = chunks[idx]["timestamp"][1]
            idx += 1

        segments.append(
            {
                "text": " ".join(curr_text),
                "timestamp": (start_timestamp, end_timestamp),
            }
        )

    return segments


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

        # ref: https://github.com/huggingface/transformers/issues/22053
        # for potential last tiemestamp issue
        outputs = pipe(
            args.audio_path,
            chunk_length_s=30,
            # ref: https://github.com/Vaibhavs10/insanely-fast-whisper?tab=readme-ov-file#frequently-asked-questions
            batch_size=8 if args.device == "mps" else 24,
            return_timestamps="word",
            generate_kwargs={"task": "transcribe", "num_beams": 1},
        )

    segments = split_by_length(outputs["chunks"], args.max_length)  # type: ignore

    # formatting timestamps and save for srt
    transcripts = []
    for idx, output in enumerate(segments):  # type: ignore
        start, end, text = SRTFormatter.format_chunk(output)  # type: ignore
        transcripts.append(Subtitle(idx + 1, start, end, text.strip()))  # type: ignore

    with open(args.output_path, "w") as f:
        f.write(srt.compose(transcripts))


if __name__ == "__main__":
    torch.mps.empty_cache()
    torch.cuda.empty_cache()
    main()
