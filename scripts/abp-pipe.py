# abp-pipe.py
# pipeline initializer and runtime for the
# Anomolous Behavior Profiling plugin
# written by Aaron Krapes
# Feb 12, 2026

MODEL_NAME = "abp-pcap-xgb"
TRITON_URL = "http://localhost:8000"
ELASTIC_CONF = '/etc/abeonasec/elasticsearch.yml'

# imports
import os
import logging
import socket

# NVIDIA preprocessing stage for model
from abp_pcap_preprocessing import AbpPcapPreprocessingStage

# morpheus config, logger and pipeline setup
from morpheus.config import Config
from morpheus.config import PipelineModes
from morpheus.utils.logger import configure_logging
from morpheus.pipeline.linear_pipeline import LinearPipeline

# morpheus pipeline stages
from morpheus.stages.input.http_server_source_stage import HttpServerSourceStage
from morpheus.stages.preprocess.deserialize_stage import DeserializeStage
from morpheus.stages.inference.triton_inference_stage import TritonInferenceStage
from morpheus.stages.postprocess.add_classifications_stage import AddClassificationsStage
from morpheus.stages.postprocess.serialize_stage import SerializeStage
from morpheus.stages.output.write_to_elasticsearch_stage import WriteToElasticsearchStage

# function to find free http port for the pipeline input
def find_free_port(start_port=8003):
    print("Looking for free port for pipeline input, starting at {}".format(start_port))
    port = start_port
    while True:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            if s.connect_ex(('localhost', port)) != 0:
                print("Found free port {}...".format(port))
                return port
            port += 1

# configure pipeline and stages
def run_pipeline():
    http_port = find_free_port(8003)

    # using default logging recommended by Morpheus
    configure_logging(log_level=logging.INFO)

    # create config and set to FIL mode
    config = Config()
    config.mode = PipelineModes.FIL

    # set pipeline config values to default
    config.num_threads = len(os.sched_getaffinity(0))
    config.pipeline_batch_size = 100000
    config.model_max_batch_size = 100000
    config.feature_length = 13
    # adds probability values in post-processing stage
    config.class_labels = ["probs"]

    # create pipeline object with config
    pipeline = LinearPipeline(config)

    # data will be sent from data_run.py runtime to HttpServerSourceStage
    pipeline.set_source(
        HttpServerSourceStage(config=config, port=http_port,))
    # pipeline.add_stage(DeserializeStage(config))

    # pcap preprocessing -- required formatting specific to this model
    # pipeline.add_stage(AbpPcapPreprocessingStage(config))

    # query triton server for model decision
    # pipeline.add_stage(TritonInferenceStage(config, model_name=MODEL_NAME, server_url=TRITON_URL))

    # add classifications to data before writing to elasticsearch
    # pipeline.add_stage(AddClassificationsStage(config, labels=["probs"]))
    # pipeline.add_stage(SerializeStage(config))

    # write data to elasticsearch
    pipeline.add_stage(
        WriteToElasticsearchStage(
            config=config,
            index='plugin-abp', # indexed by plugin name
            connection_conf_file=ELASTIC_CONF
        ))
    pipeline.run()

# run pipeline
if __name__ == "__main__":
    run_pipeline()