---
name: svc
description: Read-only state of allowlisted systemd units.
events:
  asp.svc: {}
  tool.svc:
    description: ActiveState of one allowlisted unit.
    timeout_ms: 5000
    schema:
      type: object
      required: [op, input]
      properties:
        op: {const: call}
        input:
          type: object
          required: [unit]
          additionalProperties: false
          properties:
            unit: {type: string, enum: [bluetooth.service, NetworkManager.service]}
listen: [asp.svc, tool.svc]
grant:
  exec: [systemctl, /usr/bin/systemctl]
  read: [/usr, /etc, /run]
asp:
  roots: ["unit:bluetooth.service", "unit:NetworkManager.service"]
  schemes: {unit: {owner: true, description: a systemd unit}}
  actions:
    - {name: status, applies_to: unit, effect: read, tool: tool.svc, args: {unit: "${key}"}}
---
# svc

Answers whether a system service is running. The unit is validated against
the event schema's enum before anything runs.

```kern
{"on": "asp.svc", "when": {"op": "expand", "entity.scheme": "unit"}, "answer": {"nodes": [{"id": "${entity.id}", "name": "${entity.key}", "description": "systemd unit", "attributes": {}}], "edges": [], "complete": true}}
```

```kern
{"on": "tool.svc", "run": {"argv": ["systemctl", "show", "-p", "ActiveState", "--value", "${args.input.unit}"], "timeout_ms": 5000}}
```
