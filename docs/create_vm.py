import requests
import os

def int_or_default(message: str, default: int) -> int:
  res = input("{} ({}): ".format(message, default))
  if (res == ""):
    return default
  else:
    return int(res)

def string_or_default(message: str, default: str) -> str:
  res = input("{} ({}): ".format(message, default))
  if (res == ""):
    return default
  else:
    return res

def string_until_some(message: str) -> str:
  done = False
  while (not done):
    res = input("{}: ".format(message))
    done = not (res == "")
  return res

def bool_or_default(message: str, default: bool) -> bool:
  if default:
    def_msg = "Y/n"
  else:
    def_msg = "y/N"
  res = str(input("{} ({}): ".format(message, def_msg))).lower()
  if (res == ""):
    return default
  else:
    return res == "y"

def disk_setup():
  cont = bool_or_default("Create new disk", True)
  disks = []
  while (cont):
    name = string_until_some("Disk name")
    size = int_or_default("Disk size in MB", 8192)
    disks.append({
      "name": name,
      "size_mb": size
    })

    cont = bool_or_default("Create another disk", False)
  return disks

host = string_or_default("Velocity hostname and port", "http://localhost:8080/")
name = string_until_some("VM name")

cpus = int_or_default("CPU count", 1)
if (cpus <= 0):
  print("FATAL: At least 1 CPU has to be provided")
  exit(-1)

memory = int_or_default("Memory size in MB", 1024)

screen_w = int_or_default("Screen width", 640)
screen_h = int_or_default("Screen height", 480)

iso_path = input("ISO path: ")
if (not os.path.exists(iso_path)):
  print("WARNING: The ISO file at {} does not exist".format(iso_path))

disks = disk_setup()

rosetta = bool_or_default("Enable rosetta", True)
autostart = bool_or_default("Enable autostart", False)

req = {
  "name": name,
  "cpu_count": cpus,
  "memory_size": memory,
  "screen_size": [
    screen_w,
    screen_h
  ],
  "autostart": autostart,
  "state": {
    "STOPPED": {}
  },
  "efi_specific": {
    "enable_rosetta": rosetta,
    "iso_path": iso_path
  },
  "disks": disks
}

print("Sending following request: {}", req)

print("Sending createVM request..")

x = requests.post("{}/createVM".format(host), json=req)
print(f"Got response: {x._content.decode('utf8')}")
