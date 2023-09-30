FROM python:3.10.6-alpine

USER root

ARG GOLANG_VERSION=1.20.7

ENV OPENTOFU_GIT_SOURCE_URL=https://github.com/opentofu/opentofu.git
ENV OPENTOFU_INSTALL_DIR=/opt/opentofu
ENV OPENTOFU_TEMP_INSTALL_DIR=/tmp/compile_opentofu

ENV PYTHONUNBUFFERED=1 \
    # prevents python creating .pyc files
    PYTHONDONTWRITEBYTECODE=1 \
    \
    # pip
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    \
    # poetry
    # https://python-poetry.org/docs/configuration/#using-environment-variables
    # make poetry install to this location
    POETRY_HOME="/opt/poetry" \
    # make poetry create the virtual environment in the project's root
    # do not ask any interactive question
    POETRY_NO_INTERACTION=1 
    # paths
    # this is where our requirements + virtual environment will live
    #PYSETUP_PATH="/opt/pysetup" \
    #VENV_PATH="/opt/pysetup/.venv"
# prepend poetry and venv to path
ENV PATH="$POETRY_HOME/bin:$VENV_PATH/bin:$PATH"


RUN apk update && apk add \
    bash \
    openssh \ 
    make \ 
    git \
    alpine-sdk \
    curl \
    gcc \
    musl-dev \ 
    python3-dev \ 
    libffi-dev \
    openssl-dev \
    cargo \
    go \
    sqlite-dev \
    gcc \
    musl-dev \
    ca-certificates \
    && update-ca-certificates

# Compile GO from source 
RUN wget https://dl.google.com/go/go$GOLANG_VERSION.src.tar.gz && tar -C /usr/local -xzf go$GOLANG_VERSION.src.tar.gz
RUN cd /usr/local/go/src && ./make.bash
ENV PATH=$PATH:/usr/local/go/bin
RUN rm go$GOLANG_VERSION.src.tar.gz

# Delete old versions of GO
RUN apk del go
RUN go version

# Install OpenTOFU
RUN mkdir -p ${OPENTOFU_TEMP_INSTALL_DIR}
RUN mkdir -p ${OPENTOFU_INSTALL_DIR}
WORKDIR ${OPENTOFU_TEMP_INSTALL_DIR}
RUN git clone ${OPENTOFU_GIT_SOURCE_URL}
WORKDIR ${OPENTOFU_TEMP_INSTALL_DIR}/opentofu
ENV CGO_ENABLED=0
RUN go build -ldflags "-w -s -X 'github.com/opentofu/opentofu/version.dev=no'" -o bin/ ./cmd/tofu
RUN cp bin/tofu ${OPENTOFU_INSTALL_DIR}/opentofu
WORKDIR /root/
RUN rm -r ${OPENTOFU_TEMP_INSTALL_DIR}
ENV PATH /opt/opentofu:$PATH

# Install poetry
RUN curl -sSL --insecure https://install.python-poetry.org | python3 -

COPY ./entrypoint.sh /root/entrypoint.sh
RUN chmod +x /root/entrypoint.sh
RUN mkdir /opt/deployer

COPY src /root/src
RUN chown root:root -R /root/src
# Solve dependencies
#RUN poetry config experimental.new-installer false
RUN cd /root/src; poetry install

ENTRYPOINT /root/entrypoint.sh