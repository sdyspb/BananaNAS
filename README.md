# BananaNAS

<img width="1280" height="960" alt="banananas" src="https://github.com/user-attachments/assets/29021e5f-8cc1-4892-ad87-e729fcdb4003" />


This repository contains an overlay and customization scripts for building an Armbian image for the portable NAS - BananaNAS based on RK3588 single-board computer. It features two M.2 NVMe slots, two 2.5GbE ports, and supports OMV.

The Device Tree Overlay `armsom-sige7-pcie-split.dts` enables two NVMe drives (splits 4 PCIe lanes into 2x2).

## File descriptions

| File | Description |
| :--- | :--- |
| `armsom-sige7-pcie-split.dts` | Splits 4 PCIe 3.0 lanes into two 2-lane ports for two NVMe drives. |
| `customize-image.sh` | Customization script that copies the overlay into the Armbian build. |

## Usage with the Armbian build system

Place the files in `userpatches/`:

```bash
userpatches/
├── customize-image.sh
└── overlay/
    ├── armsom-sige7-pcie-split.dts
```
## Build examples

### Server
```bash
./compile.sh build BOARD=bananapim7 BRANCH=vendor BUILD_DESKTOP=no BUILD_MINIMAL=no KERNEL_CONFIGURE=no RELEASE=trixie
```
### Server + OMV

- place omv extension to /extensions
- add ENABLE_EXTENSIONS=omv to directive and run:

```bash
./compile.sh build BOARD=bananapim7 BRANCH=vendor BUILD_DESKTOP=no BUILD_MINIMAL=no KERNEL_CONFIGURE=no RELEASE=trixie ENABLE_EXTENSIONS=omv
```

## Resources
https://pixelnas.com/

## License
GPL-2.0 (in accordance with Armbian). Base DTS source files are from the Linux kernel and the [armsom-sige7](https://www.armsom.org/sige7) project.
