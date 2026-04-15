# abp-data.py
# data collection runtime for the 
# Anomolous Behavior Profiling plugin
# specifically configured to run inside a container
# written by Aaron Krapes
# Mar 11, 2026

# LEGAL DISCLAIMER 
# --------------------------------------------------------------------------------
# THIS PROGRAM SNIFFS PACKETS FROM A SPECIFIED NETWORK INTERFACE

# DO NOT EVER RUN THIS PROGRAM GIVEN AN INTERFACE THAT HAS ACCESS TO A 
# NETWORK WHICH YOU DO NOT OWN OR HAVE LEGAL PERMISSION TO ADMINISTRATE

# THE DEVELOPERS OF ABEONASEC TAKE NO RESPONSIBILITY FOR MISUSE OF THE APPLICATION
# --------------------------------------------------------------------------------

import sys
if len(sys.argv) < 1:
    print("Usage: abp-data.py [if_name]")

# global variables
KAFKA_URL='localhost:9092'
KAFKA_TOPIC='pcap'
KAFKA_GROUP='plugin-abp'

# imports
import logging
logging.getLogger("scapy").setLevel(logging.WARNING) # set logger first

from scapy.all import sniff, Raw, Ether, IP, IPv6, TCP, UDP
from scapy.layers.http import *
from scapy.config import conf
import json

from kafka import KafkaProducer
from kafka.admin import KafkaAdminClient, NewTopic
from kafka.errors import TopicAlreadyExistsError

# function to create kafka topic
def create_topic():
    # setup kafka admin client and attempt to create topic
    admin = KafkaAdminClient(bootstrap_servers=[KAFKA_URL])
    topic_obj = NewTopic(name=KAFKA_TOPIC, num_partitions=3, replication_factor=1)
    try:
        admin.create_topics([topic_obj])
        print("[abp-data.py]: 'pcap' topic created")
    except TopicAlreadyExistsError:
        print("[abp-data.py]: 'pcap' topic already exists")
    finally:
        admin.close()

# globally initialize kafka producer, used by process_send() to send data to kafka
producer = KafkaProducer(
    bootstrap_servers=[KAFKA_URL],
    value_serializer=lambda v: v.encode('utf-8'),  # using UTF-8 encoded strings
    batch_size=16384,
    linger_ms=10,
    acks='all' # prioritizing durability of data over speed
)

# set scapy to use libpcap for compatibility
conf.use_pcap = True

# function to parse packets into the format that the Morpheus pipeline expects
# and send them to the kafka topic to be consumed into the pipeline
def process_send(pkt):
    # make sure packet contains IP information (L2) or is IPv6 (not useful with model)
    if not pkt.haslayer(IP) or pkt.haslayer(IPv6) or not pkt.haslayer(Raw):
        return
    # initialize lists for storing packet information
    # helps convert into a dict, then json later
    field = ['timestamp', 'host_ip', 'data_len', 'data', 
            'src_mac', 'dest_mac', 'protocol', 'src_ip', 
            'dest_ip', 'src_port', 'dest_port', 'flags']
    data = ['', '', '', '', '', '', '', '', '', '', '', '']

    # see if packet has an HTTP payload, otherwise leave empty
    # the model(s) being used only understand HTTP data and may produce
    # a false positive from other decoded payloads
    load = ''
    if pkt.haslayer(HTTPRequest) or pkt.haslayer(HTTPResponse):
        load = bytes(pkt[TCP].payload).decode('utf-8', errors='ignore')
        # split http data off of any gibberish (encoded payload)
        res = load.split('\r\n\r\n', 1)
        head = res[0] + '\r\n\r\n' if res else ''
        load = head

    # add data from Ethernet and IP layers
    data = [int(pkt.time), pkt[IP].src, pkt[IP].len, load, 
            pkt[Ether].src, pkt[Ether].dst, pkt[IP].proto, 
            pkt[IP].src, pkt[IP].dst, int(pkt[IP].flags)]
    # check what protocol layers the packet has and add data accordingly
    if pkt.haslayer(TCP):
        data.insert(9, pkt[TCP].sport)
        data.insert(10, pkt[TCP].dport)
        data[11] = int(pkt[TCP].flags)
    elif pkt.haslayer(UDP):
        data.insert(9, pkt[UDP].sport)
        data.insert(10, pkt[UDP].dport)

    # create dictionary and convert to json
    packet_data = dict(zip(field, data))
    packet_json = json.dumps(packet_data) 

    #print(packet_json)
    # send packet data to kafka topic
    producer.send(KAFKA_TOPIC, value=packet_json)

# start sniffing indefinitely
if __name__ == "__main__":
    print("[abp-data.py]: Creating kafka topic 'pcap'...")
    create_topic()
    print(f"[abp-data.py]: Starting sniff on {sys.argv[1]}...")
    sniff(count=0, prn=process_send, iface=sys.argv[1], store=0)
    print("[abp-data.py]: CRITICAL ERROR, EXITED")
