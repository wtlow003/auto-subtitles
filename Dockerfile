FROM ubuntu:22.04 as build

RUN useradd -ms /bin/bash builder
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    git \
    curl && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

RUN mkdir -p /whisper.cpp/
RUN chown -R builder /whisper.cpp
USER builder

RUN git clone https://github.com/ggerganov/whisper.cpp /whisper.cpp
WORKDIR /whisper.cpp

# download base and medium models
RUN ./models/download-ggml-model.sh base && \
    ./models/download-ggml-model.sh medium

# build binary
RUN make
# test binary
RUN ./main -m ./models/ggml-base.bin ./samples/jfk.wav

# FROM python:3.9.10-slim-buster as runtime
FROM ubuntu:22.04 AS runtime

WORKDIR /app
# copy artifacts from build stage
COPY --from=build /whisper.cpp/ ./whisper.cpp

RUN apt-get update && \
    apt-get install -y \
    ffmpeg \
    gcc \
    python3.9 \
    python3-pip && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*


# add new fonts from /fonts to /usr/local/share/fonts
COPY fonts /usr/local/share/fonts
# refresh font cache
RUN fc-cache -f -v

# install python dependencies
COPY requirements.txt .
RUN pip3 install --upgrade pip setuptools wheel
RUN pip3 install --no-cache-dir -r requirements.txt

# copy source code
COPY src ./src
COPY workflow.sh .

ENTRYPOINT [ "./workflow.sh" ]
