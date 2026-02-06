# data_run.py
# data collection runtime for the 
# Anomolous Behavior Profiling plugin
# written by Aaron Krapes
# Feb 5, 2026

# LEGAL DISCLAIMER ------------------------------------------------------
# THIS PROGRAM SNIFFS PACKETS FROM A SPECIFIED NETWORK INTERFACE
# DO NOT EVER RUN THIS PROGRAM GIVEN AN INTERFACE THAT HAS ACCESS TO A 
# NETWORK WHICH YOU DO NOT OWN OR HAVE LEGAL PERMISSION TO ADMINISTRATE
# -----------------------------------------------------------------------

# global variables
import sys
if len(sys.argv) > 2:
    HTTP_PORT_NUM = sys.argv[1]
    NET_IF = sys.argv[2]
else:
    sys.exit("provide HTTP server port number for pipeline input as arg")

# temporary debug output
print("DEBUG -- HTTP Port: " + HTTP_PORT_NUM + " || Type: {}".format(type(HTTP_PORT_NUM)))
print("DEBUG -- Network Interface: " + NET_IF + " || Type: {}".format(type(NET_IF)))

# imports
from scapy.all import sniff, Ether, IP, TCP, UDP
import json
import requests

# function to parse packets into the format that the Morpheus pipeline expects
# and send them to the HTTP Server input stage
def process_send(pkt):
    # initialize lists for storing packet data
    # helps us convert into a dict later
    field = ['timestamp', 'host_ip', 'data_len', 'data', 
            'src_mac', 'dest_mac', 'protocol', 'src_ip', 
            'dest_ip', 'src_port', 'dest_port', 'flags']
    data = ['', '', '', '', '', '', '', '', '', '', '', '']
    # manipulate payload for visual purposes
    payload = pkt.default_payload_class(pkt.load)
    print(payload)
    # add data from Ethernet and IP layers
    data = [int(pkt.time), pkt[IP].src, pkt[IP].len, 'tmp', 
            pkt[Ether].src, pkt[Ether].dst, pkt[IP].proto, 
            pkt[IP].src, pkt[IP].dst, pkt[IP].flags]
    # check what layers the packet has and add data accordingly
    if pkt.haslayer(TCP):
        data.insert(9, pkt[TCP].sport)
        data.insert(10, pkt[TCP].dport)
        data[11] = pkt[TCP].flags
    elif pkt.haslayer(UDP):
        data.insert(9, pkt[UDP].sport)
        data.insert(10, pkt[UDP].dport)
        
    # create dictionary and convert to json
    packet_data = dict(zip(field, data))
    print(packet_data)
    packet_json = json.dumps(packet_data) 
    # write json data to file for debugging purposes (for now)
    with open("test.json", "a") as f:
        f.write(packet_json)
    # send data to HTTP Server Stage

# start sniffing
if __name__ == "__main__":
    sniff(count=15, prn=process_send, iface='{}'.format(NET_IF), store=0)