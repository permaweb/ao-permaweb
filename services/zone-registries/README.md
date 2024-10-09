# About
**wallet**  -(changes)->  **zone**   -forwards-to->  **zone-registry**  -forwards-to->  **search-index-registries**

# Usage
## Zone Registry
### `Prepare-Database`

**Action**: `Prepare-Database`

**Description**: Initializes the database by creating necessary tables for zone ownership and delegation.

**Parameters**:
- `msg`: The message object containing the action and data.

### `Create-Zone`

**Action**: `Create-Zone`

**Description**: Creates a new profile in the zone.

**Parameters**:
- `msg`: The message object containing the action and data.

**Returns**:
```json
{
  "Target": "<profile_id>",
  "Action": "Zone-Created-Success"
}
```

### `Get-Profiles-By-Delegate`

**Action**: `Get-Zones-For-User`

**Description**: Retrieves Zone(s) associated with a wallet address.

**Parameters**:
- `msg`: The message object containing the action and data.
- `msg.Data`: `"{\"Address\": \"<some_wallet>\"}"`

**Returns**:
```json
{
  "Target": "<profile_id>",
  "Action": "Zone-Fetch-Success",
  "Data": "[{\"ZoneId\": \"some_id\", \"UserId\": \"some_address\", \"Role\": \"Owner\"}]"
}
```


### `Update Profile Metadata`

**Action**: `Zone-Metadata.Set`

**Description**: Updates an existing profile in the zone.

**Parameters**:
- `msg`: The message object containing the action and data.
- `msg.Data`: JSON object containing updated profile details.

### `Update Zone Role`

**Action**: `Zone-Role.Set`

**Description**: Updates the role of a delegate for a profile.

**Parameters**:
- `msg`: The message object containing the action and data.
- `msg.Data`: JSON object containing `Id`, `Op`, and optionally `Role`.

### `Read-Auth`

**Action**: `Read-Auth`

**Description**: Retrieves authorization data for profiles.

**Parameters**:
- `msg`: The message object containing the action.