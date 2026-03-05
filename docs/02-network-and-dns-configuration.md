# 02 - Network and DNS Configuration

## Overview

This section describes the network and DNS configuration required for deploying the Oracle RAC and Data Guard architecture.

Proper network configuration is critical for cluster communication, application connectivity, and disaster recovery operations.

The network configuration includes:

- Hostname and IP address configuration
- Client access network
- Private interconnect network
- Management network
- DNS records for database connectivity
- SCAN (Single Client Access Name) configuration

---

## Network Interfaces

Each RAC node uses multiple network interfaces to separate different types of traffic.

| Network Type | Purpose |
|--------|--------|
| Client Access Network | Application database connections |
| Private Interconnect | RAC node communication and cache fusion |
| Management Network | System administration and monitoring |

The private interconnect network is dedicated to Oracle Clusterware communication and RAC cache fusion traffic.

Low latency and high bandwidth are recommended for this network.

---

## Network Layout

### Primary Datacenter

```text
Client Access Network   : 192.168.10.0/24
Private Interconnect    : 192.168.20.0/24
Management Network      : 192.168.30.0/24
```

### Disaster Recovery Datacenter

```text
Client Access Network   : 192.168.110.0/24
Private Interconnect    : 192.168.120.0/24
Management Network      : 192.168.130.0/24
```

The primary and DR networks are routed to allow communication between clusters for Data Guard replication.

---

## Hostname Configuration

Each node must have a unique hostname resolvable via DNS.

Example hostname configuration:

```text
Primary Datacenter:
rac-node1.company.local
rac-node2.company.local

Disaster Recovery Datacenter:
rac-node3.company.local
rac-node4.company.local
```

These hostnames resolve to the client access network IP addresses.

---

## Virtual IP (VIP) Configuration

Oracle RAC uses Virtual IP addresses to enable fast failover for client connections.

Each RAC node is assigned a VIP managed by Oracle Clusterware.

Example VIP configuration:
```text
rac-node1-vip.company.local   192.168.10.21
rac-node2-vip.company.local   192.168.10.22
```

If a node fails, its VIP automatically fails over to another node in the cluster.

This prevents client connection timeouts during node failures.

---

## SCAN Configuration

Oracle RAC uses SCAN (Single Client Access Name) to provide a single entry point for client connections.

Applications connect using a single SCAN hostname rather than individual node addresses.

Example SCAN hostname:
```text
scan-db.company.local
```

A SCAN name must resolve to three IP addresses.

Example DNS records:
```text
scan-db.company.local    192.168.10.101
scan-db.company.local    192.168.10.102
scan-db.company.local    192.168.10.103
```

Oracle Grid Infrastructure automatically manages SCAN listeners across cluster nodes.

Benefits of SCAN include:

- Simplified client configuration
- Automatic connection load balancing
- Transparent failover

---

## Database Service DNS Entry

Applications do not connect directly to the SCAN hostname.

Instead, a logical database endpoint is defined:
```text
db.company.local
```

DNS mapping:
```text
db.company.local → scan-db.company.local
```

This abstraction layer allows database failover without changing application connection strings.

When a disaster recovery failover occurs, the DNS mapping is updated to point to the DR cluster endpoint:

```text
db.company.local → dr-db.company.local
```

Example DR SCAN mapping:
```
dr-db.company.local → 192.168.110.101
dr-db.company.local → 192.168.110.102
dr-db.company.local → 192.168.110.103
```

Because the DNS record uses a short TTL value, applications will automatically reconnect to the DR database cluster after the DNS update.

---

## DNS TTL Configuration

The DNS entry for the database endpoint uses a short TTL value.

Example:

```text
db.company.local   TTL = 30 seconds
```

A low TTL ensures that applications refresh the database endpoint quickly during disaster recovery failover.

---

## DNS Example Records

Example DNS configuration:

```text
# Database endpoint
db.company.local    CNAME   scan-db.company.local

# SCAN records
scan-db.company.local       192.168.10.101
scan-db.company.local       192.168.10.102
scan-db.company.local       192.168.10.103

# RAC nodes
rac-node1.company.local     192.168.10.11
rac-node2.company.local     192.168.10.12

rac-node3.company.local     192.168.110.11
rac-node4.company.local     192.168.110.12
```

---

## Data Guard Connectivity

Oracle Data Guard requires network connectivity between the primary and standby clusters.

Redo transport occurs over the client access network.

Example communication flow:

```text
Primary RAC (192.168.10.x)
        ↓
Redo Transport
        ↓
Standby RAC (192.168.110.x)
```

Reliable network connectivity between datacenters is required to maintain synchronous replication.

---

## Network Best Practices

Recommended best practices for Oracle RAC networking include:

- Use dedicated private interconnect networks
- Ensure low latency between RAC nodes
- Use redundant network paths
- Configure DNS correctly before installing Oracle Grid Infrastructure
- Avoid using /etc/hosts for SCAN resolution

---

## Network Summary

```text
Primary Datacenter

rac-node1   192.168.10.11
rac-node2   192.168.10.12

SCAN IPs
192.168.10.101
192.168.10.102
192.168.10.103


DR Datacenter

rac-node3   192.168.110.11
rac-node4   192.168.110.12

SCAN IPs DR
192.168.110.101
192.168.110.102
192.168.110.103
```

Applications connect to the database using:

```text
db.company.local
```

Oracle RAC handles connection routing internally through SCAN listeners.

---

## Cluster Interconnect Configuration

Oracle RAC relies heavily on the private interconnect network for
Cache Fusion traffic between instances.

Requirements:

- Low latency network (< 1 ms recommended)
- High bandwidth (10 GbE recommended for production)
- Dedicated network interface
- Redundant network path if possible

Oracle Clusterware automatically detects the interconnect interface
during Grid Infrastructure installation.

---

## DNS Verification

Before installing Oracle Grid Infrastructure, verify that all hostnames
and SCAN records resolve correctly from every RAC node.

Example verification commands:

```bash
nslookup rac-node1.company.local
nslookup rac-node2.company.local

nslookup scan-db.company.local
```

Expected result:

```text
Name: scan-db.company.local
Address: 192.168.10.101
Address: 192.168.10.102
Address: 192.168.10.103
```

You can also verify using:

```bash
dig scan-db.company.local
```

All RAC nodes must be able to resolve these records correctly.

---

## Next Steps

After completing the network and DNS configuration, the next step is to configure shared storage and ASM disks for Oracle RAC.

See:
```text
03-shared-storage-and-asm-disks.md
```