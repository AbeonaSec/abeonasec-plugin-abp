# abp-pipe.py
# pipeline initializer and runtime for the
# Anomolous Behavior Profiling plugin
# written by Aaron Krapes
# Mar 11, 2026

MODEL_NAME = "abp-pcap-xgb"
# using container name (podman dns)
TRITON_URL = "http://triton:8000"
KAFKA_URL = "kafka:9092"
ELASTIC_CONF = "/etc/abeonasec/es-client.yml"
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
from morpheus.stages.input.kafka_source_stage import KafkaSourceStage
from morpheus.stages.preprocess.deserialize_stage import DeserializeStage
from morpheus.stages.inference.triton_inference_stage import TritonInferenceStage
from morpheus.stages.postprocess.add_classifications_stage import AddClassificationsStage
from morpheus.stages.postprocess.serialize_stage import SerializeStage
from morpheus.stages.output.write_to_elasticsearch_stage import WriteToElasticsearchStage
from morpheus.stages.general.monitor_stage import MonitorStage

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

    # data will be sent from data_run.py runtime to a Kafka topic
    # in this case it will be 'pcap'
    pipeline.set_source(KafkaSourceStage(
        config=config,
        bootstrap_servers=KAFKA_URL,
        input_topic='pcap',
        group_id='plugin-abp'
    ))
    pipeline.add_stage(DeserializeStage(config))

    # pcap preprocessing -- required formatting specific to this model
    pipeline.add_stage(AbpPcapPreprocessingStage(config))
    pipeline.add_stage(MonitorStage(config, description="Input rate"))

    # query triton server for model decision
    pipeline.add_stage(TritonInferenceStage(config, model_name=MODEL_NAME, server_url=TRITON_URL))
    pipeline.add_stage(MonitorStage(config, description="Inference rate", unit="inf"))

    # add classifications to data before writing to elasticsearch
    pipeline.add_stage(AddClassificationsStage(config, labels=["probs"]))
    pipeline.add_stage(SerializeStage(config))

    # write data to elasticsearch
    pipeline.add_stage(
        WriteToElasticsearchStage(
            config=config,
            index='plugin-abp', # indexed by plugin name
            connection_conf_file=ELASTIC_CONF
        ))
    pipeline.add_stage(MonitorStage(config, description="Output rate", unit="to-elasticsearch"))
    pipeline.run()

# run pipeline
if __name__ == "__main__":
    run_pipeline()
