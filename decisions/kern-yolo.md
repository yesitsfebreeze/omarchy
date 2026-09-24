# KERN runs in YOLO mode for the bridge

KERN refuses every `run` block without its `executor` extension
(`~/.kern/extensions/executor`), and that extension's source is not published
anywhere. `bridge/omarchy-bridge` therefore starts `kern mcp` with
`CARTRIDGE_YOLO=1`, which skips KERN's trust checks and sandbox.

The safety boundary is the bridge instead: it forwards only allowlisted
read-only tools with enum-validated arguments, and the `svc` kern pins the
units it will query. Revisit when the executor extension exists.
