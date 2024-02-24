#!/bin/bash

# default values
DEFAULT_VIDEO_URL="https://www.youtube.com/watch\?v\=ucd63nIZZ60"
DEFAULT_OUTPUT_PATH="output"
DEFAULT_BACKEND="whisper-cpp"
DEFAULT_WHISPER_BIN_PATH="whisper.cpp"
DEFAULT_MODEL="medium"
DEFAULT_MAX_LENGTH=47
DEFAULT_THREADS=4
DEFAULT_WORKERS=1
VAD_THRESHOLD=0.2
WL_FLAG=false

BASE_RESOLUTION_WIDTH=1920
BASE_RESOLUTION_HEIGHT=1080
BASE_FONT_SIZE=14
DEFAULT_FONT="Arial Unicode MS"

# check if yt-dlp and ffmpeg are installed
if ! command -v yt-dlp &>/dev/null || ! command -v ffmpeg &>/dev/null; then
    echo "Please install yt-dlp and ffmpeg first."
    exit 1
fi

function print_run_parameters() {
    printf "\n\033[33m========== Run Parameters ==========\033[0m\n"
    echo "URL: $VIDEO_URL"
    echo "OUTPUT PATH: $OUTPUT_PATH"
    echo "BACKEND: $BACKEND"
    echo "MODEL NAME: $MODEL"
    echo "MAX LENGTH: $MAX_LENGTH"
    echo "VAD THRESHOLD: $VAD_THRESHOLD"
    echo "NO. THREADS: $THREADS"
    echo "NO. WORKERS: $WORKERS"
    echo -e "\033[33m====================================\033[0m"
}

function create_output_folder() {
    # Create or check existence of the output folder.
    # Args:
    #   $1: Output folder path

    local output_folder="$1"

    # check if the output folder exists
    if [ ! -d "$output_folder" ]; then
        # if not, create the output folder
        mkdir -p "$output_folder"
        echo "Output folder '$output_folder' created."
    else
        echo "Output folder '$output_folder' already exists."
    fi
}

function download_and_convert() {
    # Download a YouTube video, convert it to WAV, and save the result.
    # Args:
    #   $1: Video URL
    #   $2: Output path

    local video_url="$1"
    local output_path="$2"
    local filter_flag="bestvideo[ext=mp4][height<=1080]+bestaudio[ext=m4a]/best[ext=mp4]/best"

    # retrieve video title and metadata
    title=$(yt-dlp --get-title "$video_url")
    cleaned_title=$(echo "$title" | tr -cs '[:alnum:]' '-' | sed 's/-$//' | tr '[:upper:]' '[:lower:]')
    metadata=$(yt-dlp --get-filename \
            -f "$filter_flag" \
            -o "%(width)s %(height)s" \
        "$video_url")

    # extract video width and height from metadata
    video_width=$(echo "$metadata" | cut -d' ' -f1)
    video_height=$(echo "$metadata" | cut -d' ' -f2)

    # create directory for the current download
    saved_dir="$output_path/$cleaned_title"
    mkdir -p "$saved_dir"

    echo "Saving to $saved_dir..."

    echo "Downloading video..."
    yt-dlp -f "$filter_flag" -o "$saved_dir/original.mp4" "$video_url"

    # extract audio from the video using ffmpeg
    echo "Converting video to WAV..."
    if [ ! -f "$saved_dir/audio.wav" ]; then
        ffmpeg -i "$saved_dir/original.mp4" -vn -acodec pcm_s16le -ar 16000 -ac 2 "$saved_dir/audio.wav"
    fi

    echo "Conversion complete. WAV file is saved as $saved_dir.wav"
}

