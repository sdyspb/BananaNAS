# BananaNAS

Репозиторий содержит Device Tree overlay и скрипты кастомизации для сборки образа Armbian под портативное NAS-устройство BananaNAS.

BananaNAS построен на основе BananaPi BPI-M7 / Armsom Sige7 (Rockchip RK3588), оснащён двумя M.2 NVMe, двумя портами 2.5GbE и поддерживает OMV.

Device Tree Overlay `armsom-sige7-pcie-split.dts` обеспечивает работу двух дисков NVMe (разделение 4 линий PCIe на 2x2).

## Описание файлов

| Файл | Назначение |
| :--- | :--- |
| `armsom-sige7-pcie-split.dts` | Разделяет 4 линии PCIe 3.0 на два порта по 2 линии для двух NVMe. |
| `customize-image.sh` | Скрипт кастомизации, копирует overlay в сборку Armbian. |

## Использование со сборочной системой Armbian

Разместите файлы в `userpatches/`:

```bash
userpatches/
├── customize-image.sh
└── overlay/
    ├── armsom-sige7-pcie-split.dts
```

## Сборка образа
```bash
./compile.sh build BOARD=bananapim7 BRANCH=vendor BUILD_DESKTOP=no BUILD_MINIMAL=no KERNEL_CONFIGURE=no RELEASE=trixie
```
## Сборка образа с Openvediavault (OMV)

Сохраните omv.sh в userpatches/extensions/ и выполните:
```bash
./compile.sh build BOARD=bananapim7 BRANCH=vendor BUILD_DESKTOP=no BUILD_MINIMAL=no KERNEL_CONFIGURE=no RELEASE=trixie ENABLE_EXTENSIONS=omv
```

## Лицензия
GPL-2.0 (в соответствии с Armbian). Базовые исходные файлы DTS — из ядра Linux и проектов armsom-sige7 / bpi-m7
