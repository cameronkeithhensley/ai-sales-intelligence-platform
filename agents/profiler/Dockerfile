# syntax=docker/dockerfile:1.7

# Profiler runs passive OSINT reconnaissance — DNS-only, no active probing.
# The Kali base is chosen for convenient access to a packaged passive-recon
# toolchain. A production variant could be built on python:3.12-slim with
# only the specific utilities this service actually calls; the trade is
# image size for convenience, and for a portfolio build the Kali image is
# clearer about what the service does.
#
# DL3006 is suppressed because 'kali-rolling' IS the intended tag — it
# is the rolling-release channel, and pinning to a digest would defeat
# the purpose of being on a moving toolchain.
# hadolint ignore=DL3006
FROM kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Generic passive-recon toolchain + Python runtime. No active / offensive
# tools (nmap, metasploit, sqlmap, ...) are installed. Kali Rolling is a
# moving target so upstream version pins do not stick; DL3008 is suppressed
# deliberately rather than hidden.
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3 \
      python3-pip \
      dnsrecon \
      whois \
      dnsutils \
      ca-certificates \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .

# --break-system-packages is required against Debian/Kali's PEP 668
# externally-managed environment. We run as a non-root user, so the risk
# surface of 'writing to system site-packages' is bounded to the image.
RUN pip install --no-cache-dir --break-system-packages -r requirements.txt

COPY src ./src

RUN groupadd --system app \
 && useradd --system --gid app --home /home/app --create-home app \
 && chown -R app:app /app

USER app

CMD ["python3", "-u", "src/main.py"]
