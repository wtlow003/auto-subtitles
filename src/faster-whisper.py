import stable_whisper

import cli


def main():
    """_summary_"""
    args = cli.faster_whisper_cli()
    # load faster-whisper model: https://github.com/SYSTRAN/faster-whisper
    model = stable_whisper.load_faster_whisper(
        args.model,
        cpu_threads=args.cpu_threads,
        num_workers=args.num_workers,
    )
    result = model.transcribe_stable(
        audio=args.audio_path,
        verbose=True,
        vad=args.vad,
        vad_threshold=args.vad_threshold,
        # task="translate"
    )
    print(result.result)
    # adjust max-length per segment to `args.max_length`
    result.split_by_length(max_chars=args.max_length)
    result.to_srt_vtt(
        filepath=args.output_path,
        word_level=args.wl,
    )


if __name__ == "__main__":
    main()
