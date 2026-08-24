#!/usr/bin/env python3
import subprocess
import sys

TURBO_PATH = "/sys/devices/system/cpu/intel_pstate/no_turbo"

def set_turbo(profile):
    val = "0" if "performance" in profile else "1"
    subprocess.run(["sudo", "-n", "tee", TURBO_PATH], input=val, text=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# Initial update on script start
res = subprocess.run(["powerprofilesctl", "get"], capture_output=True, text=True)
set_turbo(res.stdout.strip())

# Monitor D-Bus property changes with unbuffered stdout
proc = subprocess.Popen(
    ["stdbuf", "-oL", "gdbus", "monitor", "--system", "--dest", "net.hadess.PowerProfiles", "--object-path", "/net/hadess/PowerProfiles"],
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    text=True,
    bufsize=1
    
)

for line in iter(proc.stdout.readline, ''):
    if "ActiveProfile" in line:
        if "<'performance'>" in line:
            set_turbo("performance")
        else:
            set_turbo("power-saver")
