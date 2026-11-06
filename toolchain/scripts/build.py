from pathlib import Path
import shutil
import vitis


# ------------------------------------------------------------
# Paths and component names -- CHANGE THIS between each runs
# ------------------------------------------------------------

# Run this script from the project root, containing hardware/ and src/.
ROOT = Path.cwd()

XSA_FILE = (
    ROOT
    / "hardware"
    / "zcu208_modulation_v6_adc_rrc_bypass.xsa"
)

SOURCE_DIR = ROOT / "src"
WORKSPACE = Path(r"C:\Xilinx\vitis_workspace")

PLATFORM_NAME = "zcu208_platform"
DOMAIN_NAME = "standalone_psu_cortexa53_0"
APP_NAME = "rfsoc_app"

PLATFORM_DIR = WORKSPACE / PLATFORM_NAME
APP_DIR = WORKSPACE / APP_NAME

PLATFORM_XPFM = (
    PLATFORM_DIR
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
    raise RuntimeError(f"No .c files found in {SOURCE_DIR}")

print("\nSource files:")
for name in source_files:
    print(f"  {name}")


# ------------------------------------------------------------
# Create Vitis client
# ------------------------------------------------------------

client = vitis.create_client()

try:
    client.set_workspace(path=str(WORKSPACE))

    # --------------------------------------------------------
    # Reuse the platform, or build it if needed
    # --------------------------------------------------------

    if PLATFORM_XPFM.is_file():
        print(f"\nUsing existing platform: {PLATFORM_XPFM}")

    else:
        if PLATFORM_DIR.exists():
            print("\nBuilding existing platform...")
            platform = client.get_component(name=PLATFORM_NAME)

            if platform is None:
                raise RuntimeError(
                    f"Vitis could not open the existing platform: {PLATFORM_DIR}"
                )

        else:
            print("\nCreating platform...")
            platform = client.create_platform_component(
                name=PLATFORM_NAME,
                hw_design=str(XSA_FILE),
                os="standalone",
                cpu="psu_cortexa53_0",
                domain_name=DOMAIN_NAME,
            )

        platform.build()

        if not PLATFORM_XPFM.is_file():
            raise FileNotFoundError(
                f"Platform build did not produce: {PLATFORM_XPFM}"
            )

    # --------------------------------------------------------
    # Remove the old app, if present
    # --------------------------------------------------------

    if APP_DIR.is_symlink():
        raise RuntimeError(
            f"Refusing to delete a symlinked app directory: {APP_DIR}"
        )

    if APP_DIR.exists():
        print(f"\nRemoving old application: {APP_NAME}")

        try:
            client.delete_component(name=APP_NAME)

        except Exception as exc:
            message = str(exc).lower()

            missing_markers = (
                "not found",
                "not_found",
                "does not exist",
                "doesn't exist",
                "no such component",
                "could not find",
                "cannot find",
            )

            # A failed earlier creation can leave a directory without
            # a registered Vitis component.
            is_missing_component = (
                ("component" in message or APP_NAME.lower() in message)
                and any(marker in message for marker in missing_markers)
            )

            if not is_missing_component:
                raise RuntimeError(
                    f"Could not remove the old {APP_NAME} component"
                ) from exc

            print(
                "No registered app was found; "
                "removing the leftover directory."
            )

        # Vitis may already have removed the folder.
        if APP_DIR.exists():
            if not APP_DIR.is_dir():
                raise RuntimeError(
                    f"Expected an application directory: {APP_DIR}"
                )

            shutil.rmtree(APP_DIR)

    # --------------------------------------------------------
    # Create a fresh app with the same name
    # --------------------------------------------------------

    print(f"\nCreating fresh application: {APP_NAME}")

    app = client.create_app_component(
        name=APP_NAME,
        platform=str(PLATFORM_XPFM),
        domain=DOMAIN_NAME,
        template="empty_application",
    )

    print("\nImporting application sources...")

    app.import_files(
        from_loc=str(SOURCE_DIR),
        files=source_files,
        dest_dir_in_cmp="src",
    )

    # --------------------------------------------------------
    # Build and locate the ELF
    # --------------------------------------------------------

    print("\nBuilding application...")
    app.build()

    elf_files = sorted(
        path for path in APP_DIR.rglob("*.elf")
        if path.is_file()
    )

    if not elf_files:
        raise RuntimeError(
            f"No ELF found under {APP_DIR}. "
            "Check the Vitis build output above."
        )

    print("\nELF file(s):")
    for elf in elf_files:
        print(f"  {elf}")

finally:
    vitis.dispose()