# Janus `templates/` Directory

This directory stores static template assets used by Janus workflows.

## Current content

- `libvirt/windows-base.xml`: base libvirt XML template for Windows guests.

## What this template provides

- default VM layout and hardware model;
- injectable placeholders for disk, ISO, unattended media, display profile, and GPU hostdev blocks;
- virtualization-stealth defaults used by Janus VM generation flow.

## Usage

Templates are rendered by `janus-vm` modules under `lib/vm/xml/`.
