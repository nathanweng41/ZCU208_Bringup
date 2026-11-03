from pathlib import Path
import vitis


# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

ROOT = Path.cwd()

XSA_FILE = (
    ROOT
    / "hardware"
    / "zcu208_modulation_v6_adc_rrc_bypass.xsa"
)

SOURCE_DIR = ROOT / "src"

WORKSPACE = ROOT / "vitis_workspace"

PLATFORM_NAME = "zcu208_platform"
DOMAIN_NAME = "standalone_psu_cortexa53_0"
APP_NAME = "rfsoc_app"


# ------------------------------------------------------------
# Check inputs
# ------------------------------------------------------------

if not XSA_FILE.is_file():
    raise FileNotFoundError(f"XSA not found: {XSA_FILE}")

if not SOURCE_DIR.is_dir():
    raise FileNotFoundError(f"Source directory not found: {SOURCE_DIR}")

source_files = sorted(
    p.name
    for p in SOURCE_DIR.iterdir()
    if p.is_file() and p.suffix in {".c", ".h", ".s", ".S"}
)

if not any(name.endswith(".c") for name in source_files):
    raise RuntimeError(
        f"No .c files found in {SOURCE_DIR}. "
        "Copy your RFSoC application source files there first."
    )

# This is a first-time creation script.
# Do not overwrite components that already exist.
if (WORKSPACE / PLATFORM_NAME).exists():
    raise RuntimeError(
        f"Platform already exists in {WORKSPACE}. "
        "Use the rebuild script instead."
    )

if (WORKSPACE / APP_NAME).exists():
    raise RuntimeError(
        f"Application already exists in {WORKSPACE}. "
        "Use the rebuild script instead."
    )

print("\nXSA:")
print(XSA_FILE)

print("\nApplication source files:")
for name in source_files:
    print(f"  {name}")


# ------------------------------------------------------------
# Create Vitis client and workspace
# ------------------------------------------------------------

client = vitis.create_client()
client.set_workspace(path=str(WORKSPACE))


# ------------------------------------------------------------
# Create and build the standalone Cortex-A53 platform
# ------------------------------------------------------------

print("\nCreating ZCU208 platform...")

platform = client.create_platform_component(
    name=PLATFORM_NAME,
    hw_design=str(XSA_FILE),
    os="standalone",
    cpu="psu_cortexa53_0",
    domain_name=DOMAIN_NAME
)

print("\nBuilding platform and BSP...")
platform.build()


# Standard exported platform location.
platform_xpfm = (
    WORKSPACE
    / PLATFORM_NAME
    / "export"
    / PLATFORM_NAME
    / f"{PLATFORM_NAME}.xpfm"
)

if not platform_xpfm.is_file():
    raise FileNotFoundError(
        f"Platform XPFM not found at {platform_xpfm}. "
        "Check the platform build output above."
    )

print("\nPlatform generated:")
print(platform_xpfm)


# ------------------------------------------------------------
# Create application and import C files
# ------------------------------------------------------------

print("\nCreating RFSoC application component...")

app = client.create_app_component(
    name=APP_NAME,
    platform=str(platform_xpfm),
    domain=DOMAIN_NAME,
    template="empty"
)

print("\nImporting application source files...")

app.import_files(
    from_loc=str(SOURCE_DIR),
    files=source_files,
    dest_dir_in_cmp="src"
)


# ------------------------------------------------------------
# Compile and link the application into an ELF
# ------------------------------------------------------------

print("\nBuilding RFSoC application...")
app.build()

print("\nBuild command completed.")
print("Check the output above for errors.")
print("Look for the ELF under:")
print(WORKSPACE / APP_NAME / "build")