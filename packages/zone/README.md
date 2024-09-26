# Zone.Profile Package

## Usage
### Write

To set metadata entries in the Zone, send a message with the `Zone-Metadata.Set` action and the appropriate data.

**Parameters**:
- `process`: The process identifier.
- `data`: A JSON string containing an array of `entries`, where each entry has a `key` and `value`.
- `tags`: An array of tags, where each tag has a `name` and `value`.


**Data Schema**:
```json
{
  "type": "object",
  "properties": {
    "entries": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "key": { "type": "string" },
          "value": { "type": "string" }
        },
        "required": ["key", "value"]
      }
    }
  },
  "required": ["entries"]
}
```
#### Example
```json
{
  "process": "<your-zone-id>",
  "data": "{\"entries\": [{\"key\": \"hat\", \"value\": \"blue\"}, {\"key\": \"boots\", \"value\": \"black\"}]}",
  "tags": [
    {
      "name": "Action",
      "value": "Zone-Metadata.Set"
    }
  ]
}
```
### Read
To retrieve metadata entries from the Zone, send a message with the Zone-Metadata.Get action and the appropriate data.  

**Parameters**:

- `process`: The process identifier.
- `data`: A JSON string containing an array of `keys` to retrieve.
- `tags`: An array of tags, where each tag has a `name` and `value`.

**Data Schema**:
```json
{
  "type": "object",
  "properties": {
    "keys": {
      "type": "array",
      "items": { "type": "string" }
    }
  },
  "required": ["keys"]
}
```
#### Example
**Input**:
```json
{
  "process": "<your-process>",
  "data": "{\"keys\": [\"hat\", \"boots\"]}",
  "tags": [
    {
      "name": "Action",
      "value": "Zone-Metadata.Get"
    }
  ]
}
```
**Output**:
```json
{
  "Data": {
    "Results": {
      "boots": "black",
      "hat": "blue"
    }
  }
}
```

## Testing
### AOS CLI Example
To set metadata entries in the Zone, send a message with the `Zone-Metadata.Set` action and the appropriate data.

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