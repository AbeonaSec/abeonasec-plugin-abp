# pipe_run.py
# pipeline initializer and runtime for the
# Anomolous Behavior Profiling plugin
# written by Aaron Krapes
# Feb 5, 2026

# global variables
import sys
if len(sys.argv) > 1:
    HTTP_PORT_NUM = sys.argv[1]
else:
    sys.exit("provide HTTP server port number for pipeline input as arg")

MODEL_NAME = "abp-pcap-xgb"
TRITON_URL = "localhost:8000"

# temporary debug output
print("DEBUG -- HTTP Port: " + HTTP_PORT_NUM + " || Type: " + type(HTTP_PORT_NUM))

# imports
import os
import logging

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
from morpheus.stages.output.write_to_elasticsearch_stage.py import WriteToElasticsearchStage


# configure pipeline and stages
def run_pipeline():
    # using default logging
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
    pipeline.set_source(HttpServerSourceStage())
    pipeline.add_stage(DeserializeStage(config))

    # pcap preprocessing -- required formatting specific to this model
    pipeline.add_stage(AbpPcapPreprocessingStage(config))

    # query triton server for model decision
    pipeline.add_stage(TritonInferenceStage(config, model_name=MODEL_NAME, server_url=TRITON_URL))

    # add classifications to data before writing to elasticsearch
    pipeline.add_stage(AddClassificationsStage(config, labels=["probs"]))
    pipeline.add_stage(SerializeStage(config))

    # write data to elasticsearch
    pipeline.add_stage(WriteToElasticsearchStage())
    pipeline.run()

# run pipeline
if __name__ == "__main__":
    run_pipeline()