function generate_transcript() {
    # Generate a transcript using a specified API.
    # Args: None
    local backend="$1"

    echo "Generating transcript, using backend=$backend..."

    if [ "$backend" = "whisper-cpp" ]; then
        echo "Using whisper-cpp backend..."

        # calling whisper-cpp endpoint
        # curl 127.0.0.1:8080/inference \
            #     -H "Content-Type: multipart/form-data" \
            #     -F file="@$saved_dir/audio.wav" \
            #     -F temperature="0.0" \
            #     -F temperature_inc="0.2" \
            #     -F response_format="srt" \
            #     -F max_length=10 \
            #     -o "$saved_dir/subs.srt"

        # cd ~/code/whisper.cpp || echo "whisper.cpp path not found"
        "$WHISPER_BIN_PATH/main" -m "$WHISPER_BIN_PATH/models/ggml-$MODEL.bin" \
            -f "$saved_dir/audio.wav" \
            -ml 47 \
            -osrt \
            -of "$saved_dir/subs" \
            -t "$THREADS" \
            -p "$WORKERS" \
            --split-on-word

    elif [ "$backend" = "faster-whisper" ]; then
        echo "Using faster-whisper backend..."

        cmd="OMP_NUM_THREADS=$THREADS python3 src/faster-whisper.py \
            --audio_path '$saved_dir/audio.wav' \
            --output_path '$saved_dir/subs.srt' \
            --model '$MODEL' \
            --cpu_threads '$THREADS' \
            --num_workers '$WORKERS' \
            --vad \
            --vad_threshold '$VAD_THRESHOLD' \
            --max_length '$MAX_LENGTH'"

        if [ "$WL_FLAG" = true ]; then
            cmd="$cmd --wl"
        fi

        eval "$cmd"
    fi

    if [ -n "$TRANSLATE_FROM" ] && [ -n "$TRANSLATE_TO" ]; then
        echo -e "\033[33mGenerating translation...\033[33m"

        OMP_NUM_THREADS=$THREADS python3 src/translate.py \
            --translate_from "$TRANSLATE_FROM" \
            --translate_to "$TRANSLATE_TO" \
            --subs_path "$saved_dir/subs.srt"
    fi

    echo -e "\033[32mTranscript generated. SRT file is saved in $saved_dir.\033[32m"
}

function adjust_subtitle_size() {
    # Adjust subtitle size based on the current video width and height.
    # Args:
    #   $1: Current video width
    #   $2: Current video height

    curr_width="$1"
    curr_height="$2"

    width_ratio=$(awk "BEGIN { printf \"%.4f\", $curr_width / $BASE_RESOLUTION_WIDTH }")
    height_ratio=$(awk "BEGIN { printf \"%.4f\", $curr_height / $BASE_RESOLUTION_HEIGHT }")

    if (($(awk "BEGIN { printf \"%d\", ($width_ratio < $height_ratio) ? 1 : 0 }"))); then
        resize_ratio="$width_ratio"
    else
        resize_ratio="$height_ratio"
    fi

    result=$(awk "BEGIN { rounded = int($BASE_FONT_SIZE * $resize_ratio + 0.5); printf \"%.0f\", rounded }")
    echo "$result"
}

function overlay_subtitles() {
    # Overlay subtitles on the original video with adjusted font size.
    # Args: None

    echo "Overlaying subtitles..."

    font_size=$(adjust_subtitle_size "$video_width" "$video_height")
    subs="$saved_dir/subs.srt"

    # overwrite existing subbed.mp4 even if it exists
    echo y |
    ffmpeg -i "$saved_dir/original.mp4" \
        -vf "subtitles=$subs:force_style='FontSize=$font_size,FontName=$FONT,OutlineColour=&H40000000,BorderStyle=3'" \
        "$saved_dir/subbed.mp4" \
        -crf 1 \
        -c:a copy \
        -threads 8

    echo "Subtitles overlayed."
}

# ref: http://docopt.org/
function help() {
    echo "Usage: $0 [-u <youtube_video_url>] [options]"
    echo "Options:"
    echo "  -u, --url <youtube_video_url>                       YouTube video URL"
    echo "  -o, --output-path <output_path>                     Output path"
    echo "  -b, --backend <backend>                             Backend to use: whisper-cpp or faster-whisper"
    echo "  -wbp, --whisper-bin-path <whisper_bin_path>         Path to whisper-cpp binary. Required if using [--backend whisper-cpp]."
    echo "  -ml, --max-length <max_length>                      Maximum length of the generated transcript"
    echo "  -t, --threads <threads>                             Number of threads to use"
    echo "  -w, --workers <workers>                             Number of workers to use"
    echo "  -m, --model <model>                                 Model name to use"
    echo "  -tf, --translate-from <translate_from>              Translate from language"
    echo "  -tt, --translate-to <translate_to>                  Translate to language"
    echo "  -f, --font <font>                                   Font to use for subtitles"
    exit 1
}

