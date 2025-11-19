# FirmwareCI

For detailed information on FirmwareCI, please refer to the [official documentation](https://docs.firmware-ci.com/).

## Directory Structure

The **`.firmwareci`** directory holds all configurations related to FirmwareCI. While directory names can be customized, the following mandatory directories must be present:

### **`workflows/`**

Each directory inside **`workflows`** encompasses all configurations related to a specific workflow, with its primary configuration located in the **`workflow.yaml`** file. An example test is provided within the **`tests`** subdirectory. The **`tests`** subdirectory must always be present.

### **`duts/`**

The **`duts`** directory contains configurations for DUTs (Devices Under Test). Each DUT directory includes its configuration file (**`dut.yaml`**), along with example pre-stage (**`pre.yaml`**) and post-stage (**`post.yaml`**) files.

### **`storage/`**

The **`storage`** directory contains potential storage items used in tests.
