import os
import vitis

workspace = r"C:\rfsoc_cli\vitis_workspace"
xsa_file = r"C:\rfsoc_cli\hardware\system.xsa"

client = vitis.create_client()
client.set_workspace(path=workspace)

platform = client.create_platform_component(
    name="zcu208_platform",
    hw_design=xsa_file,
    os="standalone_psu_cortexa53_0",
    cpu="psu_cortexa53_0",
    domain_name="standalone_psu_cortexa53_0"
)

platform.build()

platform_xpfm = os.path.join(
    workspace,
    "zcu208_platform",
    "export",
    "zcu208_platform",
    "zcu208_platform.xpfm"
)

print("Platform expected at:", platform_xpfm)