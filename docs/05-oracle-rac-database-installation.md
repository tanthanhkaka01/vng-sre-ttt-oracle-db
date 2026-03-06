# 05 - Oracle RAC Database Installation

## Overview

This section describes the installation of **Oracle Database 21c software** and the creation of an **Oracle RAC database** using **DBCA (Database Configuration Assistant)**.

The database will be deployed across two RAC nodes:

```text
rac01
rac02
```

Key characteristics of this deployment:

- Oracle RAC (2 nodes)
- Container Database (CDB)
- One Pluggable Database (PDB)
- ASM storage (+DATA and +FRA)
- SCAN-based client connectivity