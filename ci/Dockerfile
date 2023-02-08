FROM ubuntu:22.04
LABEL org.opencontainers.image.authors="p.tisserand@gmail.com"

# ## Configuration for local user if needed
# ARG USER=rob
# ARG USER_ID=1000
# ARG GROUP=starknet
# ARG GROUP_ID=1000
# 

RUN apt-get update
# Set the locale
RUN apt-get install -y locales && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8    

RUN apt-get install -yq tzdata && \
    ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata
RUN apt-get install -y software-properties-common

# nodejs 16.x is required by github actions
COPY ./setup_16.x /tmp
RUN bash /tmp/setup_16.x && \
    apt-get update && \
    apt-get install -y nodejs


RUN add-apt-repository -y ppa:deadsnakes/ppa
RUN apt-get install -y \
        build-essential \
        python3.9 \
        python3.9-venv \
        python3.9-dev \
        libgmp3-dev
# foundry dependencies
RUN apt-get install -y \
    git \
    zstd

# # Create new user
# RUN \
#     addgroup --gid ${GROUP_ID} ${GROUP} && \
#     adduser --uid ${USER_ID} --ingroup ${GROUP} --disabled-password --gecos "" ${USER}
# 
# USER ${USER}
# WORKDIR /home/${USER}
# RUN python3.9 -m venv venv
# ENV PATH /home/${USER}/venv/bin:$PATH
# RUN pip install --upgrade pip


