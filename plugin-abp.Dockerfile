# using miniconda3 image as base
FROM continuumio/miniconda3

# set working directory and copy scripts into container
WORKDIR /app
COPY scripts/. .

# run commands to setup morpheus environment
ENV CONDA_ENV_NAME=morpheus
RUN conda create -n ${CONDA_ENV_NAME} python=3.12 && conda activate ${CONDA_ENV_NAME}
RUN conda config --env --add channels conda-forge &&\
  conda config --env --add channels nvidia &&\
  conda config --env --add channels rapidsai &&\
  conda config --env --add channels pytorch
RUN conda install -c nvidia morpheus-core=25.06
RUN MORPHEUS_CORE_PKG_DIR=$(dirname $(python -c "import morpheus; print(morpheus.__file__)"))
RUN pip install -r ${MORPHEUS_DFP_PKG_DIR}/requirements_morpheus_dfp_arch-$(arch).txt

# install dependencies for plugin code
RUN pip install -r requirements.txt

# get args to use when starting scripts
ARG PIPE_IN_PORT
ARG NET_IF
ENV PIPE_IN_PORT=$PIPE_IN_PORT
ENV NET_IF=$NET_IF

# start pipeline script
RUN chmod +x data_run.py pipe_run.py
RUN conda run -n ${CONDA_ENV_NAME} python pipe_run.py ${PIPE_IN_PORT}

# check if pipeline input port was opened (otherwise sniffing script will fail)
CMD ["bash", "-c", "
TIMEOUT=60;
START_TIME=$SECONDS;
until ss -tulpn | grep -q ":$PORT" 2>/dev/null; do;
    if [ $(( SECONDS - START_TIME )) -ge $TIMEOUT ]; then;
        echo "CRITICAL: Morpheus pipeline has not started after 60 seconds.";
        echo "Ensure pipe_run.py is started and the Morpheus HTTP Server is listening on $PORT.";
        kill -s SIGTERM 1;
    fi;
    sleep 0.5;
done;
"]

# start sniffing script
RUN ./data_run.py ${PIPE_IN_PORT} ${NET_IF}
RUN echo "Setup Complete!\nStarted sniffing on ${NET_IF}"