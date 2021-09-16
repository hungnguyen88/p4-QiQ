# Implementing Basic QiQ

## Introduction

The objective of this exercise is to write a P4 program that
implements basic QiQ.

Your switch will have tables, which the control plane will
populate with static rules. Each rule will map an IP address to the
MAC address and output port for the next hop. We have already defined
the control plane rules, so you only need to implement the data plane
logic of your P4 program.

We will use the following topology for this exercise. It is a single
pod of a fat-tree topology and henceforth referred to as pod-topo:
![triangle-topo](./triangle-topo/qiq-network-simulation.png)

Our P4 program will be written for the V1Model architecture implemented
on P4.org's bmv2 software switch. The architecture file for the V1Model
can be found at: /usr/local/share/p4c/p4include/v1model.p4. This file
desribes the interfaces of the P4 programmable elements in the architecture,
the supported externs, as well as the architecture's standard metadata
fields. We encourage you to take a look at it.

## Step 1: Run the (incomplete) starter code

The directory with this README also contains a skeleton P4 program,
`basic.p4`, which initially drops all packets. Your job will be to
extend this skeleton program to properly forward IPv4 packets.

Before that, let's compile the incomplete `basic.p4` and bring
up a switch in Mininet to test its behavior.

1. In your shell, run:
   ```bash
   make run
   ```
   This will:
   * compile `basic.p4`, and
   * start the triangle-topo in Mininet and configure all switches with
   the appropriate P4 program + table entries, and
   * configure all hosts with the commands listed in
   [triangle-topo/topology.json](./triangle-topo/topology.json)

2. You should now see a Mininet command prompt. Then you can open terminal of Hosts h1, h2, h3, h4, h5, h6
   ```bash
   mininet> xterm h1 h2 h3 h4 h5 h6
   ```
3. Type `exit` to leave each xterm and the Mininet command line.
   Then, to stop mininet:
   ```bash
   make stop
   ```
   And to delete all pcaps, build files, and logs:
   ```bash
   make clean
   ```
   
**A note about the control plane**

A P4 program defines a packet-processing pipeline, but the rules within each table are inserted by the control plane. When a rule matches a packet, its action is invoked with parameters supplied by the control plane as part of the rule.

## Step 2: Test Standard QiQ - Enable H2 send message to H5

![triangle-topo](./triangle-topo/Standard-QiQ-Enable-H2-send-message-to-H5.png)

Use the cmd to show all messages sent to H5:
   ```bash
   h5> ./receive.py
   ```
Use the cmd to send a message from H2 to H5:  
   ```bash
   h2> ./send_vlan.py 0.0.0.0 08:00:00:00:05:55 "H2 Hello H5"
   ```
H5 will receive a packet sent from H2 with the payload "H2 Hello H5"

In the test, 

## Step 3: Test Standard QiQ - Enable H6 send message to H1

![triangle-topo](./triangle-topo/Standard-QiQ-Enable-H6-send-message-to-H1.png)

Use the cmd to show all messages sent to H1:
   ```bash
   h1> ./receive.py
   ```
Use the cmd to send a message from H6 to H1:
   ```bash
   h6> ./send_vlan.py 0.0.0.0 08:00:00:00:01:11 "H6 Hello H1"
   ```
H1 will receive a packet sent from H6 with the payload "H6 Hello H1"


## Step 4: Test **Selective QiQ - S1 and S2 forward all packets, received from H6, to H7**

![triangle-topo](./triangle-topo/Selective-QiQ-S1-and-S2-forward-all-packets-received-from-H4-to-H7.png)

Use the cmd to show all messages sent to H6 and H7:
   ```bash
   h6> ./receive.py
   ```
   ```bash
   h7> ./receive.py
   ```
Use the cmd to send a message from H4 to H6, but the packet will be forwarded to H7 by S2  
   ```bash
   h4> ./send_vlan.py 0.0.0.0 08:00:00:00:06:66 "H4 Hello H6"
   ```
H7 will receive a packet sent from H4 with the payload "H4 Hello H6"

In the test, 

#### Cleaning up Mininet

In the latter two cases above, `make run` may leave a Mininet instance
running in the background. Use the following command to clean up
these instances:

```bash
make stop
```

