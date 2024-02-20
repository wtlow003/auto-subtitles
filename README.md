<h1 align="center">Auto-Subtitles</h1>

<p align="center">
    <a href=#about>About</a> •
    <a href=#features>Features</a> •
    <a href=#installation>Installation</a> •
    <a href=#usage>Usage</a>
</p>

## About

The **Auto-Subtitles** is a CLI tool that generates and embeds subtitles for any YouTube video automatically. Other core functionality includes the ability to generate translated transcripts prior to the output process.

### Why Should You Use It?

Prior to the advancement of automatic speech recognition (ASR), transcription process is often seen as a tedious manual task that requires meticulousness in understanding the given audio.

I studied and interned in the film and media industry prior to working as a Machine Learning/Platform Engineer. I was involved in several production that involves manually generating transcriptions and overlay subtitles via video editing software for various advertisements and commercials.

With OpenAI's [Whisper](https://github.com/openai/whisper) models garnering favourable interests from developers due to the ease of local processing and [high](https://www.speechly.com/blog/analyzing-open-ais-whisper-asr-models-word-error-rates-across-languages) accuracy in languages such as english, it soon became a viable drop-in (free) replacement for professional (paid) transcription services.

While far from perfect – **Auto-Subtitles** still provides automatically generated transcriptions from your local setup with ease of setting up and using from the get-go. The CLI tool can be a initial starting phase in the subtitling process by generating a first-draft of transcriptions that can be vetted and edited by the human before using the edited subtitles for the eventual output. This can reduce the time-intensive process of audio scrubbing and typing every single word from scratch.

## Features

### Supported Models

Currently, the auto-subtitles workflow supports the following variant(s) of the Whisper model:

1. [@ggerganov/whisper.cpp](https://github.com/ggerganov/whisper.cpp):
   - Provides the `whisper-cpp` backend for the workflow.
   - Port of OpenAI's Whisper model in C/C++. Generate fast transcription on local setup (esp. MacOS) via MPS.
2. [@jianfch/stable-ts](https://github.com/jianfch/stable-ts):
   - Provides the `faster-whisper` backend for the workflow, while producing more reliable and accurate timestamps for transcription
   - Functionalities also includes VAD filters to more accurately detect voice activities.

### Translation

In **Auto-Subtitles**, we also included the functionality to translate transcripts, e.g., `english (en)` to `chinese (zh)`, prior to embedding subtitles on the output video.

We did not opt to use the translation features directly via the Whisper model due to observed performance issue and hallucination in the generated transcript.

To support a more efficient and reliable translation process, we used Meta AI's group of models - [No Language Left Behind (NLLB)](https://ai.meta.com/research/no-language-left-behind/) for translation post-transcription via `whisper-cpp` or `faster-whisper`.

Currently, the following models are supported:

1. [facebook/nllb-200-1.3B](https://huggingface.co/facebook/nllb-200-1.3B)
2. [facebook/nllb-200-3.3B](https://huggingface.co/facebook/nllb-200-3.3B)
3. [facebook/nllb-200-distilled-600M](https://huggingface.co/facebook/nllb-200-distilled-600M)
4. [facebook/nllb-200-distilled-1.3B](https://huggingface.co/facebook/nllb-200-distilled-1.3B)

By default, the `facebook/nllb-200-distilled-600M` model is used.

## Installation

For this project, you can setup the requirements/dependencies and environment either locally or in a containerised environment with Docker.

### Local Setup

#### Pre-requisites

1. [ffmpeg](https://ffmpeg.org/download.html#build-mac)

Alternatively, referenced from [@openai/whisper](https://github.com/openai/whisper):

```shell
# on Ubuntu or Debian
sudo apt update && sudo apt install ffmpeg

# on Arch Linux
sudo pacman -S ffmpeg

# on MacOS using Homebrew (https://brew.sh/)
brew install ffmpeg

# on Windows using Chocolatey (https://chocolatey.org/)
choco install ffmpeg

# on Windows using Scoop (https://scoop.sh/)
scoop install ffmpeg
```

2. [yt-dlp](https://github.com/yt-dlp/yt-dlp)
3. [Python 3.9](https://www.python.org/downloads/)
4. [whisper.cpp](https://www.bing.com/search?q=whisper.cpp&cvid=c6357be7905a4543b299efb7b63bda65&gs_lcrp=EgZjaHJvbWUqBggAEEUYOzIGCAAQRRg7MgYIARBFGDsyBggCEEUYOTIGCAMQRRg8MgYIBBBFGDwyBggFEEUYPDIGCAYQRRhA0gEIMTE0OGowajSoAgCwAgA&FORM=ANAB01&PC=U531)

```shell
# build the binary for usage
git clone https://github.com/ggerganov/whisper.cpp.git

cd whisper.cpp
make
```

- Please refer to the actual [repo](https://github.com/ggerganov/whisper.cpp.git) for all other build arguments relevant to your local setup for better performance.

#### Python Dependencies (`faster-whisper`)

Install the dependencies in `requirements.txt` into a virtual environment (`virtualenv`):

```shell
python -m venv .venv

# mac-os
source .venv/bin/activate

# install dependencies
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt
```

### [WIP] Docker Setup

## Usage

To run the automatic subtitling process for the following [video](https://www.youtube.com/watch?v=fnvZJU5Fj3Q), simply run the following command (refer [here](#detailed-options) for advanced options):

```shell
chmod +x ./workflow.sh

/workflow.sh -u https://www.youtube.com/watch?v=fnvZJU5Fj3Q \
    -b faster-whisper \
    -t 8 \
    -m medium \
    -ml 47
```

The above command generate the **transcription** + **subtitling** workflow with the following settings:

1. Using the `faster-whisper` backend
   - More reliable and accurate timestamps as opposed to `whisper.cpp`, using `VAD` etc.
2. Running on `8` threads for increased performance
3. Using the [`openai/whisper-medium`](https://huggingface.co/openai/whisper-medium) multi-lingual model
4. Limit the maximum length of each transcription segment to max [`47`](https://www.capitalcaptions.com/services/subtitle-services-2/capital-captions-standard-subtitling-guidelines/) characters.

The following is the generated video:
<video src="https://github.com/wtlow003/auto-subtitles/blob/master/assets/ollama-transcribed.mp4"></video>

### Detailed Options

To check all the avaliable options, use the `--help` flag:

```shell
./workflow.sh --help

Usage: ./workflow.sh [-u <youtube_video_url>] [options]
Options:
  -u, --url <youtube_video_url>                       YouTube video URL
  -o, --output-path <output_path>                     Output path
  -b, --backend <backend>                             Backend to use: whisper-cpp or faster-whisper
  -wbp, --whisper-bin-path <whisper_bin_path>         Path to whisper-cpp binary. Required if using [--backend whisper-cpp].
  -ml, --max-length <max_length>                      Maximum length of the generated transcript
  -t, --threads <threads>                             Number of threads to use
  -w, --workers <workers>                             Number of workers to use
  -m, --model <model>                                 Model name to use
  -tf, --translate-from <translate_from>              Translate from language
  -tt, --translate-to <translate_to>                  Translate to language
```
