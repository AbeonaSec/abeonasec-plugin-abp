# plugin-abp.Dockerfile
# dockerfile to build a morpheus container
# and run the ABP AbeonaSec plugin
# written by Aaron Krapes
# Feb 10, 2026

FROM docker.io/library/python:3.12

# need to install iproute2 for ss command
RUN apt-get update -y && \
    apt-get install -y iproute2 && \
    rm -rf /var/lib/apt/lists/*

# copy scripts and run
WORKDIR /usr/src/app
COPY src/data_run.py ./
COPY src/requirements.txt ./
COPY src/start.sh ./

RUN pip install -r requirements.txt

CMD [ "bash", "chmod +x start.sh; ./start.sh" ]