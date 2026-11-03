from pathlib import Path
from datetime import datetime
import filecmp
import shutil
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

# True: clean the previous application build before compiling
# False: use Vitis's incrmemental build
CLEAN_BEFORE_BUILD = True

platform_dir = WORKSPACE / PLATFORM_NAME

platform_xpfm = (
    platform_dir
    / "export"
    / PLATFORM_NAME
    / f"{PLATFORM_NAME}.xpfm"
)

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

print("\nProject root:")
print(ROOT)

print("\nXSA:")
print(XSA_FILE)

print("\nApplication source files:")
for name in source_files:
    print(f"  {name}")


# ------------------------------------------------------------
# Create Vitis client and workspace
# ------------------------------------------------------------

client = vitis.create_client()

try:
    client.set_workspace(path=str(WORKSPACE))

    if platform_xpfm.is_file():
        print("\nReusing existing platform: ")
        print(platform_xpfm)

        print("Make sure this platform was generated from the current XSA.")
    else:
        if platform_dir.exists():
            # The platform component exists, but the exported
            # XPFM is missing. Try building the component.
            print(
                "\nPlatform component exists, but its XPFM "
                "was not found. Rebuilding the platform..."
            )

            platform = client.get_component(name=PLATFORM_NAME)

            if platform is None:
                raise RuntimeError(
                    f"Vitis could not load the existing platform: "
                    f"{platform_dir}"
                )
            
        else:
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

        if not platform_xpfm.is_file():
            raise FileNotFoundError(
                "The platform build did not produce the expected "
                f"XPFM:\n{platform_xpfm}\n"
                "Check the platform build output above."
            )

        print("\nPlatform generated:")
        print(platform_xpfm)

# ------------------------------------------------------------
# Create application and import C files
# ------------------------------------------------------------

app = None
active_app_name = None

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