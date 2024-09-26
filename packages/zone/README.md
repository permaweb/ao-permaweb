# Profile Package

## Testing

### AOS CLI

```
.load path/to/bundle.lua
.editor
<editor mode> use '.done' to submit or '.cancel' to cancel
local P = require("@permaweb/zone")
P.zoneKV:set("tree", "green")
print(P.zoneKV:get("tree"))
.done
RETURNS:
black

```

### AO LINK
#### Write

```
{
  "process": <your-process>,
  "data": "{\"entries\": [{\"key\": \"hat\", \"value\": \"blue\"}, {\"key\": \"boots\", \"value\": \"black\"}]}",
  "tags": [
    {
      "name": "Action",
      "value": "Zone-Metadata.Set"
    }
  ]
}
```

#### Read

INPUT
```
{
  "process": <your process>,
  "data": "{\"keys\": [\"hat\", \"boots\"]}",
  "tags": [
    {
      "name": "Action",
      "value": "Zone-Metadata.Get"
    }
  ]
}
```
OUTPUT
```
    "Data": {
    "Results": {
      "boots": "black",
      "hat": "blue"
    }
    },
```
