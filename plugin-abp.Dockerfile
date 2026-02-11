# plugin-abp.Dockerfile
# dockerfile to build a morpheus container
# and run the ABP AbeonaSec plugin
# written by Aaron Krapes
# Feb 10, 2026

FROM docker.io/library/python:3.12

# need to install iproute2 for ss command
RUN apt-get update -y && \
    apt-get install -y netcat-openbsd libpcap-dev iproute2 && \
    rm -rf /var/lib/apt/lists/*

# copy scripts and run
WORKDIR /usr/src/app
COPY src/data_run.py ./
COPY src/requirements.txt ./
COPY src/start.sh ./

RUN pip install -r requirements.txt
RUN chmod +x start.sh 

# need python to be unbuffered for logging inside the script
ENV PYTHONUNBUFFERED=1

CMD [ "bash", "/usr/src/app/start.sh" ]