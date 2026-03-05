# 04 - Oracle Grid Infrastructure Installation

## Overview

This section describes the installation and configuration of Oracle Grid Infrastructure 21c for the Oracle RAC environment.

Oracle Grid Infrastructure provides the core cluster components required to support Oracle RAC, including:

- Oracle Clusterware for cluster management and node coordination
- Oracle ASM (Automatic Storage Management) for shared storage management
- SCAN listeners for client connectivity
- Cluster health monitoring and failover management

Grid Infrastructure must be installed before Oracle Database software, as it provides the cluster and storage foundation required for RAC.

---

## Architecture Components

Oracle Grid Infrastructure includes the following major components:

| Component          | Description                                               |
| ------------------ | --------------------------------------------------------- |
| Oracle Clusterware | Manages cluster membership, node monitoring, and failover |
| Oracle ASM         | Manages shared storage for database files                 |
| SCAN Listener      | Provides load-balanced database connection endpoint       |
| ASM Disk Groups    | Logical storage groups used by Oracle Database            |

In this architecture:

```text
Application
     |
 Load Balancer / DNS
     |
     SCAN
     |
+------------+      +------------+
| RAC Node 1 | <--> | RAC Node 2 |
+------------+      +------------+
       \              /
        \            /
         \          /
        Shared ASM Storage
```

## Installation Prerequisites

Before installing Oracle Grid Infrastructure, ensure the following prerequisites are completed.

### OS Configuration

Each RAC node must be configured with:

- Oracle Linux / RedHat compatible OS
- Required kernel parameters
- Required OS packages
- Oracle Grid Infrastructure user and groups

Example users and groups: