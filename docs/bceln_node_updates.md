# Instructions to Upgrade MicroK8s Nodes in a Cluster

1. **Check Node Versions**
    -  From DC node, run:
      ```
      kubectl get nodes
      ```
    - Look at the `VERSION` column to identify nodes running older MicroK8s versions.

2. **Upgrade Outdated Nodes**
    - For each node needing an update:
      1. SSH into the node:
          ```
          ssh <node>
          ```
      2. Run the following command to upgrade MicroK8s:
          ```
          sudo snap refresh microk8s --channel=1.32/stable
          ```
      3. Wait for the upgrade to complete.

3. **Verify Upgrade**
    - After upgrading all nodes, return to your control node and run:
      ```
      kubectl get nodes -o wide
      ```
    - Confirm all nodes are now running the desired version (`1.32.9`).