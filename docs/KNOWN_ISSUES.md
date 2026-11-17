# Known issues

- Unloading and reloading a chunk resets its depleted nodes. Chunk unload destroys node state (Depleted/HitsLeft attributes), so a reload rebuilds the nodes full and an exhausted tree or rock reappears instantly. Not fixed; needs depleted-node timers kept outside the chunk (e.g. in GatherService keyed by node slot id).
