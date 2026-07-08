# Target Model

A BosonOS target is modeled as:

```text
Target = SoC + Board + Profile
```

The SoC layer describes shared hardware family properties. The board layer
describes device-specific details. The profile layer describes runtime intent,
such as minimal, debug, or rescue.

This model lets BosonOS support many devices without mixing board quirks into
the core runtime or into unrelated SoC definitions.
