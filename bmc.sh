#!/bin/bash

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Network interfaces passed as arguments
INTERFACES=("$@")

if [ ${#INTERFACES[@]} -eq 0 ]; then
    echo "Usage: $0 <interface1> [interface2] ..."
    exit 1
fi

detach() {
    # Detach TC hooks for all interfaces
    for IFACE in "${INTERFACES[@]}"; do
        echo "Detaching BMC from interface $IFACE"
        sudo tc filter del dev $IFACE egress 2>/dev/null || true
        sudo tc qdisc del dev $IFACE clsact 2>/dev/null || true
        echo "BMC detached successfully from $IFACE."
    done
    sudo rm -f /sys/fs/bpf/bmc_tx_filter
}

# On script exit, detach TC hooks
trap detach EXIT

INTERFACE_IDXES=()
for IFACE in "${INTERFACES[@]}"; do
    IFACE_IDX=$(cat /sys/class/net/$IFACE/ifindex)
    INTERFACE_IDXES+=($IFACE_IDX)
done

sudo $SCRIPT_DIR/bmc/bmc "${INTERFACE_IDXES[@]}" &
sleep 5

# Attach TC hooks for all interfaces
for IFACE in "${INTERFACES[@]}"; do
    echo "Attaching BMC to interface $IFACE"
    sudo tc qdisc add dev $IFACE clsact
    sudo tc filter add dev $IFACE egress bpf object-pinned /sys/fs/bpf/bmc_tx_filter
    echo "BMC attached successfully to $IFACE."
done

wait