# parse command-line options
# ref: https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
if [ "$1" == "--help" ]; then
    help
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -u | --url)
            VIDEO_URL="$2"
            shift
            shift
            ;;
        -o | --output-path)
            OUTPUT_PATH="$2"
            shift
            shift
            ;;
        -b | --backend)
            case "$2" in
                "whisper-cpp" | "faster-whisper")
                    BACKEND="$2"
                    shift
                    shift
                    ;;
                *)
                    echo "Invalid value for -b. Use either 'whisper-cpp' or 'faster-whisper'." >&2
                    exit 1
                    ;;
            esac
            ;;
        -wbp | --whisper-bin-path)
            WHISPER_BIN_PATH="$2"
            shift
            shift
            ;;
        -ml | --max-length)
            MAX_LENGTH="$2"
            shift
            shift
            ;;
        -t | --threads)
            THREADS="$2"
            shift
            shift
            ;;
        -w | --workers)
            WORKERS="$2"
            shift
            shift
            ;;
        -m | --model)
            MODEL="$2"
            shift
            shift
            ;;
        -tf | --translate-from)
            TRANSLATE_FROM="$2"
            shift
            shift
            ;;
        -tt | --translate-to)
            TRANSLATE_TO="$2"
            shift
            shift
            ;;
        -f | --font)
            FONT="$2"
            shift
            shift
            ;;
    esac
done

echo -e "\033[33m========== Set Parameters ==========\033[0m"

if [ -z "$VIDEO_URL" ]; then
    echo "Using default YouTube video URL: $DEFAULT_VIDEO_URL"
    VIDEO_URL="$DEFAULT_VIDEO_URL"
    printf ">>> Otherwise, usage: %s [-u <youtube_video_url>]\n", "$0"
fi
if [ -z "$BACKEND" ]; then
    echo "Using default backend: $BACKEND"
    BACKEND="$DEFAULT_BACKEND"
    printf ">>> Otherwise, usage: %s -u <youtube_video_url> [-b <backend>]\n" "$0"
fi
if [ -z "$WHISPER_BIN_PATH" ]; then
    echo "Using default whisper_bin_path: $DEFAULT_WHISPER_BIN_PATH"
    WHISPER_BIN_PATH="$DEFAULT_WHISPER_BIN_PATH"
    printf ">>> Otherwise, usage: %s -u <youtube_video_url> [-b whisper-cpp] [-wbp <whisper_bin_path>]\n" "$0"
fi
if [ -z "$OUTPUT_PATH" ]; then
    echo "Using default output path: $DEFAULT_OUTPUT_PATH"
    OUTPUT_PATH="$DEFAULT_OUTPUT_PATH"
    printf ">>> Otherwise, usage: %s -u <youtube_video_url> [-o <output_path>]\n" "$0"
fi
if [ -z "$MODEL" ]; then
    echo "Using default model name: $DEFAULT_MODEL"
    MODEL="$DEFAULT_MODEL"
    printf ">>> Otherwise, usage: %s -u <youtube_video_url> [-m <model_name>]\n" "$0"
fi
if [ -z "$THREADS" ]; then
    echo "Using default number of threads: $DEFAULT_THREADS"
    THREADS="$DEFAULT_THREADS"
    printf ">>> Otherwise, usage: %s -u <youtube_video_url> [-t <threads>]\n" "$0"
fi
if [ -z "$WORKERS" ]; then
    echo "Using default number of workers: $DEFAULT_WORKERS"
    WORKERS="$DEFAULT_WORKERS"
    printf ">>> Otherwise, usage: %s -u <youtube_video_url> [-w <workers>]\n" "$0"
fi
if [ -z "$MAX_LENGTH" ]; then
    echo "Using default maximum length: $DEFAULT_MAX_LENGTH"
    MAX_LENGTH="$DEFAULT_MAX_LENGTH"
    printf ">>> Otherwise, usage: %s-u <youtube_video_url> [-ml <max_length>]\n" "$0"
fi
if [ -z "$WHISPER_BIN_PATH" ] && [ "$BACKEND" = "whisper-cpp" ]; then
    echo "Please set the WHISPER_BIN_PATH option to the path of the whisper-cpp binary."
    printf ">>> Usage: %s -u <youtube_video_url> -b whisper-cpp [-wbp <whisper_bin_path>]\n" "$0"
    exit 1
fi
if [ -z "$FONT" ]; then
    echo "Using default font: $DEFAULT_FONT"
    FONT="$DEFAULT_FONT"
    printf ">>> Otherwise, usage: %s -u <youtube_video_url> [-f <font>]\n" "$0"
fi

# invoke the functions with the provided YouTube video URL and output path
print_run_parameters
create_output_folder "$OUTPUT_PATH"
download_and_convert "$VIDEO_URL" "$OUTPUT_PATH"
generate_transcript "$BACKEND"
overlay_subtitles

echo -e "\033[32m Done! Your finished file is ready: $saved_dir/subbed.mp4\033[32m"
