# data_run.py
# data collection runtime for the 
# Anomolous Behavior Profiling plugin
# specifically configured to run inside a container
# written by Aaron Krapes
# Feb 10, 2026

# LEGAL DISCLAIMER 
# -----------------------------------------------------------------------
# THIS PROGRAM SNIFFS PACKETS FROM A SPECIFIED NETWORK INTERFACE
#
# DO NOT EVER RUN THIS PROGRAM GIVEN AN INTERFACE THAT HAS ACCESS TO A 
# NETWORK WHICH YOU DO NOT OWN OR HAVE LEGAL PERMISSION TO ADMINISTRATE
# -----------------------------------------------------------------------

# global variables
import sys
if len(sys.argv) > 1:
    PIPE_PORT_NUM = sys.argv[1]
else:
    sys.exit("usage: python3 data_run.py [Morpheus pipeline HTTP port]")

# imports
from scapy.all import sniff, Raw, Ether, IP, IPv6, TCP, UDP
from scapy.config import conf
import json
import requests

# set scapy to use libpcap for compatibility
conf.use_pcap = True

# function to parse packets into the format that the Morpheus pipeline expects
# and send them to the HTTP Server input stage
def process_send(pkt):
    # make sure packet contains IP information (L2) or is IPv6 (not useful with model)
    if not pkt.haslayer(IP) or pkt.haslayer(IPv6):
        return 0
    # initialize lists for storing packet information
    # helps convert into a dict, then json later
    field = ['timestamp', 'host_ip', 'data_len', 'data', 
            'src_mac', 'dest_mac', 'protocol', 'src_ip', 
            'dest_ip', 'src_port', 'dest_port', 'flags']
    data = ['', '', '', '', '', '', '', '', '', '', '', '']

    # see if packet has payload
    load = ''
    if pkt.haslayer(Raw):
        load = bytes(pkt[Raw].payload).decode('ascii', errors='backslashreplace')

    # add data from Ethernet and IP layers
    data = [int(pkt.time), pkt[IP].src, pkt[IP].len, load, 
            pkt[Ether].src, pkt[Ether].dst, pkt[IP].proto, 
            pkt[IP].src, pkt[IP].dst, int(pkt[IP].flags)]
    # check what protocol layers the packet has and add data accordingly
    if pkt.haslayer(TCP):
        data.insert(9, pkt[TCP].sport)
        data.insert(10, pkt[TCP].dport)
        data[11] = int(pkt[TCP].flags)
        data[3] = bytes(pkt[TCP].payload).decode('ascii', errors='backslashreplace')
    elif pkt.haslayer(UDP):
        data.insert(9, pkt[UDP].sport)
        data.insert(10, pkt[UDP].dport)
        data[3] = bytes(pkt[UDP].payload).decode('ascii', errors='backslashreplace')

    # create dictionary and convert to json
    packet_data = dict(zip(field, data))
    packet_json = json.dumps(packet_data) 

    # send data to HTTP Server Stage in Morpheus pipeline
    requests.post('http://localhost:{}/message'.format(PIPE_PORT_NUM), json=packet_json)

# start sniffing indefinitely
if __name__ == "__main__":
    sniff(count=0, prn=process_send, iface='eth0', store=0)