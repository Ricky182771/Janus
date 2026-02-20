#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Bind CLI
# ----------------------------------------------------------------------------
# This file handles command-line parsing for janus-bind.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_BIND_CLI_ARGS_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_BIND_CLI_ARGS_LOADED=1

# Print command help.
janus_bind_show_help() {
    cat <<EOF_HELP
janus-bind v$JANUS_BIND_VERSION
Safely prepare PCI devices for VFIO passthrough.

Usage:
  janus-bind --list
  janus-bind --device 0000:03:00.0 --dry-run
  janus-bind --group 11 --dry-run --yes
  sudo janus-bind --device 0000:03:00.0 --apply
  sudo janus-bind --rollback

Options:
  --list              List detected display controllers.
  --device PCI        Target a single PCI device.
  --group ID          Target all devices in an IOMMU group.
  --dry-run           Simulate actions (default mode).
  --apply             Apply bind operations to vfio-pci (requires root).
  --rollback          Restore last saved bind state (requires root).
  --yes               Assume yes for confirmation prompts.
  --verbose           Enable debug logging.
  --help, -h          Show this help.

Warning:
  --apply writes to /sys and can impact active graphics/session devices.
  Prefer --dry-run first and validate your IOMMU isolation.
EOF_HELP
}

# Parse and normalize bind command options.
janus_bind_parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --list)
                janus_bind_list_devices
                exit 0
                ;;
            --device)
                [ $# -ge 2 ] || janus_bind_die "--device requires a PCI address argument."
                JANUS_BIND_TARGET_DEVICE="$2"
                shift
                ;;
            --group)
                [ $# -ge 2 ] || janus_bind_die "--group requires an IOMMU group ID."
                JANUS_BIND_TARGET_GROUP="$2"
                shift
                ;;
            --dry-run)
                JANUS_BIND_MODE="dry-run"
                ;;
            --apply)
                JANUS_BIND_MODE="apply"
                ;;
            --rollback)
                JANUS_BIND_ROLLBACK=1
                ;;
            --yes)
                JANUS_BIND_ASSUME_YES=1
                ;;
            --verbose)
                JANUS_BIND_VERBOSE=1
                ;;
            --help|-h)
                janus_bind_show_help
                exit 0
                ;;
            *)
                janus_bind_die "Unknown option: $1"
                ;;
        esac
        shift
    done
}

# Validate incompatible option combinations.
janus_bind_validate_option_combinations() {
    if [ "$JANUS_BIND_ROLLBACK" -eq 1 ] && [ -n "$JANUS_BIND_TARGET_DEVICE$JANUS_BIND_TARGET_GROUP" ]; then
        janus_bind_die "--rollback cannot be combined with --device or --group."
    fi

    if [ "$JANUS_BIND_ROLLBACK" -eq 1 ] && [ "$JANUS_BIND_MODE" = "apply" ]; then
        janus_bind_die "--rollback cannot be combined with --apply."
    fi
}
