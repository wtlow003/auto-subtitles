import argparse


def faster_whisper_cli():
    """_summary_

    Returns:
        _type_: _description_
    """
    parser = argparse.ArgumentParser(description="Transcribe audio to text")
    parser.add_argument("--audio_path", type=str, help="Path to audio file")
    parser.add_argument("--output_path", type=str, help="Path to output file")
    parser.add_argument("--model", type=str, default="medium", help="Model to use")
    parser.add_argument(
        "--cpu_threads", type=int, default=4, help="Number of CPU threads"
    )
    parser.add_argument("--num_workers", type=int, default=4, help="Number of workers")
    parser.add_argument(
        "--wl", action="store_true", help="Include word-level timestamps"
    )
    parser.add_argument("--vad", action="store_true", help="Use VAD")
    parser.add_argument(
        "--vad_threshold", type=float, default=0.35, help="VAD threshold"
    )
    parser.add_argument(
        "--max_length", type=int, default=47, help="Max characters per line"
    )
    args = parser.parse_args()

    return args


def translator_cli():
    """_summary_

    Returns:
        _type_: _description_
    """
    parser = argparse.ArgumentParser(
        description="Translate subtitle text from SRT file."
    )
    parser.add_argument("--translate_from", type=str, help="Language to translate from")
    parser.add_argument("--translate_to", type=str, help="Language to translate to")
    parser.add_argument("--subs_path", type=str, help="Path to subtitle file")
    args = parser.parse_args()

    return args
